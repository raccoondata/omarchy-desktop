-- omarchy-desktop: keybindings (see its README > Keybindings). Loaded from
-- hypr/desktop.lua after your own hypr/bindings.lua, so these win; put your
-- own changes in hypr/bindings.lua, not here (updates replace this file).

local D = os.getenv("HOME") .. "/.config/omarchy/"

-- Window navigation and controls.
-- SUPER+W and SUPER+S previously closed a window and toggled the scratchpad.
-- SUPER+Up and SUPER+Down previously focused the window above/below.
hl.unbind("SUPER + W")
hl.unbind("SUPER + S")
hl.unbind("SUPER + UP")
hl.unbind("SUPER + DOWN")
hl.unbind("SUPER + LEFT")
hl.unbind("SUPER + RIGHT")
hl.unbind("SUPER + SHIFT + UP")
hl.unbind("SUPER + SHIFT + DOWN")

o.bind("SUPER + W", "Focus window above", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + A", "Focus window left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + S", "Focus window below", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + D", "Focus window right", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + Q", "Close window (double-tap Q)", D .. "window-close-double-tap")
o.bind("SUPER + UP", "Maximize or restore window", D .. "window-maximize-or-restore")
o.bind("SUPER + DOWN", "Minimize window", D .. "window-minimize")
o.bind("SUPER + LEFT", "Dock window left", D .. "window-dock left")
o.bind("SUPER + RIGHT", "Dock window right", D .. "window-dock right")
o.bind("SUPER + SHIFT + UP", "Restore all minimized windows", D .. "window-restore-all")
o.bind("SUPER + SHIFT + DOWN", "Minimize all windows", D .. "window-minimize-all")
-- SUPER+ALT+S was Omarchy's "move to scratchpad", which is where minimized
-- windows live; do it as a real minimize so the taskbar and Super+Up track it.
hl.unbind("SUPER + ALT + S")
o.bind("SUPER + ALT + S", "Minimize window", D .. "window-minimize-now")

-- CTRL+ALT+DELETE opens text console 3 (same as Ctrl+Alt+F3), where `rescue`
-- helps when the desktop misbehaves. It was Omarchy's "Close all windows".
-- Needs /etc/sudoers.d/50-chvt (passwordless `sudo chvt`).
hl.unbind("CTRL + ALT + DELETE")
o.bind("CTRL + ALT + DELETE", "Text console (like Ctrl+Alt+F3)", "sudo -n /usr/bin/chvt 3")

-- SUPER+CTRL+L: lock with the "Locked" card first (~/.config/omarchy/lock), so
-- a remote RustDesk viewer sees that rather than the desktop.
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Lock system", D .. "lock")

-- PRINT: Omarchy's screenshot as before (picker, ~/Pictures, clipboard), then
-- a card with Edit / Ask your agents instead of the notification
-- (~/.config/omarchy/screenshot, taskbar's ScreenshotCard.qml).
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot (then edit, or ask an agent about it)", D .. "screenshot")

-- Super+Alt+A: ask an agent about the selected text (just highlight it; no
-- need to copy). Opens the taskbar's ask card (bar/modules/AskCard.qml).
-- (Super+Shift+A stays Omarchy's ChatGPT.)
o.bind("SUPER + ALT + A", "Ask an agent about the selected text", "omarchy-shell -q taskbar askSelection")

-- SUPER+SHIFT+ESCAPE twice within 2s reboots into Windows once (firmware
-- BootNext); a single press only shows a warning. Also in the system menu.
o.bind("SUPER + SHIFT + ESCAPE", "Reboot into Windows (press twice)", D .. "reboot-to-windows --tap")

-- SUPER+TAB: Windows-style window switcher from the taskbar (live thumbnails,
-- most recent first; see bar/modules/TaskbarSwitcher.qml). Hold Super and tap
-- Tab to step through, release Super to switch; Esc cancels. SUPER+TAB and
-- SUPER+SHIFT+TAB were next/previous workspace (SUPER+CTRL+TAB, former
-- workspace, still works). Omarchy's ALT+TAB tile cycling is untouched.
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + TAB", "Window switcher", "omarchy-shell -q taskbar switcherNext")
o.bind("SUPER + SHIFT + TAB", "Window switcher (backwards)", "omarchy-shell -q taskbar switcherPrev")

-- SUPER+C stays Universal copy on a single tap. A second tap within 400ms opens
-- your first coding agent (~/.config/omarchy/agents) instead of copying again.
-- The copy mirrors Omarchy's default/hypr/bindings/clipboard.lua.
hl.unbind("SUPER + C")
do
  local claude_tap_pending = false

  local function universal_copy()
    local mods, key = "CTRL", "C"
    local window = hl.get_active_window()
    for _, tag in ipairs((window and window.tags) or {}) do
      if tag:gsub("%*$", "") == "terminal" then
        key = "Insert"
      end
    end
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end

  o.bind("SUPER + C", "Universal copy (double-tap: your first agent)", function()
    if claude_tap_pending then
      claude_tap_pending = false
      hl.exec_cmd(D .. "agents launch-primary 1")
      return
    end
    claude_tap_pending = true
    universal_copy()
    hl.timer(function()
      claude_tap_pending = false
    end, { timeout = 400, type = "oneshot" })
  end)
end

-- SUPER+V stays Universal paste on a single tap. A second tap within 400ms opens
-- your second coding agent instead of pasting again. The paste mirrors Omarchy's
-- default/hypr/bindings/clipboard.lua.
hl.unbind("SUPER + V")
do
  local codex_tap_pending = false

  local function universal_paste()
    local mods, key = "CTRL", "V"
    local window = hl.get_active_window()
    for _, tag in ipairs((window and window.tags) or {}) do
      if tag:gsub("%*$", "") == "terminal" then
        mods, key = "SHIFT", "Insert"
      end
    end
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end

  o.bind("SUPER + V", "Universal paste (double-tap: your second agent)", function()
    if codex_tap_pending then
      codex_tap_pending = false
      hl.exec_cmd(D .. "agents launch-primary 2")
      return
    end
    codex_tap_pending = true
    universal_paste()
    hl.timer(function()
      codex_tap_pending = false
    end, { timeout = 400, type = "oneshot" })
  end)
end

-- SUPER+G stays Toggle window grouping on a single tap, but the toggle waits
-- until the 400ms double-tap window has passed. A second tap opens Ghostty in
-- the focused terminal's directory instead. Unlike copy, grouping can't run on
-- the first tap: group:auto_group would pull the new terminal into the group.
hl.unbind("SUPER + G")
do
  local pending_tap = nil

  o.bind("SUPER + G", "Toggle window grouping (double-tap: Ghostty)", function()
    if pending_tap then
      pending_tap = nil
      hl.exec_cmd(o.launch('ghostty --gtk-single-instance=true --working-directory="$(omarchy-cmd-terminal-cwd)"'))
      return
    end

    -- A fresh token per first tap, so a timer left over from an earlier
    -- double-tap can't toggle grouping for this one.
    local tap = {}
    pending_tap = tap
    hl.timer(function()
      if pending_tap == tap then
        pending_tap = nil
        hl.dispatch(hl.dsp.group.toggle())
      end
    end, { timeout = 400, type = "oneshot" })
  end)
end

-- Double-tap SUPER (or Caps Lock, which is Super here via caps:super) for the
-- super menu: pinned and frequent apps in a grid, type to search (taskbar's
-- bar/modules/SuperMenu.qml). Two taps of Super on its own within 350ms.
do
  local last_tap = nil

  o.bind("SUPER + SUPER_L", "Super menu (double-tap Super or Caps Lock)", function()
    local tap = {}
    if last_tap then
      last_tap = nil
      hl.exec_cmd("omarchy-shell -q taskbar superMenu")
      return
    end
    last_tap = tap
    hl.timer(function()
      if last_tap == tap then
        last_tap = nil
      end
    end, { timeout = 350, type = "oneshot" })
  end, { release = true })
end

-- SUPER+RETURN opens a terminal as in Omarchy, after a 300ms pause: a second
-- tap within it opens another window of the focused app instead (the same as
-- the taskbar's middle-click / "New window": a web app's page, an app's own
-- launcher entry, or the window's command line). The terminal waits so a
-- double-tap doesn't also leave a terminal behind.
hl.unbind("SUPER + RETURN")
do
  local pending_tap = nil

  o.bind("SUPER + RETURN", "Terminal (double-tap: another window of this app)", function()
    if pending_tap then
      pending_tap = nil
      local window = hl.get_active_window()
      if window then
        local address = tostring(window.address)
        if address:sub(1, 2) ~= "0x" then
          address = "0x" .. address
        end
        hl.exec_cmd(D .. "taskbar-action new " .. address)
      else
        hl.exec_cmd("omarchy-launch-terminal")
      end
      return
    end

    local tap = {}
    pending_tap = tap
    hl.timer(function()
      if pending_tap == tap then
        pending_tap = nil
        hl.exec_cmd("omarchy-launch-terminal")
      end
    end, { timeout = 300, type = "oneshot" })
  end)
end

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
