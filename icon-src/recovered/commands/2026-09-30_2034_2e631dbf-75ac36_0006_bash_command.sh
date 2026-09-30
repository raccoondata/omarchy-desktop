D=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/b; cd $D
cat > mpv.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><circle cx="13" cy="13" r="4.6"/><path d="M12 11l3 2-3 2z" fill="%C" stroke="none"/>
E
cat > mpv-b.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><circle cx="12.6" cy="12.6" r="5.4"/><path d="M11.4 10.4l3.6 2.2-3.6 2.2z"/>
E
cat > imv.svgbody <<'E'
<path d="M3.5 8V5.5a2 2 0 0 1 2-2H8M16 3.5h2.5a2 2 0 0 1 2 2V8M20.5 16v2.5a2 2 0 0 1-2 2H16M8 20.5H5.5a2 2 0 0 1-2-2V16"/><path d="M7 16.5l3.5-4 2.5 2.5 1.5-1.5 2.5 3"/><circle cx="15" cy="8.8" r="1.4"/>
E
cat > obs.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><circle cx="12" cy="7.8" r="2.3"/><circle cx="15.64" cy="14.1" r="2.3"/><circle cx="8.36" cy="14.1" r="2.3"/>
E
cat > obs-b.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><path d="M9.8 7.2a2.6 2.6 0 1 0 4.4 0M17.25 12.93a2.6 2.6 0 1 0 -2.2 3.81M6.95 16.74a2.6 2.6 0 1 0 -2.2 -3.81" transform="rotate(0 12 12)"/>
E
cat > kdenlive.svgbody <<'E'
<path d="M10.5 5.5v14M8.8 3.8h3.4L10.5 6z"/><path d="M6 9h2.5M4 12h4.5M6 15h2.5"/><path d="M13.5 8l6 4-6 4z"/>
E
cat > omacut.svgbody <<'E'
<rect x="3" y="8" width="18" height="8" rx="1.5"/><path d="M8.5 4.5v15M15.5 4.5v15"/>
E
cat > omacut-b.svgbody <<'E'
<rect x="3" y="7.5" width="18" height="9" rx="1.5"/><path d="M8.5 4v16M15.5 4v16"/><circle cx="5.6" cy="10" r=".8" fill="%C" stroke="none"/><circle cx="5.6" cy="14" r=".8" fill="%C" stroke="none"/><circle cx="12" cy="10" r=".8" fill="%C" stroke="none"/><circle cx="12" cy="14" r=".8" fill="%C" stroke="none"/><circle cx="18.4" cy="10" r=".8" fill="%C" stroke="none"/><circle cx="18.4" cy="14" r=".8" fill="%C" stroke="none"/>
E
cat > pinta.svgbody <<'E'
<path d="M20.2 3.8L11.6 12.4"/><path d="M11.6 12.4l-1.6-1.6 1.6-1.6 3.2 3.2-1.6 1.6z" transform="translate(0 0)"/><path d="M10 13.2c-2.2-.4-4 1-4 3.2 0 1.2-.8 2.4-2.5 3.2 3 .6 6.8.4 7.8-2.4.6-1.6.2-3-1.3-4z"/>
E
cat > pinta-b.svgbody <<'E'
<path d="M20.5 3.5l-8.4 8.4"/><path d="M13.6 13.4l-3-3"/><path d="M10.4 13.1c-1.9-.3-3.9.8-3.9 3.1 0 1.4-.9 2.3-3 3.3 3.2.8 7.9.5 7.9-3.6"/>
E
cat > xournal.svgbody <<'E'
<path d="M13.5 20H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h8.5"/><path d="M7 9.5c1.4-.6 2.2.2 2.6 2.2s1.2 3 2.6 2.3M12.4 9.5c-2 1.2-3.3 2.8-4.9 4.5"/><path d="M20.5 5.5l-6 9.5-2 1.3.2-2.4 6-9.5a1 1 0 0 1 1.8 1.1z"/>
E
cat > moonlight.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><path d="M12 5.5v13M5.5 12h13M7.4 7.4l9.2 9.2M16.6 7.4l-9.2 9.2"/>
E
cat > moonlight-b.svgbody <<'E'
<circle cx="12" cy="12" r="8.8"/><circle cx="12" cy="12" r="6"/><path d="M12 6v12M6 12h12M7.76 7.76l8.48 8.48M16.24 7.76l-8.48 8.48"/>
E
cat > cliamp.svgbody <<'E'
<rect x="3" y="4.5" width="18" height="15" rx="3"/><path d="M7 11v2M9.5 9v6M12 7.5v9M14.5 9.5v5M17 11v2"/>
E
cat > cliamp-b.svgbody <<'E'
<path d="M4 10.5v3M8 7.5v9M12 4.5v15M16 8v8M20 10.5v3"/>
E
cat > zoom.svgbody <<'E'
<rect x="3" y="3" width="18" height="18" rx="5"/><rect x="6.5" y="9" width="7.5" height="6" rx="1.5"/><path d="M14 11.3l3.5-2v5.4l-3.5-2"/>
E
cat > zoom-b.svgbody <<'E'
<circle cx="12" cy="12" r="9"/><rect x="6.5" y="9" width="7.5" height="6" rx="1.5"/><path d="M14 11.3l3.5-2v5.4l-3.5-2"/>
E
P=~/.claude/skills/taskbar-icons/scripts/icon-preview
$P p1.png mpv.svgbody mpv-b.svgbody imv.svgbody obs.svgbody obs-b.svgbody kdenlive.svgbody omacut.svgbody omacut-b.svgbody
$P p2.png pinta.svgbody pinta-b.svgbody xournal.svgbody moonlight.svgbody moonlight-b.svgbody cliamp.svgbody cliamp-b.svgbody zoom.svgbody zoom-b.svgbody
