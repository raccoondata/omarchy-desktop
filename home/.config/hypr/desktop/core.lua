-- omarchy-desktop: mouse behaviours the taskbar relies on, loaded whatever
-- keybindings you chose (bindings.lua).

-- Middle-drag by a window's top strip is the Windows plugin's
-- (plugins/windows/hypr/drag.lua).

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
