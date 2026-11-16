-- Custom Window Rules
-- Enable blur on regular application windows
hl.window_rule({match = {class = ".*"}, no_blur = false})

-- Fullscreen protection rules: no dimming, completely opaque
hl.window_rule({match = {fullscreen = 1}, no_dim = true, opaque = true})

-- Media player & browser video protections (YouTube/Netflix/MPV/VLC)
hl.window_rule({match = {class = "^(mpv|vlc)$"}, no_dim = true, opaque = true})
hl.window_rule({match = {title = ".*(YouTube|Netflix|Twitch|Prime Video).*"}, no_dim = true})
