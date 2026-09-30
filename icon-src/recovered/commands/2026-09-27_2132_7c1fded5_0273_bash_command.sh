f=~/.config/omarchy/bar/modules/taskbar-icons.js; python3 - "$f" /tmp/claude-1000/st/steam.txt <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().split("\n")
assert not any(l.lstrip().startswith('"steam":') for l in lines)
end = max(i for i, l in enumerate(lines) if l.strip().startswith('"') and '":' in l)
if not lines[end].rstrip().endswith(","): lines[end] = lines[end].rstrip() + ","
lines.insert(end + 1, '  "steam": ' + json.dumps(pathlib.Path(sys.argv[2]).read_text()))
p.write_text("\n".join(lines))
PYEOF
node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8").replace(".pragma library",""); new Function(s+"; if(!icons.steam||!icons.ghostty) throw 1; console.log(Object.keys(icons).length+\" icons parse ok\")")()' $f
