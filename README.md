# omarchy-desktop

A Windows-feeling desktop for [Omarchy](https://omarchy.org) (Arch + Hyprland):
a taskbar with window previews, a Super menu, Windows-style window handling,
screenshots you can hand to a coding agent, and a now-playing widget. It adds
to Omarchy rather than replacing it, follows your Omarchy theme, and leaves
your own monitors, keybindings, theme and apps alone.

## Install

On an up-to-date Omarchy, logged in: accept the invite to this repo if you
can (GitHub's email; the setup accepts it for you otherwise), open a terminal
(Super+Return), paste this and press Enter:

    curl -fsSL https://gist.githubusercontent.com/raccoondata/c170eba976a5fddeb8fe11cd36ab462a/raw/omarchy-desktop-setup.sh | bash

It walks you through it: installs GitHub's command-line tool, signs you in to
GitHub in the browser (it copies a code: paste it with Ctrl+V, then
Authorize), downloads this repo to `~/.local/share/omarchy-desktop/src` and
runs `install.sh`. That asks for your password (for the system parts), which
keybindings you want (it lists them: all, only the new ones, or none) and
whether you want remote access (off unless you say yes), then tells you to
log out and back in. What it printed is kept in
`~/.local/state/omarchy-desktop/install.log`.

The setup script is `bootstrap.sh` here (published as that gist by
`omarchy-desktop release`). By hand instead:

    yay -S github-cli
    gh auth login --web --clipboard --git-protocol https
    gh repo clone raccoondata/omarchy-desktop ~/.local/share/omarchy-desktop/src
    ~/.local/share/omarchy-desktop/src/install.sh

## Update

    omarchy-desktop update

or **Super+Alt+Space > Update > Desktop**. It shows what's new, then installs
it. `omarchy-desktop status` says whether there's an update.

Other commands: `omarchy-desktop keys all|new|off` (change the keybindings),
`remote on|off` (remote access), `check` (is everything working?), and
`uninstall` (takes it all out again, putting Omarchy's bar, keys and menus
back; your settings files stay).

## What you get

- **Taskbar** (on Omarchy's bar): pinned and open apps with live window
  previews, drag to reorder, drop on a workspace number to move a window
  there, right-click for options. Click to switch, double-click to gather an
  app's windows onto a workspace, laid out evenly. Files (and any app you
  choose) comes to you instead.
- **Super menu** (double-tap Super, or Caps Lock): apps and folders (pinned,
  and in named groups you make: blocks you place anywhere on the grid and
  size in tiles, 2×2, 3×2, ...; each pinned folder can set what its click,
  Shift+click and Ctrl+click do), search (with your zoxide folders, marked
  by project type and git branch: Enter starts your coding agent in a repo
  or a folder of repos, Files elsewhere; every key configurable), now
  playing, a box to ask a coding agent, and lock / restart / shut down.
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
  controls, a volume mixer, the audio outputs by name (Speakers, Headphones,
  your monitor, a Bluetooth device: click to switch); scroll for volume.
  Glitch-styled visualizers (pixel equalizers like Static, Corrupt, Radar;
  card scenes like Signal loss, Macroblocks, Pixel sort, and torn takes on
  Windows Media Player's) and album-art effects (Glitch, Datamosh, Tear,
  VHS...): click the visualizer for the next one, right-click the art for
  the next effect; Taskbar & Desktop > Media picks them per place. They
  follow the music (its spectrum, from cava), are drawn on the GPU, and only
  run while something plays; on battery or in power saver they rest
  (equalizers flat, cava stopped).
- **Safety nets**: a backup lock screen if Omarchy's ever fails, a rescue
  console (Ctrl+Alt+Esc) that can undo recent config changes, and a local
  history of your desktop config (`~/.config/omarchy/config-history log`).
- **Optional remote access** (`omarchy-desktop remote on`): RustDesk that
  works after a reboot and with the monitor off.
- **Restart into Windows**, on PCs that dual-boot Windows (hidden otherwise).

- **Taskbar icons** for Omarchy's own apps and tools (LibreOffice, Obsidian,
  btop, lazygit, the Wi-Fi / Bluetooth / audio tools, ...), coding agents and
  common web apps, drawn to match. An app without one gets a generic icon:
  ask Claude Code or Codex for "a taskbar icon for <app>" (the bundled
  `taskbar-icons` skill draws one in the same style). Yours are kept in
  `~/.config/omarchy/taskbar-icons.json`, which updates never touch.
  Taskbar & Desktop > Icons chooses, for each place (taskbar and switcher,
  Super menu, Omarchy's app launcher, now playing, Omarchy's menu): line
  icons in the theme's colours, in each app's colour, or in that colour
  matched to your theme, or the apps' original icons. Defaults: line on the
  taskbar, originals elsewhere.

Settings: **Super+Alt+Space > Setup > Taskbar & Desktop** (type to search
them). Health check: `omarchy-desktop check`.

## Keybindings

What differs from stock Omarchy (in `~/.config/hypr/desktop/bindings.lua`).
Which ones you get is up to you (`omarchy-desktop keys`): **all**, only the
**new** ones (marked ✚: they don't change any Omarchy key), or none.
**Super+K** lists every binding, these included. They load after your own
`~/.config/hypr/bindings.lua`, so to change one, put your version in a file
of your own (say `hypr/mine.lua`) and add `require("hypr.mine")` after
`require("hypr.desktop")` in `hyprland.lua`.

| Keys | Does | Replaces Omarchy's |
|---|---|---|
| Super+W / A / S / D | focus the window above / left / below / right | W: close window, S: scratchpad |
| Super+Q, twice ✚ | close the window (Omarchy's close was Super+W) | – |
| Super+Up | maximize, or restore a minimized window | focus up |
| Super+Down | un-maximize, then minimize | focus down |
| Super+Left / Right | dock the window to that half | focus left / right |
| Super+Shift+Up / Down | restore all / minimize all windows | swap window up / down |
| Super+Alt+S | minimize now | move to scratchpad |
| Super+Tab, Super+Shift+Tab | window switcher (previews) | next / previous workspace |
| Super, twice (or Caps Lock, twice) ✚ | the Super menu (type to search, Ctrl+Enter to ask an agent) | – |
| Super+Return (twice: another window of the focused app) | terminal | – |
| Super+C, twice ✚ | your first coding agent (once: universal copy, as before) | – |
| Super+V, twice ✚ | your second coding agent (once: universal paste, as before) | – |
| Super+G, twice | Ghostty (once: toggle grouping, as before) | – |
| Print Screen | screenshot, then the editor with the ask panel | Omarchy's screenshot |
| Super+Alt+A ✚ | ask an agent about the selected text | – |
| Super+Ctrl+L ✚ | lock (backup lock if needed) | lock |
| Ctrl+Alt+Delete | task manager (btop; focuses it if open) | close all windows |
| Ctrl+Alt+Esc ✚ | text console 3 with `rescue` (Ctrl+Alt+F1 back) | – |
| Super+Shift+Escape, twice ✚ | restart into Windows (only with Windows) | – |

With all of them, Caps Lock works as a second Super key (real Caps Lock: both
Shifts), and Compose moves to Right Alt (`hypr/desktop/input.lua`).

Mouse (always on, in `hypr/desktop/core.lua`): middle-drag a window's top strip to move it (onto a workspace number
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
- `bin/omarchy-desktop`: update / status / check / keys / remote / uninstall
  (`uninstall.sh`).

After a Hyprland update the plugins rebuild themselves on the next
`omarchy-desktop update` (or run `~/.config/omarchy/hyprland-plugins/build`);
until then the title bars fall back to off.
