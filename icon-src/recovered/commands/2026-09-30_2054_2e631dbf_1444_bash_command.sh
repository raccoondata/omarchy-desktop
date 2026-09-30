cd ~/Projects/personal/omarchy-desktop/icon-src && python3 - <<'PYEOF'
p='recover-from-transcripts'
s=open(p).read()
def rep(old,new):
    global s
    assert old in s, old[:60]
    s=s.replace(old,new,1)
rep('''    base = DRAFT_SUFFIX.sub("", stem)
    return base if base in known else stem''','''    for base in (DRAFT_SUFFIX.sub("", stem), re.sub(r"\\d+$", "", stem)):
        if base in known:
            return base
    return stem''')
rep('''def names_in(text):
    found = set(NAME_FROM_FILE.findall(text))
    found |= set(re.findall(r"icon-set\\s+([a-z0-9_-]+)\\s", text))
    return sorted(n for n in found if n not in {"body", "b", "icon", "test"})''','''def names_in(text, known=()):
    found = set(NAME_FROM_FILE.findall(text))
    found |= set(re.findall(r"icon-set\\s+([a-z0-9_-]+)\\s", text))
    # Known icon names used as a key or a file name: "claude", 'claude', claude.txt
    for n in known:
        if len(n) > 1 and re.search(r"[\\"'/\\s]" + re.escape(n) + r"(\\.(txt|svg|svgbody|py)|[\\"'])", text):
            found.add(n)
    return sorted(n for n in found if n not in {"body", "b", "icon", "test", "app"})''')
rep('''            icons = names_in(fp + "\\n" + content[:4000])''','''            icons = names_in(fp + "\\n" + content, known)
            # A command about a few icons: linked from their folders too.
            if 0 < len(icons) <= 4 and kind != "file":
                for icon in icons:
                    d = OUT / "by-icon" / icon
                    if icon in known:
                        d.mkdir(exist_ok=True)
                        link = d / f"{stamp}_{session}_{kind}.sh"
                        if not link.exists():
                            link.symlink_to(pathlib.Path("../..") / fname)''')
open(p,'w').write(s)
PYEOF
./recover-from-transcripts; comm -23 <(ls recovered/by-icon) <(~/.claude/skills/taskbar-icons/scripts/icon-set --list | tr ' ' '\n' | grep -v ':' | sort) | tr '\n' ' '; echo; ls recovered/by-icon/claude recovered/by-icon/codex; for d in recovered/by-icon/*/; do [[ $(ls $d | wc -l) -gt 1 ]] && echo x; done | wc -l; head -30 recovered/by-icon/claude/*bash.sh | cut -c1-120 | head -30
