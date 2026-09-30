cd /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/c/
cat > btop.svgbody <<'E'
<rect x="3" y="4.5" width="18" height="15" rx="3"/><path d="M7.5 16v-3M10.5 16V8.5M13.5 16v-5M16.5 16V10"/>
E
cat > btop2.svgbody <<'E'
<path d="M4.5 16.5a7.5 7.5 0 0 1 15 0"/><path d="M12 16.5l3.5-4.5"/><path d="M4 20h16"/><circle cx="12" cy="16.5" r="1.1" fill="%C" stroke="none"/>
E
cat > htop.svgbody <<'E'
<path d="M5 5.5H3.5v13H5M19 5.5h1.5v13H19"/><path d="M7 8.5h10M7 12h5M7 15.5h7.5"/>
E
cat > htop2.svgbody <<'E'
<path d="M4 7h16M4 12h9M4 17h12.5"/><circle cx="20" cy="12" r="0.95" fill="%C" stroke="none"/><circle cx="20" cy="17" r="0.95" fill="%C" stroke="none"/>
E
cat > disks.svgbody <<'E'
<rect x="3" y="6" width="18" height="12" rx="2.5"/><path d="M3 13.5h18"/><circle cx="17.2" cy="15.8" r="0.95" fill="%C" stroke="none"/>
E
cat > disks2.svgbody <<'E'
<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="2.2"/><path d="M14.5 17.5l3-6"/>
E
cat > printer.svgbody <<'E'
<path d="M7 8V3.5h10V8"/><path d="M7 17H5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="7" y="13.5" width="10" height="7" rx="1"/><circle cx="17.3" cy="10.8" r="0.9" fill="%C" stroke="none"/>
E
cat > keyboard.svgbody <<'E'
<rect x="3" y="6" width="18" height="12" rx="2.5"/><path d="M8.5 14.8h7"/><circle cx="7" cy="9.6" r="0.95" fill="%C" stroke="none"/><circle cx="10.3" cy="9.6" r="0.95" fill="%C" stroke="none"/><circle cx="13.7" cy="9.6" r="0.95" fill="%C" stroke="none"/><circle cx="17" cy="9.6" r="0.95" fill="%C" stroke="none"/><circle cx="6.5" cy="12.2" r="0" fill="%C" stroke="none"/>
E
cat > restore.svgbody <<'E'
<path d="M4 12a8 8 0 1 0 2.4-5.7L4 8.7"/><path d="M4 4.5v4.2h4.2"/><path d="M12 8v4l2.8 1.8"/>
E
cat > dua.svgbody <<'E'
<path d="M12 3.5v8.5h8.5A8.5 8.5 0 0 0 12 3.5z"/><path d="M20.1 14.6A8.5 8.5 0 1 1 9.4 3.9"/>
E
cat > uuctl.svgbody <<'E'
<path d="M7.5 4.5H4v15h3.5M16.5 4.5H20v15h-3.5"/><circle cx="9.3" cy="12" r="1.9" fill="%C" stroke="none"/><path d="M13 9l3.2 3-3.2 3z"/>
E
cat > wiremix.svgbody <<'E'
<path d="M6 4v16M12 4v16M18 4v16"/><path d="M4 14.5h4M10 8h4M16 12.5h4"/>
E
cat > wiremix2.svgbody <<'E'
<path d="M6 3.5v4.2M6 11.7v8.8M12 3.5v10.2M12 17.7v2.8M18 3.5v2.2M18 9.7v10.8"/><circle cx="6" cy="9.7" r="2"/><circle cx="12" cy="15.7" r="2"/><circle cx="18" cy="7.7" r="2"/>
E
cat > impala.svgbody <<'E'
<path d="M3.5 9.5a12 12 0 0 1 17 0M6.5 12.8a7.7 7.7 0 0 1 11 0M9.4 16a3.6 3.6 0 0 1 5.2 0"/><circle cx="12" cy="19" r="1.2" fill="%C" stroke="none"/>
E
sed -i 's|<circle cx="6.5" cy="12.2" r="0" fill="%C" stroke="none"/>||' keyboard.svgbody
S=~/.claude/skills/taskbar-icons/scripts/icon-preview
$S p1.png btop.svgbody btop2.svgbody htop.svgbody htop2.svgbody disks.svgbody disks2.svgbody printer.svgbody keyboard.svgbody; $S p2.png restore.svgbody dua.svgbody uuctl.svgbody wiremix.svgbody wiremix2.svgbody impala.svgbody
