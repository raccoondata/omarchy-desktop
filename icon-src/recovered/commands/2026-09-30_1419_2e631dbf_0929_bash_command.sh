cd /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad; S=~/.claude/skills/taskbar-icons/scripts; $S/icon-set tensaku i-tensaku.svg && $S/icon-set rustdesk i-rust4.svg && cd ~/.config/omarchy/bar/modules && python3 - <<'EOF'
p='taskbar.qml'
s=open(p).read()
def rep(old,new):
    global s
    assert old in s, old[:80]
    s=s.replace(old,new,1)
rep("""    [/^(org\\.gnome\\.nautilus|nautilus|thunar)/i, "folder"],""","""    [/^(org\\.gnome\\.nautilus|nautilus|thunar)/i, "folder"],
    [/^dev\\.tensaku\\.Tensaku$/i, "tensaku"],
    [/^(rustdesk|com\\.carriez\\.flutter_hbb)$/i, "rustdesk"],""")
rep("""    [/^(libreoffice|soffice|obsidian|typora)/i, "document"],""","""    [/^(libreoffice|soffice|obsidian|md\\.obsidian|typora|org\\.gnome\\.(evince|papers))/i, "document"],""")
rep("""    terminal: "Terminal", neovim: "Neovim", spotify: "Spotify", chatgpt: "ChatGPT\"""","""    terminal: "Terminal", neovim: "Neovim", spotify: "Spotify", chatgpt: "ChatGPT",
    tensaku: "Tensaku", rustdesk: "RustDesk\"""")
open(p,'w').write(s)
EOF
grep -n 'tensaku\|rustdesk\|md\\\\.obsidian' taskbar.qml | head; omarchy-restart-shell >/dev/null 2>&1; sleep 3; qs log --id $(ls -t /run/user/1000/quickshell/by-id/ | head -1) 2>/dev/null | grep -iE 'taskbar|modules/' | tail -3
