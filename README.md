# omarchy-desktop

A Windows-feeling desktop for [Omarchy](https://omarchy.org) (Arch + Hyprland):
a taskbar with window previews, a Super menu, Windows-style window handling,
screenshots you can hand to a coding agent, and a now-playing widget. It adds
to Omarchy rather than replacing it, follows your Omarchy theme, and leaves
your own monitors, keybindings, theme and apps alone.

## Install

On an up-to-date Omarchy, logged in. The repo is private, so sign in to
GitHub first:

    yay -S github-cli && gh auth login        # HTTPS, sign in with a browser
    gh repo clone raccoondata/omarchy-desktop ~/.local/share/omarchy-desktop/src
    ~/.local/share/omarchy-desktop/src/install.sh

It asks for your password (for the system parts) and whether you want remote
access (off unless you say yes), then tells you to log out and back in.

## Update

    omarchy-desktop update

or **Super+Alt+Space > Update > Desktop**. It shows what's new, then installs
it. `omarchy-desktop status` says whether there's an update.

## What you get

- **Taskbar** (on Omarchy's bar): pinned and open apps with live window
  previews, drag to reorder, drop on a workspace number to move a window
  there, right-click for options. Click to switch, double-click to gather an
  app's windows onto a workspace, laid out evenly. Files (and any app you
  choose) comes to you instead.
- **Super menu** (double-tap Super, or Caps Lock): apps, search, now playing,
  a box to ask a coding agent, and lock / restart / shut down.
- **Windows-style windows**: Super+Up / Down to maximize, restore and
  minimize, Super+Left / Right to dock to a half, title bars with minimize
  and maximize buttons, hot corners.
- **Screenshots**: Print Screen opens the editor (Tensaku) with an ask panel
  next to it: type a question and send the screenshot to Claude Code, Codex
  or whichever agents you have, in a new or an open session.
- **Coding agents**: finds the agents you have installed (Omarchy's list),
  asks about files from Files' right-click menu or about selected text
  (Super+Alt+A), and puts their "done" / "needs you" notices on the taskbar.
- **Now playing**: title and artist on the bar, a card with album art and
  controls, a volume mixer; scroll for volume.
- **Safety nets**: a backup lock screen if Omarchy's ever fails, a rescue
  console (Ctrl+Alt+Delete) that can undo recent config changes, and a local
  history of your desktop config (`~/.config/omarchy/config-history log`).
- **Optional remote access** (`omarchy-desktop remote on`): RustDesk that
  works after a reboot and with the monitor off.
- **Restart into Windows**, on PCs that dual-boot Windows (hidden otherwise).

Settings: **Super+Alt+Space > Setup > Taskbar & Desktop**. Health check:
`omarchy-desktop check`.

## Keybindings

What differs from stock Omarchy (in `~/.config/hypr/desktop/bindings.lua`).
**Super+K** lists every binding, these included. They load after your own
`~/.config/hypr/bindings.lua`, so to change one, put your version in a file
of your own (say `hypr/mine.lua`) and add `require("hypr.mine")` after
`require("hypr.desktop")` in `hyprland.lua`.

| Keys | Does | Replaces Omarchy's |
|---|---|---|
| Super+W / A / S / D | focus the window above / left / below / right | W: close window, S: scratchpad |
| Super+Q, twice | close the window (Omarchy's close was Super+W) | – |
| Super+Up | maximize, or restore a minimized window | focus up |
| Super+Down | un-maximize, then minimize | focus down |
| Super+Left / Right | dock the window to that half | focus left / right |
| Super+Shift+Up / Down | restore all / minimize all windows | swap window up / down |
| Super+Alt+S | minimize now | move to scratchpad |
| Super+Tab, Super+Shift+Tab | window switcher (previews) | next / previous workspace |
| Super, twice (or Caps Lock, twice) | the Super menu (type to search, Ctrl+Enter to ask an agent) | – |
| Super+Return (twice: another window of the focused app) | terminal | – |
| Super+C, twice | your first coding agent (once: universal copy, as before) | – |
| Super+V, twice | your second coding agent (once: universal paste, as before) | – |
| Super+G, twice | Ghostty (once: toggle grouping, as before) | – |
| Print Screen | screenshot, then the editor with the ask panel | Omarchy's screenshot |
| Super+Alt+A | ask an agent about the selected text | – |
| Super+Ctrl+L | lock (backup lock if needed) | lock |
| Ctrl+Alt+Delete | text console 3 with `rescue` (Ctrl+Alt+F1 back) | close all windows |
| Super+Shift+Escape, twice | restart into Windows (only with Windows) | – |

Caps Lock works as a second Super key (real Caps Lock: both Shifts), and
Compose moves to Right Alt (`hypr/desktop/input.lua`).

Mouse: middle-drag a window's top strip to move it (onto a workspace number
moves it there, to a screen edge snaps it); Shift+click a taskbar icon for a
new window. Esc in the screenshot editor folds its ask panel first.

## How it's put together

- `home/`: the desktop's own files, copied into your home folder (listed in
  `manifest`). Updates replace them, so don't edit them there; the ones an
  update replaces are kept in `~/.local/state/omarchy-desktop/backups/`.
- `templates/`: starting settings (taskbar pins, hot corners, ...), copied
  only where you have none, then yours.
- `install.sh`: copies those, hooks the desktop into Omarchy (one line in
  `hyprland.lua`, the bar widgets in `shell.json`, menu entries, agent
  notification hooks), runs `setup-system` (packages, rescue console), builds
  the two Hyprland plugins, starts the background services.
- `bin/omarchy-desktop`: update / status / check / remote.

After a Hyprland update the plugins rebuild themselves on the next
`omarchy-desktop update` (or run `~/.config/omarchy/hyprland-plugins/build`);
until then the title bars fall back to off.
