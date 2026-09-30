S=/tmp/claude-1000/-home-user-Work/9e33cbca-f705-4147-928b-bb34b1860cb1/scratchpad; cd $S
cat > tg-final.svg <<'EOF'
<circle cx="12" cy="12" r="9"/><path d="M6.1 11.9l11.2-4.6-1.8 9.6-5.3-3.6z"/><path d="M10.2 13.3l4-3.4"/>
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview tg2.png tg-a.svg tg-final.svg && ~/.claude/skills/taskbar-icons/scripts/icon-set telegram tg-final.svg
