cd ~/.claude/skills/taskbar-icons && python3 - <<'PYEOF'
p='SKILL.md'
s=open(p).read()
old='''   files; one row each). Iterate until it reads clearly at the small size.'''
new='''   files; one row each). Iterate until it reads clearly at the small size.
   Name every file after the icon, in one scratch folder: drafts
   `<name>-b.svgbody`, `<name>-c.svgbody`; if you compute the drawing (arcs,
   rays), save the script as `<name>.py` and run it from the file rather than
   inline. icon-set keeps all of them (step 3), so the work isn't lost with
   the scratchpad.'''
assert old in s; s=s.replace(old,new,1)
open(p,'w').write(s)
PYEOF
cat > ~/Projects/personal/omarchy-desktop/icon-src/README.md <<'EOF'
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
EOF
cd ~/Projects/personal/omarchy-desktop/icon-src && ./recover-from-transcripts >/dev/null && ~/.claude/skills/taskbar-icons/scripts/icon-preview /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/claude-hist.png recovered/by-icon/mpv/*.svgbody 2>&1 | tail -1
