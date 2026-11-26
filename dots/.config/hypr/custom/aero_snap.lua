-- Windows-like 8-zone Aero Snap for Hyprland (0.57+ Lua API).
-- Controlled via Settings -> Interface -> Window management (raven-dots).

local snap_enabled = true
if is_file_exists(HOME .. "/.config/hypr/custom/aero_snap_enabled.lua") then
    snap_enabled = dofile(HOME .. "/.config/hypr/custom/aero_snap_enabled.lua")
end

if not snap_enabled then
    return
end

local script_path = HOME .. "/.config/hypr/custom/scripts/aero_snap.py"

hl.unbind("SUPER + mouse:272")

hl.bind("SUPER + mouse:272", function()
    local pos = hl.get_cursor_pos()
    local x = pos and math.floor(pos.x) or 0
    local y = pos and math.floor(pos.y) or 0

    local w = hl.get_active_window()
    local mon = (w and w.monitor) or hl.get_monitor_at_cursor()
    local mon_id = mon and mon.id or -1
    local ws_id = (w and w.workspace) and w.workspace.id or -1

    hl.exec_cmd(string.format(
        "python3 %q --wait-release %d %d %d %d",
        script_path, x, y, mon_id, ws_id
    ))
end, { non_consuming = true, description = "Window: Aero Snap on drag" })

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
