-- Title bars (the hyprbars plugin), styled from the
-- current Omarchy theme so they read as part of the desktop: the theme's
-- darker background (so a bar still reads as frame above a terminal of the
-- plain background), the title in the theme's foreground, and Windows-style
-- caption buttons (minimize, maximize, close) as plain glyphs. The focus
-- border wraps bar and window as one frame and shows which window is active.
-- Double-click the bar to maximize or restore; drag it to move the window.
-- `omarchy theme set` reloads Hyprland, so the bars follow the theme.
--
-- This file never loads the plugin. Loading it here hung the login once: the
-- plugin reloads the config as it initialises, and a config that loads it
-- mid-startup re-enters itself. ~/.config/omarchy/titlebars-load (run from
-- hypr/desktop/autostart.lua) loads it once the desktop is up, preferring the locally
-- fixed build (~/.config/omarchy/hyprland-plugins/build); that reload runs this
-- file again with the plugin present, and the bars get styled. On/off:
-- ~/.config/omarchy/titlebars, or Super+Space > Setup > Taskbar > Title Bars.

if not (hl.plugin and hl.plugin.hyprbars) then
  return
end

-- Apps that draw their own title bar (Edge, VS Code, ...) get no hyprbars bar:
-- generated from ~/.config/omarchy/titlebar-off.json by taskbar-action
-- (right-click a taskbar icon > Hide/Show title bar). Only valid while the
-- plugin is loaded, hence here.
-- Per-app "no title bar" rules, generated from your choices (right-click a
-- taskbar icon > Hide title bar) into ~/.config/hypr/titlebar-rules.lua.
pcall(require, "hypr.titlebar-rules")

local function theme_colors()
  local colors = {}
  local file = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/colors.toml", "r")
  if not file then
    return colors
  end
  for line in file:lines() do
    local key, hex = line:match('^%s*([%w_]+)%s*=%s*"#(%x%x%x%x%x%x)"')
    if key then
      colors[key] = hex
    end
  end
  file:close()
  return colors
end

local c = theme_colors()
local background = c.dark_background or c.background or "1e1e2e"
local foreground = c.foreground or "cdd6f4"

hl.config({
  plugin = {
    hyprbars = {
      bar_height = 30,
      bar_color = "rgb(" .. background .. ")",
      ["col.text"] = "rgb(" .. foreground .. ")",
      bar_text_font = "JetBrainsMono Nerd Font",
      bar_text_size = 11,
      bar_text_align = "left",
      bar_padding = 10,
      bar_button_padding = 12,
      bar_buttons_alignment = "right",
      bar_precedence_over_border = true,
      bar_part_of_window = true,
      bar_blur = false,
      icon_on_hover = false,
      -- The plugin paints this behind the glyph on unfocused windows; keep it
      -- clear so buttons look the same everywhere.
      inactive_button_color = "rgba(00000000)",
      on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })']],
    },
  },
})

-- Buttons are added right to left, so close sits at the edge like Windows.
-- The plugin clears them before every config reload, so they're re-added here.
local function button(icon, action)
  hl.plugin.hyprbars.add_button({
    bg_color = "rgba(00000000)",
    fg_color = "rgb(" .. foreground .. ")",
    size = 17,
    icon = icon,
    action = action,
  })
end

button("\u{eab8}", [[hyprctl dispatch 'hl.dsp.window.close()']])
button("\u{eab9}", [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })']])
button("\u{eaba}", os.getenv("HOME") .. "/.config/omarchy/window-minimize-now")
