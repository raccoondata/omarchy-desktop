cd /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad; cat > i-tensaku.svg <<'EOF'
<path d="M10.3 4.9C13.7 3.75 17.6 5.8 18.9 9.6C20.1 13.1 18.4 17.25 14.8 18.6C11.1 19.9 6.6 18 5.25 14.25C4.1 10.9 5.6 6.75 9.4 5.25C11.6 4.5 14.1 4.7 15.9 5.6C16.9 6 18 5.4 19.1 4.3"/>
EOF
cat > i-rust1.svg <<'EOF'
<path d="M5.45 16.59A8 8 0 0 1 16.59 5.45"/><path d="M18.55 7.41A8 8 0 0 1 7.41 18.55"/>
EOF
cat > i-rust2.svg <<'EOF'
<path d="M6.1 17.2A7.6 7.6 0 0 1 15.9 5.3"/><path d="M18.7 6.8A7.6 7.6 0 0 1 8.1 18.7"/><path d="M15.9 5.3L17.2 4.1" opacity="0"/>
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview prev.png i-tensaku.svg i-rust1.svg i-rust2.svg
