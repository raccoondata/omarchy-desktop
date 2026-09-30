-- omarchy-desktop: input tweaks. Window dragging always; Caps Lock as Super
-- (for double-tapping it to open the Super menu) only with all the
-- keybindings on (omarchy_desktop_keys, see bindings.lua).

hl.config({
  binds = {
    -- A mouse-drag binding only picks the window up after this much movement.
    -- It doesn't hand clicks back to apps; core.lua does that for middle.
    drag_threshold = 10,
  },
  dwindle = {
    -- Let the drop point choose the split edge instead of always placing the
    -- moved window on the default side of the tile tree.
    precise_mouse_move = true,
  },
})

if (omarchy_desktop_keys or "all") == "all" then
  hl.config({
    input = {
      -- Caps Lock is another Super. Compose (Omarchy puts it on Caps Lock)
      -- moves to Right Alt; real Caps Lock is still both Shifts together. The
      -- numpad always types digits, whatever the Num Lock state (numpad:mac).
      kb_options = "caps:super,compose:ralt,shift:both_capslock_cancel,numpad:mac",
    },
  })
end
