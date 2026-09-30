sed -i 's/^  at the real taskbar size (about 18px)\./  at the real taskbar size (about 23px: 55% of the 42px bar)./' ~/.claude/skills/taskbar-icons/SKILL.md; grep -n 'real taskbar size' ~/.claude/skills/taskbar-icons/SKILL.md
S=/tmp/claude-1000/-home-user-Work/9e33cbca-f705-4147-928b-bb34b1860cb1/scratchpad; ~/.claude/skills/taskbar-icons/scripts/icon-set youtubemusic $S/ytm-f3.svg
cd ~/.config/omarchy/bar/modules && python3 - <<'PY'
p='taskbar.qml'
s=open(p).read()
old='''    [/^chrome-(www\\.)?youtube\\.com/i, "youtube"],'''
new='''    [/^chrome-(www\\.)?youtube\\.com/i, "youtube"],
    [/^chrome-music\\.youtube\\.com/i, "youtubemusic"],'''
assert old in s, "youtube rule not found"; s=s.replace(old,new,1)
old='''    chrome: "Chromium", whatsapp: "WhatsApp", discord: "Discord", youtube: "YouTube",'''
new='''    chrome: "Chromium", whatsapp: "WhatsApp", discord: "Discord", youtube: "YouTube", youtubemusic: "YouTube Music",'''
assert old in s, "appNames line not found"; s=s.replace(old,new,1)
open(p,'w').write(s)
PY
grep -n 'youtubemusic' taskbar.qml
