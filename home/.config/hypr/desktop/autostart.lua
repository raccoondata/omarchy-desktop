-- omarchy-desktop: started with the session.

local D = os.getenv("HOME") .. "/.config/omarchy/"

-- Title bars (desktop/titlebars.lua): load hyprbars once the desktop is up,
-- never from the config itself (the plugin reloads the config as it loads;
-- doing that mid-startup hung the login once). The loader waits for the
-- shell, retries and logs to ~/.local/state/omarchy/titlebars.log. To skip
-- it, e.g. from a TTY if a Hyprland update ever breaks the plugin:
-- touch ~/.config/omarchy/titlebars-off
o.exec_on_start(D .. "titlebars-load")

-- With SDDM autologin on (for remote access after a reboot), lock at once so
-- the desktop still needs the password. Does nothing on a normal login.
o.exec_on_start(D .. "lock-on-autologin")
