f=~/.config/omarchy/bar/modules/taskbar-icons.js; python3 - "$f" /tmp/claude-1000/wa/icons.json <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().split("\n")
new = json.load(open(sys.argv[2]))
existing = {l.strip().split('"')[1] for l in lines if l.strip().startswith('"') and '":' in l}
clash = set(new) & existing
assert not clash, clash
end = max(i for i, l in enumerate(lines) if l.strip().startswith('"') and '":' in l)
if not lines[end].rstrip().endswith(","): lines[end] = lines[end].rstrip() + ","
entries = [f'  {json.dumps(k)}: {json.dumps(v)},' for k, v in new.items()]
entries[-1] = entries[-1].rstrip(",")
lines[end+1:end+1] = entries
p.write_text("\n".join(lines))
PYEOF
node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8").replace(".pragma library",""); new Function(s+"; for (const k of [\"youtube\",\"ghostty\",\"chatgpt\",\"contacts\",\"claude\"]) if(!icons[k]) throw k; console.log(Object.keys(icons).length+\" icons parse ok\")")()' $f; sed -n '/readonly property var classIcons/,/^  \]/p' ~/.config/omarchy/bar/modules/taskbar.qml
