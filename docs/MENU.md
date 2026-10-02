# The Super Menu and asking an agent: one window

Direction "D" from the design round on the Super Menu and the spotlight:
C's spatial home and edit mode, A's agents list and one ranked search, B's
"from the taskbar" as an optional placement. This file is the build plan;
keep it current as phases finish.

## What changes, in one paragraph

Double-tap Super opens the menu: your groups on one grid, with an **Agents**
component (your open coding-agent sessions and how each is doing) placed on
the grid like Now playing. Typing is a real search: one ranked list (apps,
sessions, folders, settings, Omarchy's actions, maths, ask, web), and under
it the menu shrinks to a map with the matches lit. Tab, or Super+Alt+A from
anywhere, turns the same window into **ask mode**: the question, what to
attach (the selected text, this window, its folder, the clipboard) and a
"Send to" list (a new session, or an open one with its status). How groups
and tiles look moves out of right-click pages into **edit mode** (Ctrl+E):
an inspector beside the menu, Menu › Group › Tile, each value marked as
inherited or set here. Two new settings: **Layout** Grid | Rows, and
**Placement** Centred | On the taskbar.

## Who owns what

The plugins stay separately installable (docs/SPLIT.md's rules).

| Piece | Plugin | Notes |
|---|---|---|
| The window, grid, search, map, edit mode, inspector, layout, placement | super-menu | |
| Agents component (its face at every size), session status, sessions as search results, ask mode's parts (question, attachments, Send to), sending | agent-tools | super-menu loads them through `bridges/AgentTools.qml` (a Loader), only when Agent Tools is installed |
| Super+Alt+A, Files' Ask… | agent-tools | opens the Super Menu in ask mode when it's installed (setting), else its own spotlight |
| Marks on the bar while the menu sits on it (matches, agents) | taskbar | told over IPC; nothing breaks without it |

Without Agent Tools: no Agents component, no ask mode; search keeps its
"Ask" row through Omarchy's default agent. Without the Super Menu: Agent
Tools' spotlight, now with the Send to list in its body.

## Data

- **Session status** (agent-tools): `bin/agent-notify` records every
  finish / needs-you event, whether or not you're looking at the window, in
  `$XDG_RUNTIME_DIR/agent-tools/sessions.json`
  (`{"0x<address>": {"event": "needs"|"finished", "text": "<one line>",
  "agent": "claude", "at": <epoch seconds>}}`, pruned to open windows,
  written under a lock). `ui/AgentSessions.qml` turns that, Desktop Core's
  attention and the title spinner into a status per session:
  **needs you** (attention, last event "needs"), **done** (attention
  otherwise: finished while you were away, not yet looked at), **working**
  (the title's spinner), **idle**. Each with its detail (what it asked, what
  it said) and how long ago. No polling: file watches and window events.
- **The component** (super-menu `menu.json`): the tile id `control:agents`
  in a group like any control; its size in `spans` as `"WxH"` (tiles can
  now be more than one row tall); its options in `tileStyle["control:agents"]`
  (`layout`: auto | counts | cards | list | table; `statuses`; `agents`).
- **Layout by size** (auto): 1×1 counts; one row tall (2+ wide) cards on
  the tile columns; up to 3 wide and 2+ tall the stacked list; 4+ wide and
  2+ tall a table (with each session's folder).
- **New settings** (super-menu `settings.json`): `layout` grid | rows,
  `placement` centre | taskbar. Agent Tools: `askIn` menu | spotlight.

## Ask mode's attachments, cheaply

Nothing is captured when the menu opens. Entering ask mode runs Agent
Tools' `bin/context --no-shot` (the focused window's details, a terminal's
folder, the clipboard, the selection with `--selection`; no screenshot).
"This window" is shown live from the window's own buffer (Quickshell's
ScreencopyView, so the menu over it never ends up in the picture) and saved
to a file only if it's attached when you send.

## Phases

Each phase leaves the desktop working, goes live when it's done (sandbox
first, then a shell restart while the menu is closed), and is committed per
plugin.

1. **Search** (super-menu). One ranked list replaces the results grid and
   the rows under it: kind, icon, name with the match marked, where it
   lives ("in Work") or "+ add to menu". Under it, the menu as a map with
   the matches lit, following the selection. Keys as now (Enter, Shift,
   Ctrl+Enter ask, Ctrl+P pin).
2. **Agents component** (agent-tools + super-menu). Status recording and
   the session model; the component's four layouts; tiles taller than a row
   in the grid engine (place, move, swap, grow, push down); add it from a
   group's Add a control; sessions as search results; Enter continues a
   session, Tab asks it something.
3. **Ask mode** (super-menu + agent-tools). Tab (or no match) turns the
   window into ask mode, the line growing into the question; attachments;
   Send to with statuses (the Agents component's column becomes the list);
   effort; Esc back to the menu (or closed, if it opened in ask mode).
   Super+Alt+A and Files' Ask… open it there. The spotlight gets the same
   Send to list.
4. **Edit mode** (super-menu). Ctrl+E, the Edit button, right-click ›
   Edit…: grid cells shown, an inspector docked beside the menu with levels
   Menu (the defaults: what Settings › Appearance had, plus layout and
   placement), a group, a tile, a component, and + Add (components,
   controls). Every value says Menu / <group> / own ↺. Right-click keeps
   quick actions only (new window, move to, edit, remove).
5. **Rows layout** (super-menu). Groups as rows with their names in a
   gutter, on the same columns; the Agents list beside the rows (or cards /
   a table under them); the map in search is the rows themselves.
6. **On the taskbar** (super-menu + taskbar). The window hangs from the
   bar's edge (whichever edge it's on), offered only while the Taskbar
   plugin is there and the bar shows (Omarchy's bar state: position,
   hidden). The taskbar marks matches while you search and rings the agents
   while you ask (IPC from the menu).
7. **Live tile state**: a state line under tiles (needs you, 3 unread, 4
   windows, a folder's branch), a setting per menu / group / tile.

## Progress

All seven phases are built, in the plugins' working copies (not released):
search and the map, the Agents component and session status, ask mode
(and the spotlight rebuilt on the same body), edit mode with the
inspector (plus a corner grip to resize Now playing and Agents), the Rows
layout, "on the taskbar" placement with the taskbar's marks, state lines.
Measured: the menu adds nothing while closed and about 0.1% of a core
while open (sandbox, Agents tile showing).

Left: an "unfold" entrance from the bar; the Agents tile's Tab (ask that
session something) from the grid; screenshots plugin's bar on the shared
Send to list; Now playing in the Rows layout (four of its narrow cells
squeeze the title to a few letters).

## Checks for every phase

- One grid: every tile on the same columns across groups, components
  included (screenshot at compact, medium and wide).
- Cheap: nothing runs while the menu is closed; status by file watch;
  measure the shell's CPU idle and with the menu open, before and after.
- Each plugin alone: super-menu without agent-tools, agent-tools without
  super-menu (the sandbox), `bin/check` for each plugin touched.
- No personal details in any file.

## Review

After the build: Codex reviews the changes (read-only), three rounds at
most; findings fixed between rounds, a ledger of fixed / deliberate /
deferred kept with the work.

Done, three rounds (each plugin's "Review round N" commit lists the fixes):

| Round | super-menu | agent-tools | taskbar | Outcome |
|---|---|---|---|---|
| 1 | 6 | 7 | 3 | 14 fixed, 1 already fixed, 1 kept by design |
| 2 | 4 | 6 | 2 | all fixed |
| 3 | 4 | 5 | 0 | all fixed |

Round 3's: a resized tile keeps its place; Rows in the Cards look, with
hero tiles; narrow search rows; "size" in the inspector; Send to when the
chosen session closes; one fallback folder without `XDG_RUNTIME_DIR`;
More agents folds again; no error with no agents; ask mode on short,
narrow screens.
