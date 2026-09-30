# icon-src

The taskbar icons' sources. Nothing here is installed: `icon-build` (the
`taskbar-icons` skill, `home/.claude/skills/taskbar-icons/`) builds them
into `home/.config/omarchy/bar/modules/taskbar-icons.js`. The spec and the
script format: the skill's `ICON-SPEC.md`.

- `icons/<name>.icon.py`: one script per icon, the source of truth. Edit a
  script and run `icon-build`, or install a new one with `icon-set`.
- `drafts/<name>/<date>/`: the drafts `icon-set` keeps each time it
  installs an icon.
- `recovered/`: history dug out of the Claude Code session transcripts,
  from before the icons were scripts (`./recover-from-transcripts` rebuilds
  it): every drawing of each icon (`by-icon/<name>/`), the commands and
  generators that made them (`commands/`), `INDEX.md` by date. The
  generators there were ported into `icons/` (claude, codex, chrome, photos,
  localsend, rustdesk, chatgpt, obs).
