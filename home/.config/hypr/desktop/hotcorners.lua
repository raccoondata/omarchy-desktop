-- Hot corners. Push the pointer into a corner of the screen and
-- ~/.config/omarchy/hotcorner runs whatever that corner is set to in
-- ~/.config/omarchy/hotcorners.conf (also Super+Space > Setup > Hot Corners):
-- show desktop, minimize/restore all, window switcher, menu, lock, or nothing.
-- The script also skips corners reached mid-drag and plays the corner ripple.
--
-- Hyprland has no pointer-motion event for Lua, so a cheap in-compositor timer
-- samples the cursor. Each corner fires once, then re-arms after the cursor
-- has moved rearm_px away from it.

local hotcorner = os.getenv("HOME") .. "/.config/omarchy/hotcorner"
local hit_px = 2
local rearm_px = 100
local fired = nil -- { name, x, y } of the corner that fired last

local function corner_at(pos)
  local monitor = hl.get_monitor_at(pos.x, pos.y)
  if not monitor then
    return nil
  end

  local left = monitor.x
  local top = monitor.y
  local right = monitor.x + monitor.width / monitor.scale
  local bottom = monitor.y + monitor.height / monitor.scale

  local vertical = nil
  if pos.y <= top + hit_px then
    vertical = "top"
  elseif pos.y >= bottom - 1 - hit_px then
    vertical = "bottom"
  end
  if not vertical then
    return nil
  end

  if pos.x <= left + hit_px then
    return { name = vertical .. "-left", x = left, y = vertical == "top" and top or bottom }
  elseif pos.x >= right - 1 - hit_px then
    return { name = vertical .. "-right", x = right, y = vertical == "top" and top or bottom }
  end
  return nil
end

hl.timer(function()
  local pos = hl.get_cursor_pos()
  if not pos then
    return
  end

  if fired then
    if (pos.x - fired.x) ^ 2 + (pos.y - fired.y) ^ 2 > rearm_px ^ 2 then
      fired = nil
    end
    return
  end

  local corner = corner_at(pos)
  if not corner then
    return
  end

  -- Swallow the corner (it still has to be left and re-entered) while a
  -- middle-dragged window is being dropped there, or while a game or video is
  -- truly fullscreen.
  fired = corner
  local active = hl.get_active_window()
  if o.middle_drag_active or (active and active.fullscreen == 2) then
    return
  end

  hl.exec_cmd(hotcorner .. " " .. corner.name)
end, { timeout = 50, type = "repeat" })
