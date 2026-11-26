if is_file_exists(HOME .. "/.config/hypr/custom/floating_mode.lua") then
    require("custom.floating_mode")
end

hl.window_rule({match = {class = ".*"}, no_blur = false})

-- Keep fullscreen and video windows opaque and undimmed during playback.
hl.window_rule({match = {fullscreen = 1}, no_dim = true, opaque = true})
hl.window_rule({match = {class = "^(mpv|vlc)$"}, no_dim = true, opaque = true})
hl.window_rule({match = {title = ".*(YouTube|Netflix|Twitch|Prime Video).*"}, no_dim = true})
