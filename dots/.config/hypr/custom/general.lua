-- MONITOR CONFIG:
-- Laptop screen (eDP-1) on the LEFT (0x0, normal rotation)
-- External monitor (HDMI-A-2) on the RIGHT (1920x0, rotated 180 degrees)
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "0x0",
    scale = 1,
    transform = 0
})
hl.monitor({
    output = "HDMI-A-2",
    mode = "preferred",
    position = "1920x0",
    scale = 1,
    transform = 2
})
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1
})

-- Custom general, decoration, and cursor configurations for Hyprland
-- Overrides defaults from hyprland.general

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 6,
        border_size = 2
    },
    decoration = {
        -- Window kotak (sudut siku 90 derajat tanpa rounded corners)
        rounding = 0,
        rounding_power = 2,

        -- Opacity / Transparansi: aktif 95%, tidak aktif 88%
        active_opacity = 0.95,
        inactive_opacity = 0.88,
        fullscreen_opacity = 1.0,

        -- Blur halus dan ringan (dikurangi agar jernih dan hemat daya/GPU)
        blur = {
            enabled = true,
            xray = false,
            size = 3,
            passes = 2,
            noise = 0.0,
            contrast = 0.9,
            brightness = 1.0,
            vibrancy = 0.15,
            popups = true
        },

        -- Bayangan efisien
        shadow = {
            enabled = true,
            range = 15,
            render_power = 2,
            color = "rgba(00000025)"
        },

        -- Dim inactive dinaikkan keterangannya (dim_strength lebih ringan di 0.08 agar tidak terlalu gelap)
        dim_inactive = true,
        dim_strength = 0.08,
        dim_special = 0.2
    },
    cursor = {
        -- Mengatasi kursor glitch & macet sebelum ujung kanan pada multi-GPU & layar dirotasi 180 derajat
        no_hardware_cursors = true
    }
})
