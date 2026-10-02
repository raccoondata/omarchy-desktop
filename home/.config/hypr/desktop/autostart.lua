-- omarchy-desktop: started with the session.

local D = os.getenv("HOME") .. "/.config/omarchy/"

-- With SDDM autologin on (for remote access after a reboot), lock at once so
-- the desktop still needs the password. Does nothing on a normal login.
o.exec_on_start(D .. "lock-on-autologin")
