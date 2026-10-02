-- omarchy-desktop (installed by its install.sh; `omarchy-desktop update`
-- keeps it current): the taskbar/Super-menu desktop's Hyprland side. hyprland.lua loads
-- this after your own files, so your monitors/input/bindings stay yours and
-- these add to (or override) them. Updates replace hypr/desktop/*; your own
-- changes belong in the files outside it.
-- Which keybindings (desktop.conf keys=all|new|off; see desktop/bindings.lua).
omarchy_desktop_keys = "all"
do
  local file = io.open(os.getenv("HOME") .. "/.config/omarchy/desktop.conf", "r")
  if file then
    for line in file:lines() do
      local value = line:match("^keys=(%a+)$")
      if value == "all" or value == "new" or value == "off" then
        omarchy_desktop_keys = value
      end
    end
    file:close()
  end
end

require("hypr.desktop.input")
require("hypr.desktop.bindings")
require("hypr.desktop.autostart")
require("hypr.desktop.remote")
-- The mouse settings (hypr/mouse.lua) are loaded by Desktop Core, the
-- workspace pins (hypr/workspace-pins.lua) by the Taskbar plugin.
