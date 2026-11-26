#!/usr/bin/env bash
set -euo pipefail

CUSTOM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/custom"
FLOAT_FILE="$CUSTOM_DIR/floating_mode.lua"
SNAP_FILE="$CUSTOM_DIR/aero_snap_enabled.lua"

mkdir -p "$CUSTOM_DIR"

write_floating_file() {
    local enabled="$1"
    if [[ "$enabled" == "true" ]]; then
        cat > "$FLOAT_FILE" << 'EOF'
-- Managed by Settings (raven-dots): Default Floating Mode
-- Enabled: new application windows open floating and centered at a balanced size.

hl.window_rule({
    name = "raven-default-float",
    match = {
        class = ".*",
        float = false,
        fullscreen = false
    },
    float = true,
    center = true,
    size = { "(monitor_w*0.65)", "(monitor_h*0.70)" }
})
EOF
    else
        cat > "$FLOAT_FILE" << 'EOF'
-- Managed by Settings (raven-dots): Default Floating Mode
-- Disabled: Hyprland uses standard auto-tiling layout for new windows.
EOF
    fi
}

write_snap_file() {
    local enabled="$1"
    if [[ "$enabled" == "true" ]]; then
        printf -- "-- Managed by Settings (raven-dots): Drag Corner/Edge Snap toggle\nreturn true\n" > "$SNAP_FILE"
    else
        printf -- "-- Managed by Settings (raven-dots): Drag Corner/Edge Snap toggle\nreturn false\n" > "$SNAP_FILE"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --floating)
            write_floating_file "$2"
            shift 2
            ;;
        --snap)
            write_snap_file "$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

hyprctl reload >/dev/null 2>&1 || true
