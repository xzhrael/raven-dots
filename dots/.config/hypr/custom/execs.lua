-- Custom autostart commands for Hyprland
hl.on("hyprland.start", function ()
    -- Synchronize Dark/Light Mode & Portals for all GTK, Qt, and Flatpak applications
    hl.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/custom/scripts/sync-theme.sh")

    -- Single Themed Gate: Mengunci desktop saat pertama kali boot dengan tema raven-dots
    hl.exec_cmd("sleep 1.2 && loginctl lock-session")
end)
