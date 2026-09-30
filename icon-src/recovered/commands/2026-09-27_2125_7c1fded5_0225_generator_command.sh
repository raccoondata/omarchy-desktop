cd /tmp/claude-1000/cl && python3 - <<'PYEOF'
import math
# Uneven ray lengths and small angle offsets, echoing the real mark.
lengths = [8.9, 7.0, 8.3, 6.4, 8.7, 7.4, 8.0, 6.6, 8.8, 7.2, 8.4, 6.8]
jitter  = [0, 4, -3, 5, -2, 3, -4, 2, 3, -5, 1, -3]
def rays(start=0.0, lens=lengths):
    d = ""
    for i, L in enumerate(lens):
        a = math.radians(i*30 - 90 + jitter[i])
        d += f"M{12+start*math.cos(a):.2f} {12+start*math.sin(a):.2f}L{12+L*math.cos(a):.2f} {12+L*math.sin(a):.2f}"
    return f'<path d="{d}"/>'
def tapered():
    # Each ray is a thin wedge: wide at the centre, narrowing to a rounded tip.
    d = ""
    for i, L in enumerate(lengths):
        a = math.radians(i*30 - 90 + jitter[i]); n = a + math.pi/2
        base, tip = 1.25, 0.55
        bx, by = 12 + 1.2*math.cos(a), 12 + 1.2*math.sin(a)
        tx, ty = 12 + (L-0.4)*math.cos(a), 12 + (L-0.4)*math.sin(a)
        p = [(bx+base*math.cos(n), by+base*math.sin(n)), (tx+tip*math.cos(n), ty+tip*math.sin(n)),
             (tx-tip*math.cos(n), ty-tip*math.sin(n)), (bx-base*math.cos(n), by-base*math.sin(n))]
        d += "M" + "L".join(f"{x:.2f} {y:.2f}" for x, y in p) + "Z"
    return f'<circle cx="12" cy="12" r="2.3" fill="FG" stroke="none"/><path d="{d}" fill="FG" stroke="FG" stroke-width="0.9"/>'
opts = {
  "now": '<path d="' + "".join(f"M12 12L{12+(8.6 if i%2==0 else 6.4)*math.cos(math.radians(i*36-90)):.2f} {12+(8.6 if i%2==0 else 6.4)*math.sin(math.radians(i*36-90)):.2f}" for i in range(10)) + '"/>',
  "A: 12 uneven": rays(0.0),
  "B: open centre": rays(2.3),
  "C: tapered": tapered(),
}
for k, v in [("A", rays(0.0)), ("B", rays(2.3)), ("C", tapered())]:
    open(f"{k}.txt", "w").write(v)
BG, FG, AC = "#031222", "#f6dcac", "#faa968"
cells = []
for i, (name, body) in enumerate(opts.items()):
    x = 25 + i*160
    for size, dx, y, col in [(3.5, 0, 20, FG), (0.95, 30, 130, FG), (0.95, 60, 130, AC)]:
        b = body.replace("FG", col)
        cells.append(f'<g transform="translate({x+dx} {y}) scale({size})" fill="none" stroke="{col}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{b}</g>')
    cells.append(f'<text x="{x+42}" y="185" font-family="JetBrains Mono" font-size="13" fill="{FG}" text-anchor="middle">{name}</text>')
open("opts.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="660" height="200"><rect width="100%" height="100%" fill="{BG}"/>{"".join(cells)}</svg>')
PYEOF
rsvg-convert opts.svg -o opts.png && echo ok
