#!/usr/bin/env bash
# Usage: commands.sh <wallpaper-file> [transition] [duration]
img="$1"
[[ -f "$img" ]] || { echo "commands.sh: not a file: $img" >&2; exit 1; }

# Save last wallpaper path in cache
mkdir -p "$HOME/.cache/43pr"
echo "$img" > "$HOME/.cache/43pr/last-wallpaper"

# Call system switchwall.sh to set wallpaper and run Matugen theme compilation
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"
if [ -f "$SWITCHWALL" ]; then
    current_mode="dark"
    if command -v gsettings >/dev/null 2>&1; then
        gs_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$gs_mode" == "prefer-light" ]]; then
            current_mode="light"
        elif [[ "$gs_mode" == "prefer-dark" ]]; then
            current_mode="dark"
        fi
    fi
    bash "$SWITCHWALL" --image "$img" --mode "$current_mode"
fi

# Fallback in case switchwall is not present or awww/swww is installed
if command -v awww >/dev/null 2>&1; then
    awww img "$img" -t "${2:-outer}" --transition-duration "${3:-1}"
elif command -v swww >/dev/null 2>&1; then
    swww img "$img" --transition-type "${2:-outer}" --transition-duration "${3:-1}"
fi
