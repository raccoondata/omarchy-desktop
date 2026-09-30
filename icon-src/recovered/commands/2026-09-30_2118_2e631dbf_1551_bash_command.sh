cd ~/Projects/personal/omarchy-desktop && printf '.local/share/fonts/omarchy-desktop-icons.otf\n.config/omarchy/icon-codepoints.json\n.config/omarchy/menu-icons\n.config/omarchy/menu-icons.json\n' >> manifest && python3 - <<'PYEOF'
import os,re
def edit(p, pairs):
    p=os.path.expanduser(p); s=open(p).read()
    for old,new in pairs:
        assert old in s, (p, old[:60]); s=s.replace(old,new,1)
    open(p,'w').write(s)
edit('~/Projects/personal/omarchy-desktop/install.sh',[
('''gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true''','''gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true   # the icon font
# Omarchy's menu with our icons (Taskbar & Desktop > Icons): refresh it, as
# the icons or their codepoints may have changed.
[[ "$("$omarchy/menu-icons" status 2>/dev/null)" == on ]] && "$omarchy/menu-icons" on >/dev/null''')])
edit('~/Projects/personal/omarchy-desktop/uninstall.sh',[
('''echo "- hooks into Omarchy"''','''echo "- hooks into Omarchy"
"$omarchy/menu-icons" off >/dev/null 2>&1 || true''')])
edit('~/Projects/personal/omarchy-desktop/bin/omarchy-desktop',[
('''      || { echo "icons: run ~/.claude/skills/taskbar-icons/scripts/icon-build (or fix what icon-lint reports)"; exit 1; }''','''      || { echo "icons: run ~/.claude/skills/taskbar-icons/scripts/icon-build (or fix what icon-lint reports)"; exit 1; }
    "$HOME/.claude/skills/taskbar-icons/scripts/icon-font" --check >/dev/null \\
      || { echo "icon font: run ~/.claude/skills/taskbar-icons/scripts/icon-font"; exit 1; }''')])
edit('~/.claude/skills/taskbar-icons/scripts/icon-build',[
('''    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(text)
    tmp.replace(target)
    print(f"built {len(bodies)} icons from {src} into {target}. Then: omarchy restart shell")''','''    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(text)
    tmp.replace(target)
    print(f"built {len(bodies)} icons from {src} into {target}. Then: omarchy restart shell")
    if not user:
        # The icon font (Omarchy's menu) follows the built-in set.
        import subprocess
        from iconkit import KIT
        res = subprocess.run([str(KIT / "icon-font")], capture_output=True, text=True)
        print(res.stdout.strip() or f"icon font NOT rebuilt: {res.stderr.strip()[-300:]}")''')])
edit('~/.claude/skills/taskbar-icons/scripts/icon-set',[
('''    the desktop repo's icon-src/, built into the built-in set that ships to
    everyone; map it in taskbar.qml by hand (programIcons / classIcons)''','''    the desktop repo's icon-src/, built into the built-in set (and the icon
    font) that ships to everyone; map it by hand in bar/modules/
    TaskbarMatch.js (programIcons / classIcons)'''),
('''        sys.exit("maintainer: map built-in icons in taskbar.qml (programIcons / classIcons), not with flags")''','''        sys.exit("maintainer: map built-in icons in TaskbarMatch.js (programIcons / classIcons), not with flags")'''),
('''    print("Then: omarchy restart shell" + ("" if user else " (and map it in taskbar.qml if it's new)"))''','''    print("Then: omarchy restart shell" + ("" if user else " (and map it in TaskbarMatch.js if it's new)"))''')])
edit('~/.claude/skills/taskbar-icons/SKILL.md',[
('''# Taskbar icons

The taskbar (`~/.config/omarchy/bar/modules/taskbar.qml`) draws every window
with one line icon, recoloured at runtime: theme foreground when inactive,
accent when focused, faded when minimized. So each app needs exactly **one**
drawing, covering both themes and every state.''','''# Taskbar icons

The desktop draws apps with one line icon each, recoloured at runtime (theme
foreground, accent when focused, faded when minimized): the taskbar, window
previews and Super+Tab, and, if chosen in Taskbar & Desktop > Icons, the
Super menu, now playing and Omarchy's menu (through an icon font built from
the same icons). So each app needs exactly **one** drawing. Which window,
program or launcher gets which icon: `bar/modules/TaskbarMatch.js`.'''),
('''`icon-new`, `icon-preview`, `icon-lint`, `icon-set`, `icon-build`,
`icon-test`.''','''`icon-new`, `icon-preview`, `icon-lint`, `icon-set`, `icon-build`,
`icon-test`, `icon-font` (maintainer: the font; `icon-build` runs it).'''),
('''     omarchy-desktop repo, which ships to everyone. Then map it by hand in
     `taskbar.qml`: `programIcons`''','''     omarchy-desktop repo, which ships to everyone. Then map it by hand in
     `bar/modules/TaskbarMatch.js`: `programIcons`'''),
('''- The bar doesn't hot-reload icons or `taskbar.qml`: `omarchy restart shell`
  after installing.''','''- The bar doesn't hot-reload icons, `TaskbarMatch.js` or `taskbar.qml`:
  `omarchy restart shell` after installing. A new built-in icon in Omarchy's
  menu also needs an entry in `~/.config/omarchy/menu-icons.json`, then
  `~/.config/omarchy/menu-icons on`.''')])
edit('~/.claude/skills/taskbar-icons/ICON-SPEC.md',[
('''| `icon-test <out.png> <class>...` | throwaway windows, screenshot of the real bar |''','''| `icon-test <out.png> <class>...` | throwaway windows, screenshot of the real bar |
| `icon-font [--check]` | maintainer: the built-in set as a font, for Omarchy's menu (`icon-build` runs it) |''')])
PYEOF
bash -n install.sh uninstall.sh bin/omarchy-desktop && python3 -m py_compile ~/.claude/skills/taskbar-icons/scripts/icon-build ~/.claude/skills/taskbar-icons/scripts/icon-set && echo ok; rm -rf ~/.claude/skills/taskbar-icons/scripts/__pycache__
