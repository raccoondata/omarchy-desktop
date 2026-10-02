-- omarchy-desktop: keybindings (see its README > Keybindings). Loaded from
-- hypr/desktop.lua after your own hypr/bindings.lua, so these win; put your
-- own changes in a file loaded after hypr.desktop (updates replace this file).
--
-- Which ones: omarchy_desktop_keys (hypr/desktop.lua, from keys= in
-- ~/.config/omarchy/desktop.conf; `omarchy-desktop keys` changes it):
--   all   everything below
--   new   only the ones that don't change any Omarchy key (NEW below): the
--         Super menu, ask about selected text, double-tap extras, ...
--   off   none; Omarchy's keys exactly as they were
-- The mouse behaviours the taskbar needs are in core.lua, always on.

local D = os.getenv("HOME") .. "/.config/omarchy/"
local keys = omarchy_desktop_keys or "all"
local ALL = keys == "all"
local NEW = ALL or keys == "new"


-- Window keys (Super+arrows, Super+WASD, Super+Q twice, Super+Tab, Super+G
-- twice) are the Windows plugin's (plugins/windows/hypr/).

if ALL then
  -- CTRL+ALT+DELETE: the task manager (btop, floating; focused if it's
  -- already open), like Windows. It was Omarchy's "Close all windows".
  hl.unbind("CTRL + ALT + DELETE")
  o.bind("CTRL + ALT + DELETE", "Task manager", { tui = "btop", focus = true })
end

if NEW then
  -- CTRL+ALT+ESCAPE opens text console 3 (same as Ctrl+Alt+F3), where `rescue`
  -- helps when the desktop misbehaves. Needs /etc/sudoers.d/50-chvt
  -- (passwordless `sudo chvt`).
  o.bind("CTRL + ALT + ESCAPE", "Rescue console (like Ctrl+Alt+F3)", "sudo -n /usr/bin/chvt 3")
end

if NEW then
  -- SUPER+CTRL+L: lock with the "Locked" card first (~/.config/omarchy/lock), so
  -- a remote RustDesk viewer sees that rather than the desktop.
  hl.unbind("SUPER + CTRL + L")
  o.bind("SUPER + CTRL + L", "Lock system", D .. "lock")
end

if NEW then
  -- SUPER+SHIFT+ESCAPE twice within 2s reboots into Windows once (firmware
  -- BootNext); a single press only shows a warning. Also in the system menu.
  o.bind("SUPER + SHIFT + ESCAPE", "Reboot into Windows (press twice)", D .. "reboot-to-windows --tap")
end

-- The Super menu (double-tap Super) is the Super Menu plugin's: it adds its
-- own key (plugins/super-menu/hypr/super_menu.lua).

-- Super+Return twice is the Taskbar plugin's (plugins/taskbar/hypr/).
