# icon-src

How the taskbar icons (`home/.config/omarchy/bar/modules/taskbar-icons.js`)
were made. Nothing here is installed; it's for redrawing or tweaking one.

- `sources/<name>/<date>/`: the working files the `taskbar-icons` skill's
  `icon-set` keeps each time it adds an icon on the maintainer's PC: the
  final drawing, its drafts and any generator script.
- `recovered/`: the same, dug out of the Claude Code session transcripts for
  icons made before `icon-set` kept anything (`./recover-from-transcripts`
  rebuilds it):
  - `by-icon/<name>/`: every drawing of that icon, oldest first (drafts and
    alternates), links to the commands and generator scripts that made or
    installed it, and `final.svgbody`, the version in use.
  - `commands/`: those commands and scripts.
  - `INDEX.md`: all of it by date.

Preview any drawing with the skill:
`~/.claude/skills/taskbar-icons/scripts/icon-preview out.png <file>...`
