S=/tmp/claude-1000/-home-user-Work/9e33cbca-f705-4147-928b-bb34b1860cb1/scratchpad; cd $S
cat > ytm-f1.svg <<'EOF'
<circle cx="12" cy="12" r="9" stroke-width="1.2"/><circle cx="12" cy="12" r="5.9" stroke-width="1.5"/><path d="M10.4 9.3l4.6 2.7-4.6 2.7z" fill="%C" stroke="none"/>
EOF
cat > ytm-f2.svg <<'EOF'
<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5.8" stroke-width="1.3"/><path d="M10.5 9.4l4.4 2.6-4.4 2.6z" fill="%C" stroke="none"/>
EOF
cat > ytm-f3.svg <<'EOF'
<circle cx="12" cy="12" r="9" stroke-width="1.4"/><circle cx="12" cy="12" r="6" stroke-width="1.4"/><path d="M10.2 9.1l5 2.9-5 2.9z" fill="%C" stroke="none"/>
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview ytm2.png ytm-f1.svg ytm-f2.svg ytm-f3.svg play-existing.svg && echo ok
