#!/usr/bin/env python3
"""
8-zone Windows-style Aero Snap, Window Drop-Swap & Z-Order helper for Hyprland (0.57+ Lua API).
Features:
- Works seamlessly both with SUPER + Left Click AND native CSD titlebar dragging (e.g. Chrome/GTK) without holding SUPER
- 8-zone corner/edge snapping with configurable corner ratio & automatic unsnap restore
- Drop-to-swap: dragging a floating or snapped window onto another open window swaps their slots cleanly
- Enforces floating windows always on top of auto-snapped/maximized windows via `raven_snapped` tag & alterzorder
- Multi-monitor seam guard & automatic workspace ownership enforcement
"""

import json
import os
import re
import select
import signal
import socket
import struct
import subprocess
import sys
import time

DRAG_MIN_PX = 8
MOVE_TOL_PX = 4
RESIZE_TOL_PX = 4
SEAM_OVERSHOOT_PX = 100
WAIT_TIMEOUT_S = 20.0
DEVICE_REFRESH_S = 5.0
SNAPPED_TAG = "raven_snapped"

EV_KEY = 0x01
BTN_LEFT = 0x110   # Primary mouse / clickpad / tap-and-drag button
BTN_TOUCH = 0x14A  # Raw finger contact (used only in legacy --wait-release)
EVENT_STRUCT = struct.Struct("llHHi")


def runtime_path(filename: str) -> str:
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), filename)


def config_dir() -> str:
    return os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))


def is_snap_feature_enabled() -> bool:
    """Respect both Settings (config.json) and toggle_window_mode.sh flag."""
    snap_lua = os.path.join(config_dir(), "hypr", "custom", "aero_snap_enabled.lua")
    try:
        with open(snap_lua, "r", encoding="utf-8") as f:
            if "return false" in f.read():
                return False
    except OSError:
        pass

    cfg_path = os.path.join(config_dir(), "illogical-impulse", "config.json")
    try:
        with open(cfg_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if data.get("windows", {}).get("dragCornerSnap", True) is False:
            return False
    except (OSError, ValueError, TypeError):
        pass
    return True


def get_corner_ratio() -> float:
    """Read corner snap percentage from Quickshell settings (config.json)."""
    cfg_path = os.path.join(config_dir(), "illogical-impulse", "config.json")
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


_HYPR_SOCK_PATH: str | None = None


def get_hypr_socket_path() -> str | None:
    global _HYPR_SOCK_PATH
    if _HYPR_SOCK_PATH and os.path.exists(_HYPR_SOCK_PATH):
        return _HYPR_SOCK_PATH

    xdg = os.environ.get("XDG_RUNTIME_DIR", "")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if xdg and sig:
        cand = os.path.join(xdg, "hypr", sig, ".socket.sock")
        if os.path.exists(cand):
            _HYPR_SOCK_PATH = cand
            return cand

    hypr_root = os.path.join(xdg, "hypr") if xdg else ""
    if hypr_root and os.path.isdir(hypr_root):
        try:
            entries = sorted(
                (os.path.join(hypr_root, d) for d in os.listdir(hypr_root)),
                key=lambda p: os.path.getmtime(p),
                reverse=True,
            )
            for entry in entries:
                cand = os.path.join(entry, ".socket.sock")
                if os.path.exists(cand):
                    _HYPR_SOCK_PATH = cand
                    return cand
        except OSError:
            pass
    return None


def hypr_raw(payload: str) -> str | None:
    sock_path = get_hypr_socket_path()
    if sock_path:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.settimeout(1.5)
                sock.connect(sock_path)
                sock.sendall(payload.encode("utf-8"))
                chunks = []
                while True:
                    data = sock.recv(8192)
                    if not data:
                        break
                    chunks.append(data)
                return b"".join(chunks).decode("utf-8", errors="replace")
        except OSError:
            pass
    return None


def hyprctl_json(cmd: str):
    raw = hypr_raw(f"j/{cmd}")
    if raw:
        try:
            return json.loads(raw)
        except ValueError:
            pass
    res = subprocess.run(["hyprctl", cmd, "-j"], capture_output=True, text=True)
    if res.returncode != 0 or not res.stdout.strip():
        return None
    try:
        return json.loads(res.stdout)
    except ValueError:
        return None


def hyprctl_batch(cmds: list[str]):
    if not cmds:
        return
    joined = " ; ".join(cmds)
    if hypr_raw(f"[[BATCH]]{joined}") is not None:
        return
    subprocess.run(["hyprctl", "--batch", joined], capture_output=True)


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
    """Legacy single-shot release waiter used by --wait-release."""
    paths = find_pointer_event_devices()
    fds = []
    for path in paths:
        try:
            fds.append(os.open(path, os.O_RDONLY | os.O_NONBLOCK))
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
                    except (BlockingIOError, OSError):
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


def rect_of(win: dict) -> tuple[int, int, int, int]:
    at = win.get("at") or [0, 0]
    sz = win.get("size") or [0, 0]
    return int(at[0]), int(at[1]), int(sz[0]), int(sz[1])


def point_in_rect(px: int, py: int, rect: tuple[int, int, int, int]) -> bool:
    rx, ry, rw, rh = rect
    return rx <= px < rx + rw and ry <= py < ry + rh


def resolve_target_monitor_and_cursor(
    monitors: list[dict], cx: int, cy: int, start_mon_id: int
) -> tuple[dict | None, int, int]:
    """Prevent slight overshoots across dual-monitor borders from jumping workspaces."""
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

    ratio = get_corner_ratio()
    zone_w = max(80, int(mw * ratio))
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


def infer_snapped_zone(win: dict, wa: dict, entry: dict | None = None) -> str | None:
    """Return zone name if window matches a snapped layout slot or tracked state."""
    if entry and entry.get("zone"):
        return entry["zone"]
    if win.get("fullscreen", 0) == 1:
        return "maximize"
    if not win.get("floating", False):
        return None
    wx, wy, ww, wh = rect_of(win)
    tol = 8
    for zname in ("left", "right", "top_left", "top_right", "bottom_left", "bottom_right", "maximize"):
        box = zone_box(wa, zname)
        if not box:
            continue
        bx, by, bw, bh = box
        if abs(ww - bw) <= tol and abs(wh - bh) <= tol and abs(wx - bx) <= tol and abs(wy - by) <= tol:
            return zname
    return None


def looks_like_snapped_geometry(win: dict, wa: dict) -> bool:
    size = win.get("size") or [0, 0]
    w, h = int(size[0]), int(size[1])
    tol = 8
    is_quarter = abs(w - wa["half_w"]) <= tol and abs(h - wa["half_h"]) <= tol
    is_half = abs(w - wa["half_w"]) <= tol and abs(h - wa["ah"]) <= tol
    is_max = abs(w - wa["aw"]) <= tol and abs(h - wa["ah"]) <= tol
    return is_quarter or is_half or is_max


def has_snapped_tag(win: dict) -> bool:
    return SNAPPED_TAG in (win.get("tags") or [])


def is_snapped_window(win: dict, wa: dict, state: dict) -> bool:
    addr = win.get("address", "")
    return (
        addr in state
        or has_snapped_tag(win)
        or (win.get("floating", False) and looks_like_snapped_geometry(win, wa))
        or win.get("fullscreen", 0) == 1
    )


def is_maximized_window(win: dict, wa: dict, state: dict) -> bool:
    if win.get("fullscreen", 0) != 0:
        return True
    entry = state.get(win.get("address", ""))
    if entry and entry.get("zone") == "maximize":
        return True
    _, _, ww, wh = rect_of(win)
    return win.get("floating", False) and abs(ww - wa["aw"]) <= 8 and abs(wh - wa["ah"]) <= 8


def build_place_cmds(
    win: dict,
    box: tuple[int, int, int, int],
    target_ws: int | None,
    snapped: bool,
) -> list[str]:
    """Build atomic Hyprland dispatch commands to place, tag, and layer a window."""
    addr_raw = win["address"]
    addr = f"address:{addr_raw}"
    x, y, w, h = box
    w = max(240, int(w))
    h = max(180, int(h))

    cmds = []
    if win.get("fullscreen", 0) != 0:
        cmds.append(f"dispatch hl.dsp.window.fullscreen({{ action = 'unset', window = '{addr}' }})")
    if not win.get("floating", False):
        cmds.append(f"dispatch hl.dsp.window.float({{ action = 'set', window = '{addr}' }})")

    win_ws = (win.get("workspace") or {}).get("id")
    if target_ws is not None and win_ws != target_ws:
        cmds.append(f"dispatch hl.dsp.window.move({{ workspace = {int(target_ws)}, follow = false, window = '{addr}' }})")

    cmds.append(f"dispatch hl.dsp.window.resize({{ x = {w}, y = {h}, relative = false, window = '{addr}' }})")
    cmds.append(f"dispatch hl.dsp.window.move({{ x = {int(x)}, y = {int(y)}, relative = false, window = '{addr}' }})")

    currently_tagged = has_snapped_tag(win)
    if snapped and not currently_tagged:
        cmds.append(f"dispatch hl.dsp.window.tag({{ tag = '+{SNAPPED_TAG}', window = '{addr}' }})")
    elif not snapped and currently_tagged:
        cmds.append(f"dispatch hl.dsp.window.tag({{ tag = '-{SNAPPED_TAG}', window = '{addr}' }})")

    return cmds


def enforce_floating_above_snapped_cmds(
    clients: list[dict],
    state: dict,
    monitors: list[dict],
    workspace_ids: set[int],
    override_snapped: dict[str, bool] | None = None,
) -> list[str]:
    """
    Push snapped windows cleanly to bottom of the floating z-stack on affected workspaces
    so unsnapped floating windows always remain above snapped/maximized windows.
    """
    override_snapped = override_snapped or {}
    cmds = []
    mon_wa_cache: dict[int, dict] = {}

    for ws_id in workspace_ids:
        snapped_wins = []
        floating_wins = []
        for c in clients:
            if not c.get("mapped") or c.get("hidden") or c.get("fullscreen", 0) != 0:
                continue
            if (c.get("workspace") or {}).get("id") != ws_id:
                continue
            if not c.get("floating", False):
                continue

            addr = c.get("address", "")
            if addr in override_snapped:
                c_is_snapped = override_snapped[addr]
            else:
                mon_id = c.get("monitor", -1)
                if mon_id not in mon_wa_cache:
                    mon = find_monitor_by_id(monitors, mon_id)
                    mon_wa_cache[mon_id] = compute_workarea(mon) if mon else None
                c_wa = mon_wa_cache[mon_id]
                c_is_snapped = bool(c_wa and is_snapped_window(c, c_wa, state))

            if c_is_snapped:
                snapped_wins.append(c)
            else:
                floating_wins.append(c)

        if not floating_wins or not snapped_wins:
            continue

        # Push most recently focused snapped first, oldest last -> oldest ends up lowest,
        # preserving snapped relative order while keeping every floating window on top.
        snapped_wins.sort(key=lambda w: w.get("focusHistoryID", 999))
        for sw in snapped_wins:
            cmds.append(f"dispatch hl.dsp.window.alter_zorder({{ mode = 'bottom', window = 'address:{sw['address']}' }})")

    return cmds


def find_swap_target(
    clients: list[dict],
    drag_addr: str,
    target_ws: int,
    cx: int,
    cy: int,
    sx: int,
    sy: int,
    wa: dict,
    state: dict,
    target_zone: str | None,
) -> dict | None:
    """
    Find an open non-maximized window to swap slots with when dropping a dragged window.
    - When dropped in an edge/corner zone (excluding maximize), swaps with a window occupying that slot.
    - When dropped outside snap zones onto another window, swaps with the topmost visible window
      at the drop point provided the drag started outside that window.
    """
    if target_zone == "maximize":
        return None

    candidates = []
    for c in clients:
        if not c.get("mapped") or c.get("hidden"):
            continue
        if (c.get("workspace") or {}).get("id") != target_ws:
            continue
        if c.get("address") == drag_addr or c.get("fullscreen", 0) == 2:
            continue
        if is_maximized_window(c, wa, state):
            continue

        crect = rect_of(c)
        c_entry = state.get(c.get("address", ""))
        c_zone = infer_snapped_zone(c, wa, c_entry)

        if target_zone is not None:
            if c_zone == target_zone and not point_in_rect(sx, sy, crect):
                candidates.append((0, c.get("focusHistoryID", 999), c))
        else:
            if point_in_rect(cx, cy, crect) and not point_in_rect(sx, sy, crect):
                is_snap = 1 if (c_zone is not None or has_snapped_tag(c)) else 0
                candidates.append((is_snap, c.get("focusHistoryID", 999), c))

    if not candidates:
        return None
    candidates.sort(key=lambda item: (item[0], item[1]))
    return candidates[0][2]


def handle_drag_release(
    zone: str | None = None,
    start_mon_id: int = -1,
    drag_addr: str | None = None,
    start_snapshot: dict | None = None,
    release_cursor: tuple[int, int] | None = None,
):
    clients = hyprctl_json("clients") or []
    monitors = hyprctl_json("monitors") or []
    if not monitors:
        return

    win = None
    if drag_addr:
        for c in clients:
            if c.get("address") == drag_addr:
                win = c
                break
    if win is None:
        win = hyprctl_json("activewindow")
    if not win or not win.get("address") or win.get("fullscreen") == 2:
        return

    if release_cursor is None:
        cursor = hyprctl_json("cursorpos")
        if not cursor:
            return
        raw_cx, raw_cy = int(cursor["x"]), int(cursor["y"])
    else:
        raw_cx, raw_cy = release_cursor

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

    start_mon = find_monitor_by_id(monitors, start_mon_id) if start_mon_id >= 0 else None
    start_wa = compute_workarea(start_mon) if start_mon else wa

    # Resolve dragged window's pre-drag slot (either exact snap slot or initial floating rect)
    snap_entry = (start_snapshot or {}).get("entry") or state.get(addr_raw)
    if start_snapshot:
        sx = int(start_snapshot["sx"])
        sy = int(start_snapshot["sy"])
        start_ws = start_snapshot.get("ws", win_ws)
        start_floating = bool(start_snapshot.get("floating", win.get("floating", False)))
        start_at = start_snapshot["at"]
        start_size = start_snapshot["size"]
        start_geom_win = {"at": start_at, "size": start_size, "floating": start_floating, "fullscreen": 0}
        start_zone = infer_snapped_zone(start_geom_win, start_wa, snap_entry)
    else:
        sx, sy = cx, cy
        start_ws = win_ws
        start_floating = bool(win.get("floating", False))
        start_at = win.get("at") or [wa["ax"], wa["ay"]]
        start_size = win.get("size") or [int(wa["aw"] * 0.65), int(wa["ah"] * 0.70)]
        start_zone = infer_snapped_zone(win, start_wa, snap_entry)

    # Check if dropping onto another open window should swap both windows' slots
    swap_target = None
    if target_ws is not None and (start_floating or win.get("floating", False) or target_zone is not None):
        swap_target = find_swap_target(
            clients, addr_raw, int(target_ws), cx, cy, sx, sy, wa, state, target_zone
        )

    if swap_target is not None:
        t_addr = swap_target["address"]
        t_entry = state.get(t_addr)
        t_zone = target_zone or infer_snapped_zone(swap_target, wa, t_entry)
        t_box = zone_box(wa, t_zone) if t_zone else rect_of(swap_target)
        if not t_box:
            t_box = rect_of(swap_target)

        if start_zone:
            s_box = zone_box(start_wa, start_zone) or (int(start_at[0]), int(start_at[1]), int(start_size[0]), int(start_size[1]))
        else:
            s_box = (int(start_at[0]), int(start_at[1]), int(start_size[0]), int(start_size[1]))

        drag_pre_w = (snap_entry or {}).get("pre_w") or int(start_size[0])
        drag_pre_h = (snap_entry or {}).get("pre_h") or int(start_size[1])
        targ_pre_w = (t_entry or {}).get("pre_w") or int((swap_target.get("size") or [0, 0])[0])
        targ_pre_h = (t_entry or {}).get("pre_h") or int((swap_target.get("size") or [0, 0])[1])

        drag_becomes_snapped = t_zone is not None
        targ_becomes_snapped = start_zone is not None

        if drag_becomes_snapped:
            state[addr_raw] = {"zone": t_zone, "pre_w": int(drag_pre_w), "pre_h": int(drag_pre_h)}
        else:
            state.pop(addr_raw, None)

        if targ_becomes_snapped:
            state[t_addr] = {"zone": start_zone, "pre_w": int(targ_pre_w), "pre_h": int(targ_pre_h)}
        else:
            state.pop(t_addr, None)
        save_snap_state(state)

        cmds = []
        cmds.extend(build_place_cmds(swap_target, s_box, start_ws, snapped=targ_becomes_snapped))
        cmds.extend(build_place_cmds(win, t_box, target_ws, snapped=drag_becomes_snapped))
        if not drag_becomes_snapped:
            cmds.append(f"dispatch hl.dsp.window.alter_zorder({{ mode = 'top', window = '{addr}' }})")
        if not targ_becomes_snapped:
            cmds.append(f"dispatch hl.dsp.window.alter_zorder({{ mode = 'top', window = 'address:{t_addr}' }})")

        ws_set = {int(target_ws)}
        if start_ws is not None:
            ws_set.add(int(start_ws))
        cmds.extend(enforce_floating_above_snapped_cmds(
            clients, state, monitors, ws_set,
            override_snapped={addr_raw: drag_becomes_snapped, t_addr: targ_becomes_snapped},
        ))
        cmds.append(f"dispatch hl.dsp.focus({{ window = '{addr}' }})")
        if drag_becomes_snapped:
            # Re-run bottom push after focus() raises the newly focused snapped window
            cmds.extend(enforce_floating_above_snapped_cmds(
                clients, state, monitors, ws_set,
                override_snapped={addr_raw: drag_becomes_snapped, t_addr: targ_becomes_snapped},
            ))
        hyprctl_batch(cmds)
        return

    # Snap into corner/edge/maximize zone
    if target_zone:
        box = zone_box(wa, target_zone)
        if not box:
            return

        cmds = []
        override_snapped = {addr_raw: True}

        # When snapping into a corner over a window occupying that side's 50% half,
        # automatically shrink the covered 50% window into the complementary opposite corner.
        split_pair = {
            "top_right":    ("right", "bottom_right"),
            "bottom_right": ("right", "top_right"),
            "top_left":     ("left",  "bottom_left"),
            "bottom_left":  ("left",  "top_left"),
        }.get(target_zone)
        if split_pair and target_ws is not None:
            half_zone, comp_zone = split_pair
            comp_box = zone_box(wa, comp_zone)
            if comp_box:
                for c in clients:
                    c_addr = c.get("address", "")
                    if (
                        not c_addr
                        or c_addr == addr_raw
                        or not c.get("mapped")
                        or c.get("hidden")
                        or c.get("fullscreen", 0) != 0
                        or (c.get("workspace") or {}).get("id") != int(target_ws)
                    ):
                        continue
                    c_entry = state.get(c_addr)
                    if infer_snapped_zone(c, wa, c_entry) == half_zone:
                        c_pre_w = (c_entry or {}).get("pre_w") or int(wa["aw"] * 0.65)
                        c_pre_h = (c_entry or {}).get("pre_h") or int(wa["ah"] * 0.70)
                        state[c_addr] = {"zone": comp_zone, "pre_w": int(c_pre_w), "pre_h": int(c_pre_h)}
                        override_snapped[c_addr] = True
                        cmds.extend(build_place_cmds(c, comp_box, int(target_ws), snapped=True))

        entry = state.get(addr_raw)
        if not entry:
            if start_floating and win.get("fullscreen", 0) == 0 and start_zone is None:
                pre_w, pre_h = int(start_size[0]), int(start_size[1])
            else:
                pre_w, pre_h = int(wa["aw"] * 0.65), int(wa["ah"] * 0.70)
            entry = {"pre_w": pre_w, "pre_h": pre_h}
        entry["zone"] = target_zone
        state[addr_raw] = entry
        save_snap_state(state)

        cmds.extend(build_place_cmds(win, box, target_ws, snapped=True))
        cmds.append(f"dispatch hl.dsp.focus({{ window = '{addr}' }})")
        if target_ws is not None:
            cmds.extend(enforce_floating_above_snapped_cmds(
                clients, state, monitors, {int(target_ws)}, override_snapped=override_snapped
            ))
        hyprctl_batch(cmds)
        return

    # Dropped outside snap zones: if window was snapped/maximized, restore pre-snap floating size
    entry = state.pop(addr_raw, None)
    was_snapped = entry is not None or start_zone is not None or win.get("fullscreen", 0) == 1
    if not was_snapped and win.get("floating", False):
        was_snapped = looks_like_snapped_geometry(win, start_wa)

    if entry is not None:
        save_snap_state(state)

    if was_snapped:
        rw = int(entry["pre_w"]) if entry and entry.get("pre_w") else int(wa["aw"] * 0.65)
        rh = int(entry["pre_h"]) if entry and entry.get("pre_h") else int(wa["ah"] * 0.70)
        rw = max(320, min(rw, wa["aw"]))
        rh = max(240, min(rh, wa["ah"]))

        rx = max(wa["ax"], min(cx - rw // 2, wa["ax"] + wa["aw"] - rw))
        ry = max(wa["ay"], min(cy - rh // 4, wa["ay"] + wa["ah"] - rh))

        cmds = build_place_cmds(win, (rx, ry, rw, rh), target_ws, snapped=False)
        cmds.append(f"dispatch hl.dsp.window.alter_zorder({{ mode = 'top', window = '{addr}' }})")
        cmds.append(f"dispatch hl.dsp.focus({{ window = '{addr}' }})")
        hyprctl_batch(cmds)
        return

    # Regular unsnapped floating drag: enforce workspace ownership & keep floating on top of snapped windows
    if win.get("floating", False):
        wx, wy, ww, wh = rect_of(win)
        w_cx = int(wx + ww / 2)
        w_cy = int(wy + wh / 2)
        center_mon = find_monitor_at(monitors, w_cx, w_cy)
        cmds = []
        dest_ws = win_ws
        if center_mon:
            center_ws = (center_mon.get("activeWorkspace") or {}).get("id")
            if center_ws and win_ws != center_ws:
                dest_ws = center_ws
                cmds.append(f"dispatch hl.dsp.window.move({{ workspace = {int(center_ws)}, follow = false, window = '{addr}' }})")
        if has_snapped_tag(win):
            cmds.append(f"dispatch hl.dsp.window.tag({{ tag = '-{SNAPPED_TAG}', window = '{addr}' }})")
        cmds.append(f"dispatch hl.dsp.window.alter_zorder({{ mode = 'top', window = '{addr}' }})")
        if dest_ws is not None and cmds:
            cmds.append(f"dispatch hl.dsp.focus({{ window = '{addr}' }})")
        hyprctl_batch(cmds)


def snapshot_drag_start(sx: int, sy: int, fds: list[int]) -> tuple[dict | None, bool]:
    """
    Capture pre-drag geometry of the clicked window.
    If pointer pressed over an unfocused background window, briefly wait (~18 ms)
    for Hyprland to switch focus while watching for early release.
    Returns (snapshot_or_None, already_released_bool).
    """
    win = hyprctl_json("activewindow")
    if win and win.get("address") and point_in_rect(sx, sy, rect_of(win)):
        pass
    else:
        # Wait up to 18ms for focus switch without missing fast button-up events
        deadline = time.monotonic() + 0.018
        while True:
            rem = deadline - time.monotonic()
            if rem <= 0:
                break
            readable, _, _ = select.select(fds, [], [], rem)
            for fd in readable:
                while True:
                    try:
                        chunk = os.read(fd, EVENT_STRUCT.size * 16)
                    except (BlockingIOError, OSError):
                        break
                    if not chunk:
                        break
                    off = 0
                    while off + EVENT_STRUCT.size <= len(chunk):
                        _, _, ev_type, code, val = EVENT_STRUCT.unpack_from(chunk, off)
                        off += EVENT_STRUCT.size
                        if ev_type == EV_KEY and code == BTN_LEFT and val == 0:
                            return None, True
        win = hyprctl_json("activewindow")

    if not win or not win.get("address") or win.get("fullscreen") == 2:
        return None, False

    state = load_snap_state()
    addr = win["address"]
    return {
        "addr": addr,
        "at": list(win.get("at") or [0, 0]),
        "size": list(win.get("size") or [0, 0]),
        "floating": bool(win.get("floating", False)),
        "ws": (win.get("workspace") or {}).get("id"),
        "mon_id": int(win.get("monitor", -1)),
        "sx": sx,
        "sy": sy,
        "entry": state.get(addr),
    }, False


def sync_initial_tags_and_zorder():
    """Ensure persisted snapped windows stay tagged & below floating windows across reloads."""
    state = load_snap_state()
    clients = hyprctl_json("clients") or []
    monitors = hyprctl_json("monitors") or []
    if not clients or not monitors:
        return

    cmds = []
    workspaces: set[int] = set()
    alive_addrs = {c.get("address") for c in clients if c.get("address")}

    # Prune closed windows from snap state
    stale = [k for k in state if k not in alive_addrs]
    if stale:
        for k in stale:
            state.pop(k, None)
        save_snap_state(state)

    for c in clients:
        addr = c.get("address", "")
        if addr in state and not has_snapped_tag(c):
            cmds.append(f"dispatch hl.dsp.window.tag({{ tag = '+{SNAPPED_TAG}', window = 'address:{addr}' }})")
        ws_id = (c.get("workspace") or {}).get("id")
        if ws_id is not None:
            workspaces.add(int(ws_id))

    cmds.extend(enforce_floating_above_snapped_cmds(clients, state, monitors, workspaces))
    hyprctl_batch(cmds)


def run_daemon():
    """
    Persistent low-overhead input watcher supporting BOTH SUPER+LMB AND direct CSD titlebar
    drags (like Chrome/GTK/Qt) without holding SUPER.
    """
    acquire_single_instance()
    sync_initial_tags_and_zorder()

    def close_fds(fds: list[int]):
        for fd in fds:
            try:
                os.close(fd)
            except OSError:
                pass

    def open_fds() -> list[int]:
        opened = []
        for p in find_pointer_event_devices():
            try:
                opened.append(os.open(p, os.O_RDONLY | os.O_NONBLOCK))
            except OSError:
                continue
        return opened

    fds = open_fds()
    last_refresh = time.monotonic()
    dragging = False
    drag_snapshot: dict | None = None

    try:
        while True:
            if not fds or (not dragging and time.monotonic() - last_refresh >= DEVICE_REFRESH_S):
                close_fds(fds)
                fds = open_fds()
                last_refresh = time.monotonic()
                if not fds:
                    time.sleep(1.0)
                    continue

            try:
                readable, _, _ = select.select(fds, [], [], DEVICE_REFRESH_S)
            except (InterruptedError, ValueError, OSError):
                close_fds(fds)
                fds = open_fds()
                dragging = False
                drag_snapshot = None
                continue

            for fd in readable:
                while True:
                    try:
                        chunk = os.read(fd, EVENT_STRUCT.size * 32)
                    except BlockingIOError:
                        break
                    except OSError:
                        close_fds(fds)
                        fds = open_fds()
                        dragging = False
                        drag_snapshot = None
                        break
                    if not chunk:
                        break

                    off = 0
                    while off + EVENT_STRUCT.size <= len(chunk):
                        _, _, ev_type, code, val = EVENT_STRUCT.unpack_from(chunk, off)
                        off += EVENT_STRUCT.size
                        if ev_type != EV_KEY or code != BTN_LEFT:
                            continue

                        if val == 1 and not dragging:
                            if not is_snap_feature_enabled():
                                continue
                            cur = hyprctl_json("cursorpos")
                            if not cur:
                                continue
                            sx, sy = int(cur["x"]), int(cur["y"])
                            snap, released_early = snapshot_drag_start(sx, sy, fds)
                            if released_early or snap is None:
                                dragging = False
                                drag_snapshot = None
                            else:
                                dragging = True
                                drag_snapshot = snap

                        elif val == 0 and dragging:
                            snap = drag_snapshot
                            dragging = False
                            drag_snapshot = None
                            if not snap or not is_snap_feature_enabled():
                                continue

                            time.sleep(0.02)
                            cur = hyprctl_json("cursorpos")
                            if not cur:
                                continue
                            ex, ey = int(cur["x"]), int(cur["y"])
                            if abs(ex - snap["sx"]) <= DRAG_MIN_PX and abs(ey - snap["sy"]) <= DRAG_MIN_PX:
                                continue

                            clients = hyprctl_json("clients") or []
                            end_win = next((c for c in clients if c.get("address") == snap["addr"]), None)
                            if not end_win:
                                continue

                            end_at = end_win.get("at") or [0, 0]
                            end_sz = end_win.get("size") or [0, 0]
                            moved = (
                                abs(int(end_at[0]) - int(snap["at"][0])) > MOVE_TOL_PX
                                or abs(int(end_at[1]) - int(snap["at"][1])) > MOVE_TOL_PX
                            )
                            resized = (
                                abs(int(end_sz[0]) - int(snap["size"][0])) > RESIZE_TOL_PX
                                or abs(int(end_sz[1]) - int(snap["size"][1])) > RESIZE_TOL_PX
                            )
                            # Ignore clicks, text selection, scrollbars, tab-bar clicks, and border resizes
                            if not moved or resized:
                                continue

                            handle_drag_release(
                                start_mon_id=snap["mon_id"],
                                drag_addr=snap["addr"],
                                start_snapshot=snap,
                                release_cursor=(ex, ey),
                            )
    finally:
        close_fds(fds)


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
    if len(sys.argv) >= 2 and sys.argv[1] == "--daemon":
        run_daemon()
    elif len(sys.argv) >= 4 and sys.argv[1] in ("--wait-release", "--tiled-drag"):
        sx, sy = int(float(sys.argv[2])), int(float(sys.argv[3]))
        start_mon_id = int(sys.argv[4]) if len(sys.argv) >= 5 else -1
        if not wait_for_pointer_release():
            return
        time.sleep(0.03)
        cursor = hyprctl_json("cursorpos")
        if not cursor:
            return
        ex, ey = int(cursor["x"]), int(cursor["y"])
        if abs(ex - sx) <= DRAG_MIN_PX and abs(ey - sy) <= DRAG_MIN_PX:
            return
        handle_drag_release(start_mon_id=start_mon_id, release_cursor=(ex, ey))
    elif len(sys.argv) >= 3 and sys.argv[1] == "--snap":
        handle_drag_release(zone=sys.argv[2])


if __name__ == "__main__":
    main()
