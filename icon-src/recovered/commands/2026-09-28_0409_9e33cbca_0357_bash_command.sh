S=/tmp/claude-1000/-home-user-Work/9e33cbca-f705-4147-928b-bb34b1860cb1/scratchpad; cd $S
cat > ytm-a.svg <<'EOF'
<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5.4"/><path d="M10.5 9.5l4.1 2.5-4.1 2.5z" fill="%C" stroke="none"/>
EOF
cat > ytm-b.svg <<'EOF'
<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5.4"/><path d="M11 10.2l2.9 1.8-2.9 1.8z"/>
EOF
cat > ytm-c.svg <<'EOF'
<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5.6" stroke-width="1.35"/><path d="M10.5 9.4l4.2 2.6-4.2 2.6z" fill="%C" stroke="none"/>
EOF
printf '%s' '<circle cx="12" cy="12" r="8.5"/><path d="M10.2 8.8l5 3.2-5 3.2z"/>' > play-existing.svg
~/.claude/skills/taskbar-icons/scripts/icon-preview ytm.png ytm-a.svg ytm-b.svg ytm-c.svg play-existing.svg && echo ok
