f=~/.config/omarchy/bar/modules/taskbar-icons.js; python3 - "$f" /tmp/claude-1000/cl/D.txt <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().split("\n")
body = pathlib.Path(sys.argv[2]).read_text()
idx = [i for i, l in enumerate(lines) if l.lstrip().startswith('"claude":')]
assert len(idx) == 1
lines[idx[0]] = '  "claude": ' + json.dumps(body) + ','
p.write_text("\n".join(lines))
PYEOF
node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8").replace(".pragma library",""); new Function(s+"; if(!icons.claude||!icons.codex) throw 1; console.log(Object.keys(icons).length+\" icons parse ok\")")()' $f
omarchy restart shell >/dev/null 2>&1; sleep 6; id=$(ls -t /run/user/1000/quickshell/by-id/ | head -1); qs log --id $id 2>/dev/null | grep -iE 'taskbar|modules/' | head -3
mon=$(hyprctl monitors -j | jq -r '.[0] | "\(.x),\(.y) 900x40"'); grim -g "$mon" /tmp/claude-1000/cl/bar.png && echo shot
