I=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/a; for n in writer calc impress draw math base libreoffice obsidian pdf omawrite; do ~/.claude/skills/taskbar-icons/scripts/icon-set "$n" "$I/$n.svgbody" >/dev/null || echo "FAILED $n"; done; ~/.claude/skills/taskbar-icons/scripts/icon-set --list | wc -w
cd ~/.config/omarchy/bar/modules && python3 - <<'PYEOF'
p='taskbar.qml'
s=open(p).read()
old='''    [/(libreoffice|soffice)/i, "document"],
    [/(obsidian|typora|org\\.gnome\\.(evince|papers))/i, "document"],'''
new='''    [/^omawrite$/i, "omawrite"],
    [/libreoffice-writer/i, "writer"],
    [/libreoffice-calc/i, "calc"],
    [/libreoffice-impress/i, "impress"],
    [/libreoffice-draw/i, "draw"],
    [/libreoffice-math/i, "math"],
    [/libreoffice-base/i, "base"],
    [/(libreoffice|soffice)/i, "libreoffice"],
    [/obsidian/i, "obsidian"],
    [/^(org\\.gnome\\.(evince|papers)|evince|papers)$/i, "pdf"],
    [/typora/i, "document"],'''
assert old in s; s=s.replace(old,new,1)
open(p,'w').write(s)
PYEOF
omarchy-restart-shell >/dev/null 2>&1; sleep 4; omarchy-shell taskbar isDragging; qs log --id $(ls -t /run/user/1000/quickshell/by-id/ | head -1) 2>/dev/null | grep -iE 'taskbar|modules/' | tail -3
