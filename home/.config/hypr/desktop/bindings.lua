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


if ALL then
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
end

if NEW then
  -- SUPER+Q twice closes the window (Omarchy's close, Super+W, becomes focus
  -- up when all the keybindings are on).
  o.bind("SUPER + Q", "Close window (double-tap Q)", D .. "window-close-double-tap")
end

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

if ALL then
  -- PRINT: Omarchy's screenshot as before (picker, ~/Pictures, clipboard), then
  -- a card with Edit / Ask your agents instead of the notification
  -- (~/.config/omarchy/screenshot, taskbar's ScreenshotCard.qml).
  hl.unbind("PRINT")
  o.bind("PRINT", "Screenshot (then edit, or ask an agent about it)", D .. "screenshot")
end

if NEW then
  -- Super+Alt+A: ask an agent about the selected text (just highlight it; no
  -- need to copy). Opens the taskbar's ask card (bar/modules/AskCard.qml).
  -- (Super+Shift+A stays Omarchy's ChatGPT.)
  o.bind("SUPER + ALT + A", "Ask an agent about the selected text", "omarchy-shell -q taskbar askSelection")
end

if NEW then
  -- SUPER+SHIFT+ESCAPE twice within 2s reboots into Windows once (firmware
  -- BootNext); a single press only shows a warning. Also in the system menu.
  o.bind("SUPER + SHIFT + ESCAPE", "Reboot into Windows (press twice)", D .. "reboot-to-windows --tap")
end

if ALL then
  -- SUPER+TAB: Windows-style window switcher from the taskbar (live thumbnails,
  -- most recent first; see bar/modules/TaskbarSwitcher.qml). Hold Super and tap
  -- Tab to step through, release Super to switch; Esc cancels. SUPER+TAB and
  -- SUPER+SHIFT+TAB were next/previous workspace (SUPER+CTRL+TAB, former
  -- workspace, still works). Omarchy's ALT+TAB tile cycling is untouched.
  hl.unbind("SUPER + TAB")
  hl.unbind("SUPER + SHIFT + TAB")
  o.bind("SUPER + TAB", "Window switcher", "omarchy-shell -q taskbar switcherNext")
  o.bind("SUPER + SHIFT + TAB", "Window switcher (backwards)", "omarchy-shell -q taskbar switcherPrev")
end

if NEW then
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
end

if NEW then
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
end

if ALL then
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
end

-- The Super menu (double-tap Super) is the Super Menu plugin's: it adds its
-- own key (plugins/super-menu/hypr/super_menu.lua).

if ALL then
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
end
