cd /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/ic; cat > hermes2.svg <<'EOF'
<path d="M4 16C6.6 11.4 11.4 7.8 20.2 5.8C17 8.4 15.4 9.8 14.2 11"/><path d="M4 16C7.4 14.2 11.6 12.8 18 12.2C15.6 13.8 13.6 15 12.2 15.6"/><path d="M4 16C6.8 16.8 10 17.4 14.6 17.2C12.2 18.6 9.4 19.2 7 19"/>
EOF
cat > copilot2.svg <<'EOF'
<path d="M4.5 12.5C4.5 7.8 7.6 5 12 5C16.4 5 19.5 7.8 19.5 12.5V15.2C19.5 17.8 16.4 19.5 12 19.5C7.6 19.5 4.5 17.8 4.5 15.2Z"/><rect x="6.2" y="8" width="5.2" height="4.4" rx="2"/><rect x="12.6" y="8" width="5.2" height="4.4" rx="2"/><circle cx="10" cy="15.6" r=".9" fill="%C" stroke="none"/><circle cx="14" cy="15.6" r=".9" fill="%C" stroke="none"/>
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview ../icons3.png hermes.svg hermes2.svg copilot.svg copilot2.svg
