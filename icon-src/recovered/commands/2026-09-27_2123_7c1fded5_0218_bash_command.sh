d=$(cat /tmp/claude-1000/cx/scallop.txt); f=~/.config/omarchy/bar/modules/taskbar-icons.js; python3 - "$f" "$d" <<'PYEOF'
import sys, re, json, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
new = '<path d="%s"/><path d="M9.3 10l2 2-2 2M12.9 14.3h2.2"/>' % sys.argv[2]
s2 = re.sub(r'("codex": )"[^"\n]*(?:\\.[^"\n]*)*"', lambda m: m.group(1) + json.dumps(new), s, count=1)
assert s2 != s
p.write_text(s2)
PYEOF
grep -n '"codex"' $f | cut -c1-120; omarchy restart shell >/dev/null 2>&1; sleep 5; id=$(ls -t /run/user/1000/quickshell/by-id/ | head -1); qs log --id $id 2>/dev/null | grep -iE 'taskbar|modules/' | head -3; rm -rf /tmp/claude-1000/cx
