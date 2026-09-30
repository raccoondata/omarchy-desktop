-- omarchy-desktop: REMOTE, the virtual screen ~/.config/omarchy/remote-screen
-- adds while no monitor is connected (switched off), so remote desktop
-- (RustDesk) has something to show. Only matters with that service running.
hl.monitor({ output = "REMOTE", mode = "2560x1440@60", position = "auto", scale = 1 })
