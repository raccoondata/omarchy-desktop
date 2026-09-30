D=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/b; cd $D
cat > omacut-d.svgbody <<'E'
<rect x="3" y="8" width="18" height="8" rx="1.5"/><path d="M10 4.5H8v15h2M14 4.5h2v15h-2"/>
E
cat > omacut-e.svgbody <<'E'
<path d="M8 8H4.5A1.5 1.5 0 0 0 3 9.5v5A1.5 1.5 0 0 0 4.5 16H8M16 8h3.5A1.5 1.5 0 0 1 21 9.5v5a1.5 1.5 0 0 1-1.5 1.5H16"/><path d="M10.5 4.5H8v15h2.5M13.5 4.5H16v15h-2.5"/>
E
cat > mpv-d.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><circle cx="12.9" cy="12.9" r="5.2"/><path d="M11.6 10.6l3.7 2.3-3.7 2.3z"/>
E
P=~/.claude/skills/taskbar-icons/scripts/icon-preview
$P p4.png omacut.svgbody omacut-d.svgbody omacut-e.svgbody mpv-b.svgbody mpv-d.svgbody
