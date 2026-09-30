D=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/b; cd $D
cat > mpv-c.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><circle cx="13.2" cy="13.2" r="5"/><path d="M12 10.9l3.5 2.3-3.5 2.3z"/>
E
cat > obs-c.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><circle cx="12" cy="7.6" r="2.4"/><circle cx="15.81" cy="14.2" r="2.4"/><circle cx="8.19" cy="14.2" r="2.4"/><path d="M14.4 7.6a6.4 6.4 0 0 1 1.4 4.2M13.4 16.6a6.4 6.4 0 0 1-4.3.6M5.9 13.4a6.4 6.4 0 0 1 2.3-4.2"/>
E
cat > kdenlive-b.svgbody <<'E'
<path d="M10.5 6.5v13"/><path d="M8.6 4h3.8l-1.9 2.6z" fill="%C"/><path d="M4.5 9.5h3M3.5 13h4M4.5 16.5h3"/><path d="M13.8 8.2l6.2 4-6.2 4z"/>
E
cat > omacut-c.svgbody <<'E'
<rect x="6.7" y="4.5" width="2.6" height="15" rx="1.3"/><rect x="14.7" y="4.5" width="2.6" height="15" rx="1.3"/><path d="M6.7 8.5H4.5A1.5 1.5 0 0 0 3 10v4a1.5 1.5 0 0 0 1.5 1.5h2.2M9.3 8.5h5.4M9.3 15.5h5.4M17.3 8.5h2.2A1.5 1.5 0 0 1 21 10v4a1.5 1.5 0 0 1-1.5 1.5h-2.2"/>
E
cat > pinta-c.svgbody <<'E'
<path d="M20.5 3.5L13.85 10.15"/><path d="M13.28 12.98L11.02 10.72 12.72 9.02 14.98 11.28z"/><path d="M11.02 10.72C8 10.5 6.8 12.5 6.5 14.5 6.2 16.5 5.5 18.5 3.8 20.2 7.5 20 12 18.5 13.28 12.98"/>
E
cat > xournal-b.svgbody <<'E'
<path d="M14 20H5.5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2H14"/><path d="M6.5 9.5c1.4-.6 2.2.2 2.6 2.2s1.2 3 2.6 2.3M11.6 9.3c-2 1.2-3.3 2.9-4.9 4.7"/><path d="M20.8 5.2l-5.2 8.6-1.9 1.2.1-2.2 5.2-8.6a1 1 0 0 1 1.8 1z"/>
E
P=~/.claude/skills/taskbar-icons/scripts/icon-preview
$P p3.png mpv-c.svgbody obs.svgbody obs-c.svgbody kdenlive-b.svgbody omacut-c.svgbody pinta-b.svgbody pinta-c.svgbody xournal-b.svgbody
