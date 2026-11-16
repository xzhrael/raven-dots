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
    kill $target_pids 2>/dev/null || true
    exit 0
else
    qs -n -p "$HOME/.config/quickshell/hyprquickpaper" &
    exit 0
fi
