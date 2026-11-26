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
