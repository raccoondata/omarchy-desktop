cd /tmp/claude-1000/cx && python3 - <<'PYEOF'
import math
def scallop(n=8, R=7.3, r=3.05, cx=12, cy=12):
    pts = [(cx + R*math.cos(math.radians(k*360/n - 90 + 180/n)), cy + R*math.sin(math.radians(k*360/n - 90 + 180/n))) for k in range(n)]
    d = f"M{pts[0][0]:.2f} {pts[0][1]:.2f}"
    for k in range(1, n + 1):
        x, y = pts[k % n]
        d += f"A{r} {r} 0 0 1 {x:.2f} {y:.2f}"
    return d + "Z"
prompt = "M9.3 10l2 2-2 2M12.9 14.3h2.2"
opts = {
  "A: outlined badge": f'<path d="{scallop()}"/><path d="{prompt}"/>',
  "B: solid badge": f'<path d="{scallop()}" fill="FG"/><path d="{prompt}" stroke="BG"/>',
  "C: current cloud": '<path d="M7.5 18.5h9a4 4 0 0 0 .55-7.96A5.5 5.5 0 0 0 6.7 9.3a4.6 4.6 0 0 0 .8 9.2z"/><path d="M9.6 12.3l1.8 1.5-1.8 1.5M13 15.4h2"/>',
}
open("scallop.txt","w").write(scallop())
BG, FG, AC = "#031222", "#f6dcac", "#faa968"
cells = []
for i, (name, body) in enumerate(opts.items()):
    x = 30 + i*200
    for size, y, col in [(3.5, 20, FG), (0.95, 130, FG), (0.95, 160, AC)]:
        b = body.replace("FG", col).replace("BG", BG)
        cells.append(f'<g transform="translate({x + (0 if size>1 else 60)} {y}) scale({size})" fill="none" stroke="{col}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{b}</g>')
    cells.append(f'<text x="{x+42}" y="205" font-family="JetBrains Mono" font-size="13" fill="{FG}" text-anchor="middle">{name}</text>')
open("opts.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="620" height="225"><rect width="100%" height="100%" fill="{BG}"/>{"".join(cells)}</svg>')
PYEOF
rsvg-convert opts.svg -o opts.png && echo ok
