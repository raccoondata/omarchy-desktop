f=~/.config/omarchy/bar/modules/taskbar-icons.js; q=~/.config/omarchy/bar/modules/taskbar.qml; python3 - "$f" /tmp/claude-1000/vs/A.txt <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().split("\n")
body = pathlib.Path(sys.argv[2]).read_text()
assert not any(l.lstrip().startswith('"vscode":') for l in lines)
idx = [i for i, l in enumerate(lines) if l.lstrip().startswith('"code":')]
assert len(idx) == 1
lines.insert(idx[0] + 1, '  "vscode": ' + json.dumps(body) + ',')
p.write_text("\n".join(lines))
PYEOF
grep -n 'cursor|dev' $q
