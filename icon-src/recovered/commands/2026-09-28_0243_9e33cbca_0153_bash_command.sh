S=/tmp/claude-1000/-home-user-Work/9e33cbca-f705-4147-928b-bb34b1860cb1/scratchpad; cd $S
cat > tg-a.svg <<'EOF'
<circle cx="12" cy="12" r="9"/><path d="M6.6 11.8l10.4-4.2-1.7 9-4.9-3.3z"/><path d="M10.4 13.3l3.6-3.1"/>
EOF
cat > tg-b.svg <<'EOF'
<path d="M3.5 11.2l16.5-6.7-2.8 14.6-7.6-5.2z"/><path d="M9.6 13.9l5.4-4.8"/><path d="M9.6 13.9l.8 4.3 2.8-2.3"/>
EOF
cat > tg-c.svg <<'EOF'
<circle cx="12" cy="12" r="9"/><path d="M7 11.9l9.8-3.9-1.6 8.4-4.4-3z"/><path d="M10.8 13.4l.4 2.7 1.5-1.4"/>
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview tg.png tg-a.svg tg-b.svg tg-c.svg && echo ok
