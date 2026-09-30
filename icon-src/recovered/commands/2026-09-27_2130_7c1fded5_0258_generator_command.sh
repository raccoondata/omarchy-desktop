mkdir -p /tmp/claude-1000/wa && cd /tmp/claude-1000/wa && cat > gen.py <<'PYEOF'
import math, json
def rot(x, y, deg, cx=12, cy=12):
    a = math.radians(deg); dx, dy = x-cx, y-cy
    return cx + dx*math.cos(a) - dy*math.sin(a), cy + dx*math.sin(a) + dy*math.cos(a)
dot = lambda x, y, r=0.95: f'<circle cx="{x}" cy="{y}" r="{r}" fill="%C" stroke="none"/>'

def photos():
    # Pinwheel: four half-discs, each on a spoke from the centre.
    d = ""
    for k in range(4):
        ex, ey = rot(12, 4.2, k*90)
        d += f"M12 12L{ex:.2f} {ey:.2f}A3.9 3.9 0 0 0 12 12Z"
    return f'<path d="{d}"/>'

def openai():
    # Six links wound around the centre, echoing OpenAI's knot.
    d = ""
    for k in range(6):
        a1, a2 = math.radians(k*60 - 90), math.radians(k*60 - 90 + 75)
        d += f"M{12+3.3*math.cos(a1):.2f} {12+3.3*math.sin(a1):.2f}L{12+8.2*math.cos(a2):.2f} {12+8.2*math.sin(a2):.2f}"
    return f'<circle cx="12" cy="12" r="3.3"/><path d="{d}"/>'

icons = {
  "youtube": '<rect x="2.8" y="5.5" width="18.4" height="13" rx="4"/><path d="M10.2 9.4l4.6 2.6-4.6 2.6z"/>',
  "x": '<path d="M4.3 4h4.4l11 16h-4.4z"/><path d="M19.5 4l-6.4 7.1M10.9 12.9L4.5 20"/>',
  "whatsapp": '<path d="M4.3 19.7l1.25-3.9a8.1 8.1 0 1 1 2.9 2.7z"/><path d="M9.4 8.9c.35 2.8 2.9 5.35 5.7 5.7l1-1.45-1.95-1-1 .75a4.6 4.6 0 0 1-2-2l.75-1-1-1.95z"/>',
  "discord": '<path d="M8.7 7.2c-1.6.3-3 .9-4.3 1.7-1.4 3-1.8 6-1.4 9 1.4 1.1 3 1.8 4.6 2.2l1.1-1.8M15.3 7.2c1.6.3 3 .9 4.3 1.7 1.4 3 1.8 6 1.4 9-1.4 1.1-3 1.8-4.6 2.2l-1.1-1.8M7.6 16.9c2.9 1.3 5.9 1.3 8.8 0M8.6 8.7c2.3-.6 4.5-.6 6.8 0"/>' + dot(9.4, 13.2, 1.15) + dot(14.6, 13.2, 1.15),
  "teams": '<rect x="3" y="6.5" width="12" height="11.5" rx="2.5"/><path d="M6.4 9.9h5.2M9 9.9v5.3"/><circle cx="18.2" cy="7.2" r="1.9"/><path d="M15 10.8h4.6c.8 0 1.4.6 1.4 1.4v2.6a3.4 3.4 0 0 1-5.4 2.8"/>',
  "basecamp": '<circle cx="12" cy="12" r="8.5"/><path d="M4.1 14.8c2.3-2.9 4.2-4.9 5.8-4.9 1.8 0 2.3 3.2 4.1 3.2 1.3 0 2.6-1.2 5.8-4.4"/>',
  "chatgpt": openai(),
  "grok": '<path d="M17.3 6.1A7.6 7.6 0 1 0 19 15.6"/><path d="M5 20.4L20.4 4.9"/>',
  "mail": '<rect x="3.2" y="5.5" width="17.6" height="13" rx="2.5"/><path d="M4 7.3l8 5.9 8-5.9"/>',
  "calendar": '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/>' + dot(8.3, 14) + dot(12, 14) + dot(15.7, 14),
  "messages": '<path d="M4.5 6.5a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-7l-4 3.5v-3.5a2 2 0 0 1-2-2z"/><path d="M8.3 9h7.4M8.3 12h4.6"/>',
  "photos": photos(),
  "maps": '<path d="M12 21s-6.5-6-6.5-11a6.5 6.5 0 0 1 13 0c0 5-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
  "contacts": '<circle cx="12" cy="8.8" r="3.3"/><path d="M5.5 19.5c.9-3 3.4-5 6.5-5s5.6 2 6.5 5"/>',
}
json.dump(icons, open("icons.json","w"))
BG, FG, AC = "#031222", "#f6dcac", "#faa968"
cells = []
for i, (name, body) in enumerate(icons.items()):
    col, row = i % 7, i // 7
    x, y = 20 + col*120, 20 + row*150
    for s, dx, dy, c in [(2.6, 0, 0, FG), (0.75, 12, 78, FG), (0.75, 38, 78, AC)]:
        cells.append(f'<g transform="translate({x+dx} {y+dy}) scale({s})" fill="none" stroke="{c}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{body.replace("%C", c)}</g>')
    cells.append(f'<text x="{x+31}" y="{y+118}" font-family="JetBrains Mono" font-size="12" fill="{FG}" text-anchor="middle">{name}</text>')
open("sheet.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="860" height="320"><rect width="100%" height="100%" fill="{BG}"/>{"".join(cells)}</svg>')
PYEOF
python3 gen.py && rsvg-convert sheet.svg -o sheet.png && echo ok
