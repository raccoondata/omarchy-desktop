cd /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad; mkdir -p ic && cd ic
cat > gemini.svg <<'EOF'
<path d="M12 3.2C12.4 8.2 15.8 11.6 20.8 12C15.8 12.4 12.4 15.8 12 20.8C11.6 15.8 8.2 12.4 3.2 12C8.2 11.6 11.6 8.2 12 3.2Z"/>
EOF
cat > copilot.svg <<'EOF'
<path d="M4.5 12.5C4.5 7.8 7.6 5 12 5C16.4 5 19.5 7.8 19.5 12.5V15.2C19.5 17.8 16.4 19.5 12 19.5C7.6 19.5 4.5 17.8 4.5 15.2Z"/><rect x="6.6" y="8.2" width="4.6" height="3.8" rx="1.7"/><rect x="12.8" y="8.2" width="4.6" height="3.8" rx="1.7"/><path d="M10 14.8v1.4M14 14.8v1.4"/>
EOF
cat > cursor.svg <<'EOF'
<path d="M12 3.2L19.6 7.6V16.4L12 20.8L4.4 16.4V7.6Z"/><path d="M4.4 7.6L12 12L19.6 7.6M12 12V20.8"/>
EOF
cat > opencode.svg <<'EOF'
<rect x="5" y="4" width="14" height="16" rx="1.2"/><rect x="9" y="8" width="6" height="8" rx=".6"/>
EOF
cat > crush.svg <<'EOF'
<path d="M12 19.2C7.2 16 4.2 13.2 4.2 9.8C4.2 7.4 6 5.6 8.3 5.6C9.8 5.6 11.2 6.4 12 7.7C12.8 6.4 14.2 5.6 15.7 5.6C18 5.6 19.8 7.4 19.8 9.8C19.8 13.2 16.8 16 12 19.2Z"/>
EOF
cat > pi.svg <<'EOF'
<path d="M4.6 9C4.9 7.9 5.8 7.4 7.2 7.4H19.4M9.4 7.4C9.4 12 8.8 15.4 7.4 18.4M15 7.4V15.6C15 17.4 16 18 17.8 17.4"/>
EOF
cat > omp.svg <<'EOF'
<circle cx="12" cy="12" r="8.6"/><path d="M8 9.4H16.2M10.3 9.4C10.3 12 10 14 9.2 15.6M13.8 9.4V14.2C13.8 15.4 14.4 15.8 15.6 15.4"/>
EOF
cat > hermes.svg <<'EOF'
<path d="M3.8 17.6C9.5 17.6 15.6 14.2 20.2 5.4C15.2 6.8 11 8.8 8 11.8C6.2 13.6 4.8 15.5 3.8 17.6Z"/><path d="M8.6 14.6C11.2 14.2 14 12.8 16.4 10.4M11 11.2C13 10.4 15 9.2 17 7.6"/>
EOF
cat > muse.svg <<'EOF'
<path d="M12 12C10.1 8.7 8.6 7.2 6.7 7.2C4.6 7.2 3.2 9.4 3.2 12C3.2 14.6 4.6 16.8 6.7 16.8C8.6 16.8 10.1 15.3 12 12C13.9 8.7 15.4 7.2 17.3 7.2C19.4 7.2 20.8 9.4 20.8 12C20.8 14.6 19.4 16.8 17.3 16.8C15.4 16.8 13.9 15.3 12 12Z"/>
EOF
cat > openclaw.svg <<'EOF'
<path d="M7 20.2C6.2 15.6 6.8 11.4 9.4 8.2C11.8 5.4 15.4 4 19.4 4.4C17.6 6 16.4 7.6 15.8 9.6C17.6 9.2 19.4 9.6 20.6 10.6C18.4 13 15.2 14 12.2 13.4C10.8 15.4 10.2 17.6 10.4 20.2"/>
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview ../icons1.png gemini.svg copilot.svg cursor.svg opencode.svg crush.svg; ~/.claude/skills/taskbar-icons/scripts/icon-preview ../icons2.png pi.svg omp.svg hermes.svg muse.svg openclaw.svg; cd ..; magick icons1.png icons2.png +append icons.png
