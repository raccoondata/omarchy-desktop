---
name: taskbar-icons
description: >
  Draw and wire up icons for the omarchy-desktop taskbar (its line-icon set,
  plus your own in ~/.config/omarchy/taskbar-icons.json). Use when a newly installed
  app, web app, or terminal program shows the generic icon, or when asked to
  add, redraw, or refine a taskbar icon. Triggers: "icon for <app>", "taskbar
  icon", "installed <app>", "make an icon", "web app logo", generic window icon.
---

# Taskbar icons

The taskbar (`~/.config/omarchy/bar/modules/taskbar.qml`) draws every window
with one line icon from `taskbar-icons.js`, recoloured at runtime: theme
foreground when inactive, theme accent when focused, and the whole entry at
35% when minimized. So each app needs exactly **one** drawing, which covers
dark and light themes and every state. Never add per-state or per-theme files.

## Style rules

- 24x24 viewBox. The wrapper sets `fill="none"`, `stroke-width="1.75"`, round
  caps and joins, so write only the inner elements (paths, circles, rects).
- Outline only. For a small solid dot use
  `<circle ... fill="%C" stroke="none"/>`; `%C` is replaced with the draw
  colour. Never hardcode a colour.
- Keep shapes inside roughly 3 to 21 on both axes, like the existing icons.
- A brand mark should be a simplified line version of the real logo, legible
  at the real taskbar size (about 23px: 55% of the 42px bar). Fewer, bolder strokes beat detail:
  earlier attempts failed by crowding (a 12-ray Claude burst clumped, a
  tapered version blobbed, a ChatGPT knot read as a camera aperture).
- Look at the real logo first when one is installed:
  `find /usr/share/icons /usr/share/pixmaps -iname '*<app>*'`, or the agent
  marks in `/usr/share/omarchy/shell/plugins/agents/assets/`.

## Workflow

Scripts live in `~/.claude/skills/taskbar-icons/scripts/`.

1. **Find what to match.**
   - Desktop app: open it and read `hyprctl clients -j | jq -r '.[].class'`,
     or check `StartupWMClass=` in its `.desktop` file. Don't guess: VS Code
     turned out to be `com.microsoft.VSCode`, not `code`.
   - Omarchy web app: the class is `chrome-<host>__<path>-Default` (from the
     URL in its `.desktop` Exec line), e.g. `chrome-youtube.com__-Default`.
   - Terminal program: the foreground process name (`comm`), as reported by
     `~/.config/omarchy/window-programs`.
   - First check the icon doesn't already exist: `scripts/icon-set --list`.

2. **Draw it.** Write the inner SVG to a file in the scratchpad, then preview
   it big and at real size in both inactive and accent colours:
   `scripts/icon-preview <out.png> <body-file>` and Read the PNG. When unsure,
   draw two or three options and preview them together (pass several body
   files; one row each). Iterate until it reads clearly at the small size.
   Name every file after the icon, in one scratch folder: drafts
   `<name>-b.svgbody`, `<name>-c.svgbody`; if you compute the drawing (arcs,
   rays), save the script as `<name>.py` and run it from the file rather than
   inline. icon-set keeps all of them (step 3), so the work isn't lost with
   the scratchpad.

3. **Add and map it.** Names are lowercase, one word, e.g. `steam`, `youtube`.
   Where it goes depends on the PC (icon-set decides):
   - **Usually: your own icon file**, `~/.config/omarchy/taskbar-icons.json`,
     which the desktop's updates never touch (`taskbar-icons.js` and
     `taskbar.qml` are replaced on every `omarchy-desktop update`, so never
     edit those there). Add and map in one go:
     `scripts/icon-set <name> <body-file> --program <prog>` for a terminal
     program, `--class '<regex>'` for a window class (both repeatable).
     These are checked before the built-in rules.
   - **The maintainer's PC** (`maintainer=on` in
     `~/.config/omarchy/desktop.conf`): `scripts/icon-set <name> <body-file>`
     adds it to the built-in set (`taskbar-icons.js`, which ships to everyone),
     then map it by hand in `taskbar.qml`: `programIcons` (`program: "icon"`)
     for terminal programs, `classIcons` (`[/regex/, "icon"]`, first match
     wins) for window classes. Specific rules above general ones: web app
     hosts above the generic `/^(chrome-|firefox|...)/` browser rule, exact
     classes as `^...$`. (`--user` forces the personal file here too.)

4. **Check** the class or program first (step 1) so the match is right: a
   wrong regex just leaves the generic icon.

5. **Reload and test.** `omarchy restart shell`, then check the shell log
   for taskbar errors, then `scripts/icon-test <out.png> <class> [<class>...]`. It opens
   a dummy window per class, screenshots the bar to `<out.png>`, and closes
   the windows. Read the screenshot and confirm each dummy shows the new icon.
   Ghostty only accepts dotted classes; the script uses foot for any other.

6. **Clean up** scratchpad files, and tell the user what the icon looks like
   and what it's matched on.

## Gotchas

- The bar does not hot-reload `taskbar.qml` or `taskbar-icons.js`: always
  `omarchy restart shell` after editing them. `shell.json` does hot-reload.
- Check for errors with:
  `qs log --id $(ls -t $XDG_RUNTIME_DIR/quickshell/by-id/ | head -1) | grep -iE 'taskbar|modules/'`
- Edit `taskbar-icons.js` and `taskbar-icons.json` only through `scripts/icon-set`. A hand-rolled regex
  replacement once corrupted the file and blanked every icon.
- `taskbar-icons.js` is JavaScript with `.pragma library`; entries are
  one-per-line JSON strings.
