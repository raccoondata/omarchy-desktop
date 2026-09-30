cd ~/.claude/skills/taskbar-icons && python3 - <<'PYEOF'
p='SKILL.md'
s=open(p).read()
def rep(old,new):
    global s
    assert old in s, old[:60]
    s=s.replace(old,new,1)
rep("Draw and wire up icons for the maintainer's custom Omarchy taskbar (the line-icon set in\n  ~/.config/omarchy/bar/modules/taskbar-icons.js).","Draw and wire up icons for the omarchy-desktop taskbar (its line-icon set,\n  plus your own in ~/.config/omarchy/taskbar-icons.json).")
rep('''3. **Add it.** `scripts/icon-set <name> <body-file>` adds or replaces the
   entry and validates that the whole file still parses (it refuses to write
   a broken file). Names are lowercase, one word, e.g. `steam`, `youtube`.

4. **Map it** in `taskbar.qml`:
   - `programIcons`: `program: "icon"` for terminal programs.
   - `classIcons`: `[/regex/, "icon"]`, first match wins. Put specific rules
     above general ones: web app hosts go above the generic
     `/^(chrome-|firefox|...)/` browser rule, and exact classes use `^...$`.''','''3. **Add and map it.** Names are lowercase, one word, e.g. `steam`, `youtube`.
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
   wrong regex just leaves the generic icon.''')
rep("`qs log --id $(ls -t /run/user/1000/quickshell/by-id/ | head -1) | grep -iE 'taskbar|modules/'`","`qs log --id $(ls -t $XDG_RUNTIME_DIR/quickshell/by-id/ | head -1) | grep -iE 'taskbar|modules/'`")
rep("- Edit `taskbar-icons.js` only through `scripts/icon-set`.","- Edit `taskbar-icons.js` and `taskbar-icons.json` only through `scripts/icon-set`.")
open(p,'w').write(s)
PYEOF
grep -n "the maintainer\|1000" SKILL.md
