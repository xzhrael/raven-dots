hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

-- Wallpaper: Toggle 3D Coverflow HyprQuickPaper (Buka jika tutup, tutup jika sudah buka)
hl.bind("SUPER + W", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/quickshell/hyprquickpaper/toggle.sh"), {description = "Wallpaper: Toggle 3D Coverflow picker"} )
