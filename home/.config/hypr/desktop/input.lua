-- omarchy-desktop: input tweaks the desktop relies on (Caps Lock as Super for
-- the double-tap Super menu, window dragging).

hl.config({
  input = {
    -- Caps Lock is another Super. Compose (Omarchy puts it on Caps Lock) moves
    -- to Right Alt; real Caps Lock is still both Shifts together. The numpad
    -- always types digits, whatever the Num Lock state (numpad:mac).
    kb_options = "caps:super,compose:ralt,shift:both_capslock_cancel,numpad:mac",
  },
  binds = {
    -- A mouse-drag binding only picks the window up after this much movement.
    -- It doesn't hand clicks back to apps; bindings.lua does that for middle.
    drag_threshold = 10,
  },
  dwindle = {
    -- Let the drop point choose the split edge instead of always placing the
    -- moved window on the default side of the tile tree.
    precise_mouse_move = true,
  },
})
