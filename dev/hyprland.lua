-- Disposable nested/headless probe only; never sourced by the user's desktop.
hl.monitor({ output = "", mode = "1280x720@60", position = "auto", scale = 1 })
hl.config({
    debug = { enable_stdout_logs = true, disable_logs = false },
    misc = { disable_hyprland_logo = true },
    xwayland = { enabled = false },
})
