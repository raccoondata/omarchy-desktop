SP=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad; ~/.claude/skills/taskbar-icons/scripts/icon-set edge $SP/edge3.svg && cd ~/.config/omarchy/bar/modules && python3 - <<'EOF'
p="taskbar.qml"
s=open(p).read()
old='''    [/^(chromium|chromium-browser|google-chrome|google-chrome-stable)$/i, "chrome"],'''
assert old in s
s=s.replace(old, old+'''
    [/^microsoft-edge/i, "edge"],''',1)
old2='''    chrome: "Chromium", whatsapp'''
assert old2 in s
s=s.replace(old2,'''    chrome: "Chromium", edge: "Microsoft Edge", whatsapp''',1)
open(p,"w").write(s)
EOF
grep -n '"edge"' ~/.config/omarchy/bar/modules/taskbar.qml
