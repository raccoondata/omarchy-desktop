cd ~/Projects/personal/omarchy-desktop/icon-src && python3 - <<'PYEOF'
p='recover-from-transcripts'
s=open(p).read()
def rep(old,new):
    global s
    assert old in s, old[:60]
    s=s.replace(old,new,1)
rep('''HEREDOC = re.compile(r"cat\\s*>\\s*(\\S+\\.svgbody)\\s*<<''','''HEREDOC = re.compile(r"cat\\s*>\\s*(\\S+\\.(?:svgbody|svg|txt))\\s*<<''')
rep('''def icon_of(filename, known):''','''def echo_drawings(cmd):
    """(file, body) for lines like  echo "$P"'<path .../>' > writer.svgbody,
    with shell variables (NAME='...' assignments earlier in the command)
    expanded by hand; nothing is run."""
    import shlex
    env, out = {}, []
    for line in re.split(r"\\n|;\\s*|&&", cmd):
        line = line.strip()
        m = re.match(r"^([A-Za-z_]\\w*)=(.+)$", line)
        if m:
            try:
                env[m.group(1)] = " ".join(shlex.split(m.group(2)))
            except ValueError:
                pass
            continue
        m = re.match(r"^(?:echo|printf '%s\\\\n')\\s+(.+?)\\s*>\\s*(\\S+\\.(?:svgbody|svg|txt))$", line)
        if m:
            try:
                parts = shlex.split(m.group(1))
            except ValueError:
                continue
            text = " ".join(parts)
            text = re.sub(r"\\$\\{?([A-Za-z_]\\w*)\\}?", lambda v: env.get(v.group(1), v.group(0)), text)
            out.append((m.group(2), text))
    return out


def icon_of(filename, known):''')
rep('''            for hfile, _, body in HEREDOC.findall(content):
                if SVG_BODY.search(body):
                    save_drawing(stamp, session, hfile, body, f"heredoc in a {tool} command")''','''            for hfile, _, body in HEREDOC.findall(content):
                if SVG_BODY.search(body):
                    save_drawing(stamp, session, hfile, body, f"heredoc in a {tool} command")
            for efile, body in echo_drawings(content):
                if SVG_BODY.search(body) and "$" not in body:
                    save_drawing(stamp, session, efile, body, f"echo in a {tool} command")''')
open(p,'w').write(s)
PYEOF
./recover-from-transcripts; total=$(ls recovered/by-icon | wc -l); with=$(for d in recovered/by-icon/*/; do [[ $(ls $d | wc -l) -gt 1 ]] && echo; done | wc -l); echo "$with of $total"; ls recovered/by-icon | while read i; do [[ $(ls recovered/by-icon/$i | wc -l) -eq 1 ]] && printf '%s ' $i; done; echo; comm -23 <(ls recovered/by-icon) <(~/.claude/skills/taskbar-icons/scripts/icon-set --list | tr ' ' '\n' | grep -v ':' | sort) | tr '\n' ' '; echo; ls recovered/by-icon/writer; cat recovered/by-icon/writer/$(ls recovered/by-icon/writer | head -1)
