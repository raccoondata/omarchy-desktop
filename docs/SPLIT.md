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
| screenshots | Print Screen into the editor or a preview with the ask panel (requires agent-tools) | Setup > Screenshots |
| agent-tools | the agents base: the agent list, starting and pasting into sessions, the ask panel and card, notifications; plus small entry points into the ask card (Files right-click, Super+Alt+A, Super+C/V twice, safe mode), each with an on/off switch | Setup > Agent Tools |
| rescue | done locally: Ctrl+Alt+Del task manager, Ctrl+Alt+Esc rescue console, lock guard, backup lock, reboot to Windows; its system parts are its bin/setup-system | — |
| remote-access | RustDesk unattended setup | — |
| line-icons | done (raccoondata/omarchy-line-icons) | Setup > Line Icons |

Config history moves to omarchy-config (personal). Setup > Desktop: a hub
listing the installed elements' settings.

## Rules

- A plugin works alone, apart from what it requires. desktop-core is
  required by all. Other plugins are used only if installed (Line Icons,
  else app icons), through `bridges/` files loaded by a Loader.
- Agent features: agent-tools is the base. A small entry point into its ask
  card (a menu item, a key) lives inside agent-tools with its own on/off
  switch. Anything with its own substantial UI, or that takes over
  something Omarchy already does, is a separate plugin that requires
  agent-tools (screenshots: without an agent it would only repeat
  Omarchy's own Print Screen).
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
2. now-playing, hot-corners, agent-tools, screenshots (done locally).
   Desktop Core's hypr-include adds a plugin's Hyprland file to
   hyprland.lua. Agent Tools took over the Files extension and the safe-mode
   unit at the same paths, so install.sh's "dropped files" step skips them.
   Screenshots requires Agent Tools and uses its ask panel directly.
3. super-menu (done locally): its own key file, Host.qml as its link to the
   rest; Desktop Core counts app use. First release: line-icons and
   super-menu, after a visual pass.
4. windows (done locally): keys, switcher, middle-drag, snapping and its
   preview, title bars and the Hyprland plugins (build, load, post-update
   rebuild) are its; the taskbar keeps drops on workspace numbers and tells
   it when the pointer is over one (IPC windows overTaskbar), and minimizes
   and restores through Desktop Core's window. Then taskbar (and the
   settings window splits per plugin). Taskbar done locally: the bar
   widget, its settings, Shift+click and pins; the desktop keeps only input
   tweaks and autostart.
5. rescue (done locally: keys, lock, backup lock and its guard, rescue
   console, reboot to Windows; the desktop's setup-system calls its
   setup-system), remote-access, the bundle installer, config history to
   omarchy-config.
