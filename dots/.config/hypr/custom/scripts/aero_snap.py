#!/usr/bin/env python3
"""
8-zone Windows-style Aero Snap & Unsnap helper for Hyprland (0.57+ Lua API).
Features:
- 30% corner zones & edge zones for fast, forgiving snapping
- Automatic unsnap restore: dragging a snapped window outside snap zones restores
  its pre-snap floating size cleanly under the cursor
- Multi-monitor seam guard (prevents accidental workspace switches at monitor borders)
- Enforces window workspace ownership to match the target monitor's active workspace
- Respects reserved bar/dock insets, gaps_out, gaps_in, and border_size
"""

import json
import os
import re
import select
import signal
import struct
import subprocess
import sys
import time

DRAG_MIN_PX = 8
SEAM_OVERSHOOT_PX = 100
WAIT_TIMEOUT_S = 20.0

EV_KEY = 0x01
BTN_LEFT = 0x110   # 272
BTN_TOUCH = 0x14A  # 330
EVENT_STRUCT = struct.Struct("llHHi")


def runtime_path(filename: str) -> str:
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), filename)


def get_corner_ratio() -> float:
    """Read corner snap percentage from Quickshell settings (config.json)."""
    cfg_dir = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    cfg_path = os.path.join(cfg_dir, "illogical-impulse", "config.json")
    try:
        with open(cfg_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        pct = float(data.get("windows", {}).get("dragCornerPercent", 30))
        pct = max(5.0, min(45.0, pct))
        return pct / 100.0
    except (OSError, ValueError, TypeError):
        return 0.30


def load_snap_state() -> dict:
    path = runtime_path("raven-aero-snap-state.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_snap_state(state: dict):
    path = runtime_path("raven-aero-snap-state.json")
    # Keep state file bounded by dropping oldest entries if huge
    if len(state) > 64:
        keys = list(state.keys())[-32:]
        state = {k: state[k] for k in keys}
    tmp = f"{path}.tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(state, f)
        os.replace(tmp, path)
    except OSError:
        pass


def hyprctl_json(cmd: str):
    res = subprocess.run(["hyprctl", cmd, "-j"], capture_output=True, text=True)
    if res.returncode != 0 or not res.stdout.strip():
        return None
    return json.loads(res.stdout)


def get_int_option(opt: str, fallback: int) -> int:
    data = hyprctl_json(f"getoption {opt}")
    if not data:
        return fallback
    if "int" in data:
        return int(data["int"])
    if "css" in data:
        m = re.match(r"^\s*(\d+)", str(data["css"]))
        if m:
            return int(m.group(1))
    return fallback


def find_pointer_event_devices() -> list[str]:
    """Return /dev/input/eventN paths for mouse and touchpad devices."""
    devices = []
    try:
        with open("/proc/bus/input/devices", "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if line.startswith("H: Handlers=") and "mouse" in line:
                    for token in line.split():
                        if token.startswith("event"):
                            path = f"/dev/input/{token}"
                            if os.path.exists(path):
                                devices.append(path)
    except OSError:
        pass
    return devices


def wait_for_pointer_release(timeout_s: float = WAIT_TIMEOUT_S) -> bool:
    """Block efficiently via select() until mouse/touchpad primary button is released."""
    paths = find_pointer_event_devices()
    fds = []
    for path in paths:
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            fds.append(fd)
        except OSError:
            continue

    if not fds:
        return False

    deadline = time.monotonic() + timeout_s
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return False
            readable, _, _ = select.select(fds, [], [], remaining)
            for fd in readable:
                while True:
                    try:
                        chunk = os.read(fd, EVENT_STRUCT.size * 16)
                    except BlockingIOError:
                        break
                    except OSError:
                        break
                    if not chunk:
                        break
                    offset = 0
                    while offset + EVENT_STRUCT.size <= len(chunk):
                        _, _, ev_type, code, value = EVENT_STRUCT.unpack_from(chunk, offset)
                        offset += EVENT_STRUCT.size
                        if ev_type == EV_KEY and code in (BTN_LEFT, BTN_TOUCH) and value == 0:
                            return True
    finally:
        for fd in fds:
            try:
                os.close(fd)
            except OSError:
                pass


def monitor_rect(mon: dict) -> tuple[int, int, int, int]:
    scale = mon.get("scale") or 1.0
    w = mon["width"] / scale
    h = mon["height"] / scale
    if mon.get("transform") in (1, 3, 5, 7):
        w, h = h, w
    return int(mon["x"]), int(mon["y"]), int(w), int(h)


def find_monitor_at(monitors: list[dict], cx: int, cy: int) -> dict | None:
    for mon in monitors:
        mx, my, mw, mh = monitor_rect(mon)
        if mx <= cx < mx + mw and my <= cy < my + mh:
            return mon
    for mon in monitors:
        if mon.get("focused"):
            return mon
    return monitors[0] if monitors else None


def find_monitor_by_id(monitors: list[dict], mon_id: int) -> dict | None:
    for mon in monitors:
        if mon.get("id") == mon_id:
            return mon
    return None


def resolve_target_monitor_and_cursor(
    monitors: list[dict], cx: int, cy: int, start_mon_id: int
) -> tuple[dict | None, int, int]:
    """
    Prevent slight overshoots across the shared border between dual monitors
    from jumping the snapped window to the neighbor monitor/workspace.
    """
    cursor_mon = find_monitor_at(monitors, cx, cy)
    start_mon = find_monitor_by_id(monitors, start_mon_id) if start_mon_id >= 0 else None

    if start_mon and cursor_mon and start_mon["id"] != cursor_mon["id"]:
        smx, smy, smw, smh = monitor_rect(start_mon)
        dx_out = max(smx - cx, cx - (smx + smw - 1), 0)
        dy_out = max(smy - cy, cy - (smy + smh - 1), 0)
        if dx_out <= SEAM_OVERSHOOT_PX and dy_out <= SEAM_OVERSHOOT_PX:
            clamped_x = max(smx, min(cx, smx + smw - 1))
            clamped_y = max(smy, min(cy, smy + smh - 1))
            return start_mon, clamped_x, clamped_y

    return cursor_mon, cx, cy


def compute_workarea(mon: dict) -> dict:
    mx, my, mw, mh = monitor_rect(mon)
    res = mon.get("reserved") or [0, 0, 0, 0]
    r_left, r_top, r_right, r_bottom = int(res[0]), int(res[1]), int(res[2]), int(res[3])

    gaps_out = get_int_option("general:gaps_out", 6)
    gaps_in = get_int_option("general:gaps_in", 4)
    border = get_int_option("general:border_size", 2)

    ax = mx + r_left + gaps_out + border
    ay = my + r_top + gaps_out + border
    aw = mw - r_left - r_right - 2 * gaps_out - 2 * border
    ah = mh - r_top - r_bottom - 2 * gaps_out - 2 * border

    mid_gap = 2 * gaps_in + 2 * border
    half_w = (aw - mid_gap) // 2
    half_h = (ah - mid_gap) // 2

    return {
        "mx": mx, "my": my, "mw": mw, "mh": mh,
        "r_top": r_top, "r_bottom": r_bottom,
        "ax": ax, "ay": ay, "aw": aw, "ah": ah,
        "half_w": half_w, "half_h": half_h,
        "right_x": ax + half_w + mid_gap,
        "bottom_y": ay + half_h + mid_gap,
    }


def zone_box(wa: dict, zone: str) -> tuple[int, int, int, int] | None:
    zones = {
        "top_left":     (wa["ax"], wa["ay"], wa["half_w"], wa["half_h"]),
        "top_right":    (wa["right_x"], wa["ay"], wa["half_w"], wa["half_h"]),
        "bottom_left":  (wa["ax"], wa["bottom_y"], wa["half_w"], wa["half_h"]),
        "bottom_right": (wa["right_x"], wa["bottom_y"], wa["half_w"], wa["half_h"]),
        "left":         (wa["ax"], wa["ay"], wa["half_w"], wa["ah"]),
        "right":        (wa["right_x"], wa["ay"], wa["half_w"], wa["ah"]),
        "maximize":     (wa["ax"], wa["ay"], wa["aw"], wa["ah"]),
    }
    return zones.get(zone)


def detect_zone(wa: dict, cx: int, cy: int) -> str | None:
    mx, my, mw, mh = wa["mx"], wa["my"], wa["mw"], wa["mh"]
    r_top, r_bottom = wa["r_top"], wa["r_bottom"]
    usable_h = mh - r_top - r_bottom

    # Symmetric zone ratio from Settings -> Interface -> Window management.
    # Side edge bands use the same horizontal reach as corners so Left/Right halves
    # (corner_w * middle_h) are at least as large and easy to hit as each corner.
    ratio = get_corner_ratio()
    zone_w = max(80, int(mw * ratio))
    # Cap vertical corner split at 33% so middle Left/Right half always retains >= 34% height
    corner_h = max(80, int(usable_h * min(0.33, ratio)))
    top_h = max(48, int(usable_h * min(0.12, ratio * 0.5)))

    in_left = cx <= mx + zone_w
    in_right = cx >= mx + mw - zone_w
    in_top_corner = cy <= my + r_top + corner_h
    in_bottom_corner = cy >= my + mh - r_bottom - corner_h

    if in_left and in_top_corner:
        return "top_left"
    if in_right and in_top_corner:
        return "top_right"
    if in_left and in_bottom_corner:
        return "bottom_left"
    if in_right and in_bottom_corner:
        return "bottom_right"

    if in_left:
        return "left"
    if in_right:
        return "right"
    if cy <= my + r_top + top_h:
        return "maximize"
    return None


def looks_like_snapped_geometry(win: dict, wa: dict) -> bool:
    """Fallback detector when a window was already snapped before state tracking."""
    size = win.get("size") or [0, 0]
    w, h = int(size[0]), int(size[1])
    tol = 6
    is_quarter = abs(w - wa["half_w"]) <= tol and abs(h - wa["half_h"]) <= tol
    is_half = abs(w - wa["half_w"]) <= tol and abs(h - wa["ah"]) <= tol
    is_max = abs(w - wa["aw"]) <= tol and abs(h - wa["ah"]) <= tol
    return is_quarter or is_half or is_max


def apply_snap(zone: str | None = None, start_mon_id: int = -1):
    win = hyprctl_json("activewindow")
    if not win or not win.get("address") or win.get("fullscreen") == 2:
        return

    monitors = hyprctl_json("monitors") or []
    cursor = hyprctl_json("cursorpos")
    if not monitors or not cursor:
        return

    raw_cx, raw_cy = int(cursor["x"]), int(cursor["y"])
    target_mon, cx, cy = resolve_target_monitor_and_cursor(monitors, raw_cx, raw_cy, start_mon_id)
    if not target_mon:
        return

    wa = compute_workarea(target_mon)
    target_zone = zone or detect_zone(wa, cx, cy)
    addr_raw = win["address"]
    addr = f"address:{addr_raw}"
    state = load_snap_state()

    target_ws = (target_mon.get("activeWorkspace") or {}).get("id")
    win_ws = (win.get("workspace") or {}).get("id")

    if target_zone:
        box = zone_box(wa, target_zone)
        if not box:
            return
        x, y, w, h = box

        # Preserve pre-snap floating dimensions if transitioning from unsnapped -> snapped
        entry = state.get(addr_raw)
        if not entry:
            if win.get("floating", False) and win.get("fullscreen", 0) == 0 and not looks_like_snapped_geometry(win, wa):
                sz = win.get("size") or [int(wa["aw"] * 0.65), int(wa["ah"] * 0.70)]
                pre_w, pre_h = int(sz[0]), int(sz[1])
            else:
                pre_w, pre_h = int(wa["aw"] * 0.65), int(wa["ah"] * 0.70)
            entry = {"pre_w": pre_w, "pre_h": pre_h}
        entry["zone"] = target_zone
        state[addr_raw] = entry
        save_snap_state(state)

        cmds = []
        if win.get("fullscreen", 0) != 0:
            cmds.append(f"dispatch hl.dsp.window.fullscreen({{ action = 'unset', window = '{addr}' }})")
        if not win.get("floating", False):
            cmds.append(f"dispatch hl.dsp.window.float({{ action = 'set', window = '{addr}' }})")
        if target_ws and win_ws != target_ws:
            cmds.append(f"dispatch hl.dsp.window.move({{ workspace = {int(target_ws)}, follow = false, window = '{addr}' }})")
        cmds.append(f"dispatch hl.dsp.window.resize({{ x = {w}, y = {h}, relative = false, window = '{addr}' }})")
        cmds.append(f"dispatch hl.dsp.window.move({{ x = {x}, y = {y}, relative = false, window = '{addr}' }})")
        cmds.append(f"dispatch hl.dsp.focus({{ window = '{addr}' }})")
        subprocess.run(["hyprctl", "--batch", " ; ".join(cmds)], capture_output=True)
        return

    # Dropped outside snap zones: if window was previously snapped (or maximized),
    # restore it cleanly to a balanced floating window at the drop location.
    entry = state.pop(addr_raw, None)
    was_snapped = entry is not None or win.get("fullscreen", 0) == 1
    if not was_snapped and win.get("floating", False):
        # Also detect snapped geometry on the start monitor in case it came from another monitor
        start_mon = find_monitor_by_id(monitors, start_mon_id) if start_mon_id >= 0 else None
        ref_wa = compute_workarea(start_mon) if start_mon else wa
        was_snapped = looks_like_snapped_geometry(win, ref_wa)

    if entry is not None:
        save_snap_state(state)

    if was_snapped:
        rw = int(entry["pre_w"]) if entry and entry.get("pre_w") else int(wa["aw"] * 0.65)
        rh = int(entry["pre_h"]) if entry and entry.get("pre_h") else int(wa["ah"] * 0.70)
        rw = max(320, min(rw, wa["aw"]))
        rh = max(240, min(rh, wa["ah"]))

        rx = max(wa["ax"], min(cx - rw // 2, wa["ax"] + wa["aw"] - rw))
        ry = max(wa["ay"], min(cy - rh // 4, wa["ay"] + wa["ah"] - rh))

        cmds = []
        if win.get("fullscreen", 0) != 0:
            cmds.append(f"dispatch hl.dsp.window.fullscreen({{ action = 'unset', window = '{addr}' }})")
        if not win.get("floating", False):
            cmds.append(f"dispatch hl.dsp.window.float({{ action = 'set', window = '{addr}' }})")
        if target_ws and win_ws != target_ws:
            cmds.append(f"dispatch hl.dsp.window.move({{ workspace = {int(target_ws)}, follow = false, window = '{addr}' }})")
        cmds.append(f"dispatch hl.dsp.window.resize({{ x = {rw}, y = {rh}, relative = false, window = '{addr}' }})")
        cmds.append(f"dispatch hl.dsp.window.move({{ x = {rx}, y = {ry}, relative = false, window = '{addr}' }})")
        cmds.append(f"dispatch hl.dsp.focus({{ window = '{addr}' }})")
        subprocess.run(["hyprctl", "--batch", " ; ".join(cmds)], capture_output=True)
        return

    # Regular unsnapped drag: still enforce workspace matches monitor of window center
    if win.get("floating", False):
        at = win.get("at") or [0, 0]
        size = win.get("size") or [0, 0]
        w_cx = int(at[0] + size[0] / 2)
        w_cy = int(at[1] + size[1] / 2)
        center_mon = find_monitor_at(monitors, w_cx, w_cy)
        if center_mon:
            center_ws = (center_mon.get("activeWorkspace") or {}).get("id")
            if center_ws and win_ws != center_ws:
                cmds = [
                    f"dispatch hl.dsp.window.move({{ workspace = {int(center_ws)}, follow = false, window = '{addr}' }})",
                    f"dispatch hl.dsp.focus({{ window = '{addr}' }})",
                ]
                subprocess.run(["hyprctl", "--batch", " ; ".join(cmds)], capture_output=True)


def acquire_single_instance():
    pid_path = runtime_path("raven-aero-snap.pid")
    try:
        with open(pid_path, "r") as f:
            old_pid = int(f.read().strip())
        if old_pid != os.getpid():
            os.kill(old_pid, signal.SIGTERM)
    except (OSError, ValueError):
        pass
    try:
        with open(pid_path, "w") as f:
            f.write(str(os.getpid()))
    except OSError:
        pass


def main():
    if len(sys.argv) >= 4 and sys.argv[1] == "--wait-release":
        acquire_single_instance()
        sx, sy = int(float(sys.argv[2])), int(float(sys.argv[3]))
        start_mon_id = int(sys.argv[4]) if len(sys.argv) >= 5 else -1
        if not wait_for_pointer_release():
            return
        time.sleep(0.03)
        cursor = hyprctl_json("cursorpos")
        if not cursor:
            return
        if abs(int(cursor["x"]) - sx) <= DRAG_MIN_PX and abs(int(cursor["y"]) - sy) <= DRAG_MIN_PX:
            return
        apply_snap(start_mon_id=start_mon_id)
    elif len(sys.argv) >= 3 and sys.argv[1] == "--snap":
        apply_snap(zone=sys.argv[2])


if __name__ == "__main__":
    main()
