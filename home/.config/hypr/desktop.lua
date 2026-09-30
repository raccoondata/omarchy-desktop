-- omarchy-desktop (installed by its install.sh; `omarchy-desktop update`
-- keeps it current): the taskbar/Super-menu desktop's Hyprland side. hyprland.lua loads
-- this after your own files, so your monitors/input/bindings stay yours and
-- these add to (or override) them. Updates replace hypr/desktop/*; your own
-- changes belong in the files outside it.
require("hypr.desktop.input")
require("hypr.desktop.bindings")
require("hypr.desktop.hotcorners")
require("hypr.desktop.titlebars")
require("hypr.desktop.autostart")
require("hypr.desktop.remote")
-- Written by the desktop's settings (yours; may not exist yet):
pcall(require, "hypr.mouse")             -- Taskbar & Desktop > Mouse
pcall(require, "hypr.workspace-pins")    -- right-click an icon > Always open on workspace
