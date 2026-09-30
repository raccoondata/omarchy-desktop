cd ~/.claude/skills/taskbar-icons/scripts && python3 - <<'PYEOF'
p='icon-set'
s=open(p).read()
def rep(old,new):
    global s
    assert old in s, old[:60]
    s=s.replace(old,new,1)
rep('''Then: omarchy restart shell
"""''','''Then: omarchy restart shell

It also keeps the working files: the body file and every file next to it
whose name starts with <name> (drafts like <name>-b.svgbody, a generator
<name>.py), under icon-src/sources/<name>/<date>/ in the desktop repo on the
maintainer's PC, else ~/.config/omarchy/taskbar-icons-src/<name>/<date>/.
"""''')
rep('''def main():''','''def conf_value(key):
    try:
        for line in CONF.read_text().split("\\n"):
            if line.startswith(key + "="):
                return line.split("=", 1)[1]
    except OSError:
        pass
    return ""


def keep_sources(name, body_file, maintainer_mode):
    import datetime
    import shutil
    repo = conf_value("repo")
    if maintainer_mode and repo:
        root = pathlib.Path(repo) / "icon-src" / "sources"
    else:
        root = HOME / ".config/omarchy/taskbar-icons-src"
    dest = root / name / datetime.datetime.now().strftime("%Y-%m-%d_%H%M")
    src = pathlib.Path(body_file).resolve()
    files = [src] + sorted(f for f in src.parent.iterdir()
                           if f.is_file() and f != src and f.name.lower().startswith(name)
                           and f.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"))
    dest.mkdir(parents=True, exist_ok=True)
    for f in files:
        shutil.copy2(f, dest / f.name)
    return dest, len(files)


def main():''')
rep('''        BUILTIN.write_text("\\n".join(lines))
        print(f"{action} '{name}' in the built-in set''','''        BUILTIN.write_text("\\n".join(lines))
        dest, n = keep_sources(name, rest[1], True)
        print(f"kept {n} working file(s) in {dest}")
        print(f"{action} '{name}' in the built-in set''')
rep('''    tmp.replace(USER)
''','''    tmp.replace(USER)
    dest, n = keep_sources(name, rest[1], False)
    print(f"kept {n} working file(s) in {str(dest).replace(str(HOME), '~')}")
''')
open(p,'w').write(s)
PYEOF
python3 -m py_compile icon-set && echo ok; T=$(mktemp -d); mkdir -p $T/h/.config/omarchy/bar/modules $T/work; cp ~/.config/omarchy/bar/modules/taskbar-icons.js $T/h/.config/omarchy/bar/modules/; echo '<circle cx="12" cy="12" r="8"/>' > $T/work/demo.svgbody; echo '<circle cx="12" cy="12" r="6"/>' > $T/work/demo-b.svgbody; echo 'print(1)' > $T/work/demo.py; echo x > $T/work/demo.png; echo y > $T/work/other.svgbody; HOME=$T/h ./icon-set demo $T/work/demo.svgbody --program demo; find $T/h/.config/omarchy/taskbar-icons-src -type f | sed "s|$T/h/||"; rm -rf $T
