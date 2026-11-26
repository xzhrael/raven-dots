-- Windows-like 8-zone Aero Snap, Drop-to-Swap, & Floating-on-Top for Hyprland (0.57+ Lua API).
-- Controlled via Settings -> Interface -> Window management (raven-dots).

local snap_enabled = true
if is_file_exists(HOME .. "/.config/hypr/custom/aero_snap_enabled.lua") then
    snap_enabled = dofile(HOME .. "/.config/hypr/custom/aero_snap_enabled.lua")
end

local script_path = HOME .. "/.config/hypr/custom/scripts/aero_snap.py"

if not snap_enabled then
    hl.exec_cmd("pkill -f 'aero_snap.py --daemon' || true")
    return
end

local SNAPPED_TAG = "raven_snapped"
local enforcing_zorder = false

local function has_snapped_tag(win)
    if not win or not win.tags then return false end
    for _, t in ipairs(win.tags) do
        if t == SNAPPED_TAG then return true end
    end
    return false
end

local function keep_floating_above_snapped(ws)
    if enforcing_zorder or not ws then return end
    local wins = hl.get_workspace_windows(ws)
    if not wins or #wins < 2 then return end

    local snapped = {}
    local floating_count = 0
    for _, w in ipairs(wins) do
        if w.mapped and not w.hidden and w.floating and (w.fullscreen or 0) == 0 then
            if has_snapped_tag(w) then
                table.insert(snapped, w)
            else
                floating_count = floating_count + 1
            end
        end
    end

    if floating_count == 0 or #snapped == 0 then return end

    enforcing_zorder = true
    -- Push most recently focused snapped first and oldest last so relative snapped order stays intact
    -- while every unsnapped floating window remains strictly on top.
    table.sort(snapped, function(a, b)
        return (a.focus_history_id or 0) < (b.focus_history_id or 0)
    end)
    for _, sw in ipairs(snapped) do
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = "address:" .. sw.address }))
    end
    enforcing_zorder = false
end

hl.on("window.active", function(win)
    local w = win or hl.get_active_window()
    if w and has_snapped_tag(w) then
        keep_floating_above_snapped(w.workspace)
    end
end)

hl.on("window.update_state", function(win, changes)
    if not win then return end
    if changes and changes.float == false and has_snapped_tag(win) then
        hl.dispatch(hl.dsp.window.tag({ tag = "-" .. SNAPPED_TAG, window = "address:" .. win.address }))
    end
    if win.workspace then
        keep_floating_above_snapped(win.workspace)
    end
end)

hl.on("window.move_to_workspace", function(win)
    if win and win.workspace then
        keep_floating_above_snapped(win.workspace)
    end
end)

-- Single persistent watcher handles both SUPER+LMB and direct CSD titlebar drags (e.g. Chrome)
hl.exec_cmd(string.format("python3 %q --daemon", script_path))

hl.unbind("SUPER + mouse:272")
hl.bind("SUPER + mouse:272", function()
    local w = hl.get_active_window()
    if w and not w.floating then
        local pos = hl.get_cursor_pos()
        local x = pos and math.floor(pos.x) or 0
        local y = pos and math.floor(pos.y) or 0
        local mon = w.monitor or hl.get_monitor_at_cursor()
        local mon_id = mon and mon.id or -1
        hl.exec_cmd(string.format("python3 %q --tiled-drag %d %d %d", script_path, x, y, mon_id))
    end
end, { non_consuming = true, description = "Window: Aero Snap on tiled drag" })

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
