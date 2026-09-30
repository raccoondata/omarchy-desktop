-- omarchy-desktop: mouse behaviours the taskbar and screenshot editor rely
-- on, loaded whatever keybindings you chose (bindings.lua).

-- Middle-drag a window by its top strip (tab bar, first terminal line) to move
-- it; drop it at a screen edge to dock it there, or on a taskbar workspace
-- number to send it there (both via the taskbar and the dragevents plugin). A middle click in the strip
-- that doesn't move is handed back to the app, so closing tabs still works.
-- Middle clicks anywhere else never touch the window manager: paste,
-- autoscroll and open-in-new-tab behave normally.
--
-- Hyprland swallows every press a mouse bind catches, so the bind is a function
-- that returns pass_event outside the strip. Inside it, Hyprland also swallows
-- the release, which is why a still click is replayed with send_key_state.
do
  local strip_px = 40
  local move_px = 10 -- same as binds.drag_threshold in input.lua
  local press = nil

  local function moved_far(pos)
    return (pos.x - press.x) ^ 2 + (pos.y - press.y) ^ 2 > move_px ^ 2
  end

  -- Watch the cursor while the button is held, so a drag that comes back to
  -- where it started still counts as a drag rather than a click.
  local tracker = hl.timer(function()
    local pos = press and hl.get_cursor_pos()
    if pos and moved_far(pos) then
      press.moved = true
    end
  end, { timeout = 16, type = "repeat" })
  tracker:set_enabled(false)

  -- Prefer the focused window: with follow_mouse it's the one under the
  -- cursor, and it's the one on top when floating windows overlap.
  local function window_at(pos)
    local monitor = hl.get_monitor_at(pos.x, pos.y)
    if not monitor then
      return nil
    end
    local active = hl.get_active_window()
    local found = nil
    for _, window in ipairs(hl.get_windows({ monitor = monitor })) do
      local at, size = window.at, window.size
      if window.visible and not window.hidden
        and pos.x >= at.x and pos.x < at.x + size.x
        and pos.y >= at.y and pos.y < at.y + size.y then
        if active and window.address == active.address then
          return window
        end
        if not found or (window.floating and not found.floating) then
          found = window
        end
      end
    end
    return found
  end

  hl.bind("mouse:274", function()
    if press then
      -- Release. Hyprland already ended the drag when the button came up.
      local moved = press.moved or moved_far(hl.get_cursor_pos() or press)
      press = nil
      o.middle_drag_active = false
      tracker:set_enabled(false)
      -- A real drag's drop (workspace number, screen edge) is handled by the
      -- taskbar, which hears about every window drag from the dragevents plugin.
      if not moved then
        hl.dispatch(hl.dsp.send_key_state({ mods = "", key = "mouse:274", state = "down" }))
        hl.dispatch(hl.dsp.send_key_state({ mods = "", key = "mouse:274", state = "up" }))
      end
      return
    end

    local pos = hl.get_cursor_pos()
    local window = pos and window_at(pos)
    if not window or pos.y - window.at.y >= strip_px then
      return { pass_event = true }
    end

    press = { x = pos.x, y = pos.y, moved = false }
    o.middle_drag_active = true
    tracker:set_enabled(true)
    hl.dispatch(hl.dsp.window.drag())
  end, { description = "Drag window by its top strip" })
end

-- Shift+click a taskbar icon: another window of that program (as middle-click
-- does). The bar never sees modifier keys (it never has keyboard focus), so
-- this tells it Shift was down; the click itself still goes through, here and
-- in apps (shift-click to select keeps working).
hl.bind("SHIFT + mouse:272", function()
  local pos = hl.get_cursor_pos()
  local monitor = pos and hl.get_monitor_at(pos.x, pos.y)
  if monitor and pos.y - monitor.y < 48 then
    hl.exec_cmd("omarchy-shell -q taskbar shiftClick")
  end
  return { pass_event = true }
end, { description = "Shift+click a taskbar icon: new window" })
-- Esc while the screenshot editor's ask panel/bar is up: in the editor, fold
-- the panel/bar away (the taskbar's EditorDock) instead of closing the editor
-- and the screenshot with it; a second Esc then closes the editor as usual.
-- Anywhere else Esc goes through untouched. Not bound normally: EditorDock
-- binds it (hyprctl eval) only while its panel/bar is showing, and sets
-- omarchy_screenshot_editor to the editor window's address.
-- The key's release is caught too (omarchy_screenshot_escape_release): a
-- release without its press makes the editor ignore the next Esc.
omarchy_screenshot_editor = ""
omarchy_screenshot_swallow = false
function omarchy_screenshot_escape()
  local window = hl.get_active_window()
  local address = window and tostring(window.address) or ""
  if address ~= "" and address:sub(1, 2) ~= "0x" then
    address = "0x" .. address
  end
  if omarchy_screenshot_editor ~= "" and address == omarchy_screenshot_editor then
    omarchy_screenshot_swallow = true
    hl.exec_cmd("omarchy-shell -q taskbar screenshotEscape")
    return
  end
  return { pass_event = true }
end
function omarchy_screenshot_escape_release()
  if omarchy_screenshot_swallow then
    omarchy_screenshot_swallow = false
    return
  end
  return { pass_event = true }
end
