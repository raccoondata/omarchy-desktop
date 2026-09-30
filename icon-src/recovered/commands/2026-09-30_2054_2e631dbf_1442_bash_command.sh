cd ~/Projects/personal/omarchy-desktop/icon-src && python3 - <<'PYEOF'
p='recover-from-transcripts'
s=open(p).read()
def rep(old,new):
    global s
    assert old in s, old[:60]
    s=s.replace(old,new,1)
rep('''Every tool call that wrote an icon body or an icon script, or ran icon-set /
icon-preview / an icon generator, is saved as a file named
<date>_<time>_<session>_<n>_<what>, and listed in <out-dir>/INDEX.md with the
icon names it mentions. Safe to run again: it rewrites <out-dir>.''','''Output:
  by-icon/<name>/      every drawing of that icon, oldest first
                       (<date>_<time>_<session>_<file>): drafts, alternates,
                       and final.svgbody, the one in the current icon set
  commands/            the commands and scripts that drew, generated or added
                       icons (heredocs, generators, icon-set runs)
  INDEX.md             all of it by date, with the icon names each mentions
Safe to run again: it rewrites <out-dir>.''')
rep('''NAME_FROM_FILE = re.compile''','''HEREDOC = re.compile(r"cat\\s*>\\s*(\\S+\\.svgbody)\\s*<<\\s*'?(\\w+)'?\\n(.*?)\\n\\2\\s*(?:\\n|$)", re.S)
DRAFT_SUFFIX = re.compile(r"([-_](v\\d+|alt\\w*|[a-z]|\\d+|old|new|draft\\w*))+$")
NAME_FROM_FILE = re.compile''')
rep('''def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    rows = []
    seen = set()''','''def icon_of(filename, known):
    stem = pathlib.Path(filename).name.split(".")[0].lower()
    if stem in known:
        return stem
    base = DRAFT_SUFFIX.sub("", stem)
    return base if base in known else stem


def final_icons():
    js = HOME / ".config/omarchy/bar/modules/taskbar-icons.js"
    out = {}
    for line in js.read_text().split("\\n"):
        m = re.match(r'^  ("[a-z0-9_-]+"): (".*"),?$', line)
        if m:
            out[json.loads(m.group(1))] = json.loads(m.group(2))
    try:
        out.update(json.loads((HOME / ".config/omarchy/taskbar-icons.json").read_text()).get("icons", {}))
    except (OSError, ValueError):
        pass
    return out


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "commands").mkdir(parents=True)
    (OUT / "by-icon").mkdir()
    finals = final_icons()
    known = set(finals)
    rows = []
    seen = set()

    def save_drawing(stamp, session, filename, body, src):
        name = icon_of(filename, known)
        d = OUT / "by-icon" / name
        d.mkdir(exist_ok=True)
        key = (name, hash(body.strip()))
        if key in seen:
            return
        seen.add(key)
        (d / f"{stamp}_{session}_{pathlib.Path(filename).name}").write_text(body.strip() + "\\n")
        rows.append((stamp, session, "drawing", f"by-icon/{name}/{stamp}_{session}_{pathlib.Path(filename).name}", src, [name]))
''')
rep('''            kind, name, content = got
            key = hash(content)
            if key in seen:
                continue
            seen.add(key)
            stamp = (ts[:16] or "0000-00-00T00:00").replace(":", "").replace("T", "_")
            fname = f"{stamp}_{session}_{n:04d}_{kind}_{name}"
            (OUT / fname).write_text(content)
            fp = str(inp.get("file_path", ""))
            icons = names_in(fp + "\\n" + content[:4000])
            rows.append((stamp, session, kind, fname, fp or (content.strip().splitlines() or [""])[0][:90], icons))''','''            kind, name, content = got
            stamp = (ts[:16] or "0000-00-00T00:00").replace(":", "").replace("T", "_")
            fp = str(inp.get("file_path", ""))
            # Single drawings: into by-icon/.
            if kind == "file" and fp.endswith((".svgbody", ".svg")) and SVG_BODY.search(content):
                save_drawing(stamp, session, fp, content, fp)
                continue
            if kind == "iconset":
                continue  # the full set: its icons are in final.svgbody
            # Heredocs inside commands: each drawing into by-icon/ too.
            for hfile, _, body in HEREDOC.findall(content):
                if SVG_BODY.search(body):
                    save_drawing(stamp, session, hfile, body, f"heredoc in a {tool} command")
            key = hash(content)
            if key in seen:
                continue
            seen.add(key)
            fname = f"commands/{stamp}_{session}_{n:04d}_{kind}_{name}"
            (OUT / fname).write_text(content)
            icons = names_in(fp + "\\n" + content[:4000])
            rows.append((stamp, session, kind, fname, fp or (content.strip().splitlines() or [""])[0][:90], icons))
    for name, body in finals.items():
        d = OUT / "by-icon" / name
        d.mkdir(exist_ok=True)
        (d / "final.svgbody").write_text(body + "\\n")''')
rep('''"Newest at the bottom. `kind`: file = a drawing/script written to disk, "
                  "iconset = a full taskbar-icons.js, edit = an edit to one, "
                  "bash = a command that drew, generated or added icons.\\n\\n")''','''"Newest at the bottom. `kind`: drawing = one icon body (draft or final), "
                  "file = another icon file or script, edit = an edit to one, generator = a script "
                  "that computed a drawing, bash = a command that drew, generated or added icons.\\n\\n")''')
open(p,'w').write(s)
PYEOF
./recover-from-transcripts && ls recovered/by-icon | wc -l && for d in recovered/by-icon/*/; do n=$(ls $d | grep -vc final); echo "$(basename $d):$n"; done | awk -F: '{t+=$2; if($2>0) h++} END {print t" drafts across "h" icons"}'; ls recovered/by-icon/mpv recovered/by-icon/claude | head -20; ls recovered/commands | wc -l
