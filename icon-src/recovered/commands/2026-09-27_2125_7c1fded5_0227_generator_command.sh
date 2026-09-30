cd /tmp/claude-1000/cl && python3 - <<'PYEOF'
import math
def rays(n, lens, jit, start=0.0):
    d = ""
    for i in range(n):
        a = math.radians(i*360/n - 90 + jit[i]); L = lens[i]
        d += f"M{12+start*math.cos(a):.2f} {12+start*math.sin(a):.2f}L{12+L*math.cos(a):.2f} {12+L*math.sin(a):.2f}"
    return f'<path d="{d}"/>'
def tapered(n, lens, jit, base=0.95, tip=0.5, hub=1.7):
    d = ""
    for i in range(n):
        a = math.radians(i*360/n - 90 + jit[i]); nrm = a + math.pi/2; L = lens[i]
        bx, by = 12 + 0.8*math.cos(a), 12 + 0.8*math.sin(a)
        tx, ty = 12 + (L-0.45)*math.cos(a), 12 + (L-0.45)*math.sin(a)
        p = [(bx+base*math.cos(nrm), by+base*math.sin(nrm)), (tx+tip*math.cos(nrm), ty+tip*math.sin(nrm)),
             (tx-tip*math.cos(nrm), ty-tip*math.sin(nrm)), (bx-base*math.cos(nrm), by-base*math.sin(nrm))]
        d += "M" + "L".join(f"{x:.2f} {y:.2f}" for x, y in p) + "Z"
    return f'<circle cx="12" cy="12" r="{hub}" fill="FG" stroke="none"/><path d="{d}" fill="FG" stroke="FG" stroke-width="0.9"/>'
L11 = [9.0, 6.9, 8.2, 7.4, 8.8, 6.6, 8.5, 7.1, 8.9, 6.8, 7.9]
J11 = [0, 5, -3, 4, -2, 6, -4, 3, -1, 5, -3]
opts = {
  "A: 12 uneven": open("A.txt").read(),
  "D: 11 uneven": rays(11, L11, J11),
  "E: 11 slim taper": tapered(11, L11, J11),
}
open("D.txt","w").write(opts["D: 11 uneven"]); open("E.txt","w").write(opts["E: 11 slim taper"])
BG, FG, AC = "#031222", "#f6dcac", "#faa968"
for key, body in opts.items():
    tag = key[0]
    for col, suffix in [(FG, "fg"), (AC, "ac")]:
        b = body.replace("FG", col)
        open(f"{tag}-{suffix}.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="{col}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{b}</svg>')
PYEOF
# Render each at the real taskbar size (18px), then scale up 6x with nearest-neighbour so pixels are visible,
# plus a large version for shape.
for t in A D E; do
  rsvg-convert -w 18 -h 18 -b '#031222' $t-fg.svg -o $t-small.png
  rsvg-convert -w 18 -h 18 -b '#031222' $t-ac.svg -o $t-small-ac.png
  rsvg-convert -w 96 -h 96 -b '#031222' $t-fg.svg -o $t-big.png
  magick $t-small.png -filter point -resize 600% $t-small-x6.png
  magick $t-small-ac.png -filter point -resize 600% $t-small-ac-x6.png
  magick $t-big.png $t-small-x6.png $t-small-ac-x6.png -background '#031222' -gravity center +append -bordercolor '#031222' -border 12 $t-row.png
done
magick A-row.png D-row.png E-row.png -append cmp.png && echo ok
