# Splitting omarchy-desktop into Omarchy plugins

Goal: every element installs, updates and is configured on its own (`omarchy
plugin add <repo>`), like the Line Icons plugin; omarchy-desktop becomes the
bundle that adds them all. Nothing should need the taskbar to be installed.

## The plugins

| id | Holds | Settings |
|---|---|---|
| desktop-core | the shared window model (windows, what runs in terminals, recently used, attention, agents list, agent/terminal kinds), its state files, shared UI controls, media visuals (equalizers, AudioLevels, Visuals, shaders) | — |
| taskbar | the bar widget: icons, previews, gather, pins, apps that come to you, drag to workspaces | Setup > Taskbar |
| super-menu | launcher, groups, folders, search, double-tap Super | Setup > Super Menu |
| windows | Super+arrows ladder, minimize/restore, Super+Tab switcher, title bars + drag (Hyprland plugins), double-tap close, snap preview | Setup > Windows |
| hot-corners | corners and their effects | Setup > Hot Corners |
| now-playing | the card, visualizers, output picker | Setup > Now Playing |
| screenshots | capture, editor, fly-out; "ask an agent" when the agent tools are there | Setup > Screenshots |
| agent-tools | agent launchers, notifications, Files right-click, ask panel, safe mode | Setup > Agents |
| rescue | Ctrl+Alt+Del task manager, Ctrl+Alt+Esc rescue console, lock guard, backup lock, reboot to Windows | — |
| remote-access | RustDesk unattended setup | — |
| line-icons | done (raccoondata/omarchy-line-icons) | Setup > Line Icons |

Config history moves to omarchy-config (personal). Setup > Desktop: a hub
listing the installed elements' settings.

## Rules

- A plugin works alone. Another plugin is used only if installed: Line
  Icons (else app icons), agent-tools (else no ask), desktop-core is the one
  hard requirement (each plugin's setup adds it if missing).
- Omarchy gives third-party plugins no access to each other's services, so
  desktop-core's service publishes shared state as files in
  `$XDG_RUNTIME_DIR/desktop-core/` (programs.json, mru.json,
  attention.json, agents.json) and the others watch them; expensive work
  (window-programs) runs once. Shared code is imported by path
  (`../desktop-core/lib/...`), like Line Icons' libraries.
- Plugins talk through Omarchy's summon/IPC (`omarchy-shell shell summon
  <id>`, `qs ipc call <target>`), never by reaching into another's objects.
- Each plugin: `bin/setup` (idempotent, run by its service at start) and
  `bin/teardown` (undoes everything outside the plugin folder), its own
  settings file `~/.config/omarchy/<id>/settings.json`, its own Setup entry
  in Omarchy's menu, `bin/check`, README, MIT. No personal details; commit as
  `<repo name> <334392459+raccoondata@users.noreply.github.com>`.
- Migration: setup imports the old keys from `taskbar-settings.json` once.
- Every phase leaves the desktop working; omarchy-desktop's installer adds
  each plugin as it's split out.

## Naming

Omarchy's convention for third-party plugins: a repo `omarchy-<plugin>` and
an id `<owner>.<plugin>` (its docs: `acme/omarchy-weather`, `acme.weather`);
plain display names ("Taskbar"). The repos move to a personal GitHub account
(pending: the account, and whether the id namespace is its name or a neutral
word). Until then the working ids are plain (`desktop-core`, `line-icons`).

## Testing each plugin alone

- Static: `desktop-core/bin/plugin-audit <plugin>` lists what a plugin
  reaches outside its folder (imports of other plugins, `~/.config/omarchy`
  files, other plugins' IPC, programs) and fails on anything its manifest
  doesn't declare (`requires`, `uses`, `files`, `commands`). Part of every
  plugin's `bin/check`.
- Live (needs `cage`): a throwaway Hyprland inside a headless cage, with a
  fresh HOME, its own XDG_RUNTIME_DIR and D-Bus, Omarchy's shell and only the
  plugins under test; read its log, drive it over IPC, screenshot it.

## Phases

1. desktop-core, with the taskbar using it (no visible change). Done
   locally (plugin repo not published yet): the service publishes programs,
   mru, attention, agents and runs cava; the modules import its lib/, ui/,
   media/ and model/; the installer adds it (need_plugin).
2. now-playing, hot-corners (done locally; Desktop Core's hypr-include adds
   a plugin's Hyprland file to hyprland.lua), agent-tools, screenshots.
3. super-menu (done locally): its own key file, Host.qml as its link to the
   rest; Desktop Core counts app use. First release: line-icons and
   super-menu, after a visual pass.
4. windows, then taskbar (and the settings window splits per plugin).
5. rescue, remote-access, the bundle installer, config history to
   omarchy-config.
