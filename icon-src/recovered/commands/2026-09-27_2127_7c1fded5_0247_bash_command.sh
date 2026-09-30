f=~/.config/omarchy/bar/modules/taskbar-icons.js; python3 - "$f" /tmp/claude-1000/ch/chrome.txt <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().split("\n")
body = pathlib.Path(sys.argv[2]).read_text()
assert not any(l.lstrip().startswith('"chrome":') for l in lines)
idx = [i for i, l in enumerate(lines) if l.lstrip().startswith('"browser":')]
assert len(idx) == 1
lines.insert(idx[0] + 1, '  "chrome": ' + json.dumps(body) + ',')
p.write_text("\n".join(lines))
PYEOF
node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8").replace(".pragma library",""); new Function(s+"; if(!icons.chrome||!icons.vscode) throw 1; console.log(Object.keys(icons).length+\" icons parse ok\")")()' $f; grep -n 'chromium|chrome-' ~/.config/omarchy/bar/modules/taskbar.qml
