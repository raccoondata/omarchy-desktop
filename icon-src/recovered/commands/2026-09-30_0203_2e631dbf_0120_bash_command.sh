SP=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad; cd $SP
cat > edge1.svg <<'EOF'
<path d="M20.6 13.2A8.7 8.7 0 1 0 15.2 20.5"/>
<path d="M20.6 13.2C20.6 9.8 17.8 7.6 14.4 7.6C10.6 7.6 8.2 10.3 8.2 13.2C8.2 16.4 10.9 18.4 13.8 18.4C16.2 18.4 17.8 17.2 18.4 16"/>
EOF
cat > edge2.svg <<'EOF'
<path d="M20.5 12.5A8.5 8.5 0 1 0 12 20.5"/>
<path d="M20.5 12.5C20.5 16 17.5 17.5 15 17.5C11.5 17.5 10 15 10 13C10 11 11.5 10 13.5 10.5"/>
<path d="M12 20.5C15 20.5 17.5 19 18.8 17"/>
EOF
cat > edge3.svg <<'EOF'
<path d="M4.2 14A8.3 8.3 0 1 1 20.6 12.2C20.6 15.4 18.2 17.2 15.4 17.2C12.6 17.2 11 15.6 11 13.8C11 12.4 12 11.4 13.4 11.4"/>
<path d="M4.2 14C4.8 18 8.6 20.8 12.6 20.8C15.4 20.8 17.8 19.6 19.2 17.6"/>
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview $SP/edge.png edge1.svg edge2.svg edge3.svg && echo ok
