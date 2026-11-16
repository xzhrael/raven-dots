#!/usr/bin/env bash
# sync-theme.sh - Global Dark/Light Mode Synchronizer for Hyprland & Desktop Apps
# Ensures GTK3, GTK4/Libadwaita, Qt, Flatpak, and XDG Desktop Portals are 100% synchronized.

TARGET_MODE="$1"

if [[ -z "$TARGET_MODE" ]]; then
    CURRENT_GS=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
    if [[ "$CURRENT_GS" == "prefer-light" ]]; then
        TARGET_MODE="light"
    elif [[ "$CURRENT_GS" == "prefer-dark" ]]; then
        TARGET_MODE="dark"
    else
        # Fallback check from gtk-3.0 settings.ini
        if grep -q "gtk-application-prefer-dark-theme = 0" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null; then
            TARGET_MODE="light"
        else
            TARGET_MODE="dark"
        fi
    fi
fi

if [[ "$TARGET_MODE" == "light" ]]; then
    COLOR_SCHEME="prefer-light"
    GTK_THEME="adw-gtk3"
    PREFER_DARK_VAL="0"
else
    COLOR_SCHEME="prefer-dark"
    GTK_THEME="adw-gtk3-dark"
    PREFER_DARK_VAL="1"
fi

# 1. Update GSettings (GNOME / Portal interface)
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
fi

# 2. Update DConf directly to prevent caching mismatch
if command -v dconf >/dev/null 2>&1; then
    dconf write /org/gnome/desktop/interface/color-scheme "'$COLOR_SCHEME'" 2>/dev/null || true
    dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME'" 2>/dev/null || true
fi

# 3. Synchronize ~/.config/gtk-3.0/settings.ini and ~/.config/gtk-4.0/settings.ini
write_gtk_ini() {
    local target_file="$1"
    mkdir -p "$(dirname "$target_file")"
    cat > "$target_file" << EOF
[Settings]
gtk-theme-name = $GTK_THEME
gtk-application-prefer-dark-theme = $PREFER_DARK_VAL
gtk-icon-theme-name = Reversal-grey
gtk-font-name = Google Sans Flex Medium 11
gtk-cursor-theme-name = Bibata-Modern-Classic
gtk-cursor-theme-size = 24
EOF
}

write_gtk_ini "$HOME/.config/gtk-3.0/settings.ini"
write_gtk_ini "$HOME/.config/gtk-4.0/settings.ini"

# Also persist in dots repository if present
if [[ -d "$HOME/Projects/dots-hyprland/dots/.config" ]]; then
    write_gtk_ini "$HOME/Projects/dots-hyprland/dots/.config/gtk-3.0/settings.ini"
    write_gtk_ini "$HOME/Projects/dots-hyprland/dots/.config/gtk-4.0/settings.ini"
fi

# 4. Broadcast updated environment variables to DBus and Systemd user session
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME GTK_THEME="$GTK_THEME" 2>/dev/null || true
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME GTK_THEME 2>/dev/null || true
fi

# 5. Synchronize Flatpak application overrides
if command -v flatpak >/dev/null 2>&1; then
    flatpak --user override --env=GTK_THEME="$GTK_THEME" 2>/dev/null || true
fi

# 6. Notify / restart xdg-desktop-portal to pick up interface settings cleanly
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gtk 2>/dev/null || true
fi

exit 0
