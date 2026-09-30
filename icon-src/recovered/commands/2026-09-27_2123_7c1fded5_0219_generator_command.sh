f=~/.config/omarchy/bar/modules/taskbar-icons.js; python3 - "$f" <<'PYEOF'
import sys, json, math, pathlib
def scallop(n=8, R=7.3, r=3.05, cx=12, cy=12):
    pts = [(cx + R*math.cos(math.radians(k*360/n - 90 + 180/n)), cy + R*math.sin(math.radians(k*360/n - 90 + 180/n))) for k in range(n)]
    d = f"M{pts[0][0]:.2f} {pts[0][1]:.2f}"
    for k in range(1, n + 1):
        x, y = pts[k % n]
        d += f"A{r} {r} 0 0 1 {x:.2f} {y:.2f}"
    return d + "Z"
p = pathlib.Path(sys.argv[1]); lines = p.read_text().split("\n")
body = '<path d="%s"/><path d="M9.3 10l2 2-2 2M12.9 14.3h2.2"/>' % scallop()
idx = [i for i, l in enumerate(lines) if l.lstrip().startswith('"codex":')]
assert len(idx) == 1
lines[idx[0]] = '  "codex": ' + json.dumps(body) + ','
p.write_text("\n".join(lines))
PYEOF
node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8").replace(".pragma library",""); new Function(s+"; if(!icons.codex||!icons.claude) throw 1; console.log(Object.keys(icons).length+\" icons parse ok\")")()' $f; omarchy restart shell >/dev/null 2>&1; sleep 5; id=$(ls -t /run/user/1000/quickshell/by-id/ | head -1); qs log --id $id 2>/dev/null | grep -iE 'taskbar|modules/' | head -3; echo "log check done"
