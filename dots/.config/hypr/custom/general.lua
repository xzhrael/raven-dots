-- Monitor layout: eDP-1 on the left (0x0), HDMI-A-2 on the right (1920x0, rotated 180 deg).
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

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 6,
        border_size = 2
    },
    decoration = {
        -- Sharp 90-degree corners.
        rounding = 0,
        rounding_power = 2,

        active_opacity = 0.95,
        inactive_opacity = 0.88,
        fullscreen_opacity = 1.0,

        -- Light blur keeps text crisp while reducing GPU power draw.
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

        shadow = {
            enabled = true,
            range = 15,
            render_power = 2,
            color = "rgba(00000025)"
        },

        -- Mild dimming keeps unfocused windows legible.
        dim_inactive = true,
        dim_strength = 0.08,
        dim_special = 0.2
    },
    cursor = {
        -- Software cursor avoids glitches and right-edge stalls on multi-GPU 180-deg rotated displays.
        no_hardware_cursors = true
    }
})
