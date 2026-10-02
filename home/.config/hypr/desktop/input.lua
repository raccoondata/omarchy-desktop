-- omarchy-desktop: input tweaks: Caps Lock as Super (for double-tapping it to
-- open the Super menu), only with all the keybindings on
-- (omarchy_desktop_keys, from hypr/desktop.lua). Window dragging is the Windows
-- plugin's.

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
