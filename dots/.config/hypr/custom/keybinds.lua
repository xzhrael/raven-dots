hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

hl.bind("SUPER + W", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/quickshell/hyprquickpaper/toggle.sh"), {description = "Wallpaper: Toggle 3D Coverflow picker"} )

-- 8-zone corner/edge snapping on drag (titlebar or SUPER + LMB).
if is_file_exists(HOME .. "/.config/hypr/custom/aero_snap.lua") then
    require("custom.aero_snap")
end
