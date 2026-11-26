#!/usr/bin/env bash
# toggle.sh - Clean Single-Instance Toggle for hyprquickpaper
# If already running, closes the instance. If not running, launches it.

target_pids=""
for pid in $(pidof quickshell 2>/dev/null); do
    if grep -q "hyprquickpaper" "/proc/$pid/cmdline" 2>/dev/null; then
        target_pids="$pid $target_pids"
    fi
done

if [[ -n "$target_pids" ]]; then
    for pid in $target_pids; do
        qs ipc --pid "$pid" call wallpaperPicker close 2>/dev/null || kill "$pid" 2>/dev/null || true
    done
    exit 0
else
    qs -n -p "$HOME/.config/quickshell/hyprquickpaper" &
    exit 0
fi
