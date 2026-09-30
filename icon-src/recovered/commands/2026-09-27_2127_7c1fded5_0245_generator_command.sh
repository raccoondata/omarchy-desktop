mkdir -p /tmp/claude-1000/ch && cd /tmp/claude-1000/ch && python3 - <<'PYEOF'
import math
R, r = 8.5, 3.2
x0, y0 = 12, 12 - r
x1 = 12 + math.sqrt(R*R - r*r)
def rot(x, y, deg):
    a = math.radians(deg); dx, dy = x - 12, y - 12
    return 12 + dx*math.cos(a) - dy*math.sin(a), 12 + dx*math.sin(a) + dy*math.cos(a)
d = ""
for deg in (0, 120, 240):
    ax, ay = rot(x0, y0, deg); bx, by = rot(x1, y0, deg)
    d += f"M{ax:.2f} {ay:.2f}L{bx:.2f} {by:.2f}"
body = f'<circle cx="12" cy="12" r="{R}"/><circle cx="12" cy="12" r="{r}"/><path d="{d}"/>'
open("chrome.txt","w").write(body)
for col, s in [("#f6dcac","fg"),("#faa968","ac")]:
    open(f"{s}.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="{col}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{body}</svg>')
PYEOF
rsvg-convert -w 96 -h 96 -b '#031222' fg.svg -o big.png; for s in fg ac; do rsvg-convert -w 18 -h 18 -b '#031222' $s.svg -o s.png; magick s.png -filter point -resize 600% $s-x.png; done; magick big.png fg-x.png ac-x.png -background '#031222' -gravity center +append -bordercolor '#031222' -border 12 cmp.png && echo ok
