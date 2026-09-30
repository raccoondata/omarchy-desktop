mkdir -p /tmp/claude-1000/icons && cat > /tmp/claude-1000/icons/gen.py <<'PYEOF'
import math, json, pathlib

# Omarchy-style line icons on a 24px grid. "%C" is replaced with the draw
# colour at runtime, so one drawing serves dark/light themes and every state.
def claude_rays(n=10, long=8.6, short=6.4):
    parts = []
    for i in range(n):
        a = math.radians(i * 360 / n - 90)
        r = long if i % 2 == 0 else short
        parts.append(f"M12 12L{12 + r*math.cos(a):.2f} {12 + r*math.sin(a):.2f}")
    return f'<path d="{"".join(parts)}"/>'

dot = lambda x, y, r=0.95: f'<circle cx="{x}" cy="{y}" r="{r}" fill="%C" stroke="none"/>'

icons = {
  "terminal": '<rect x="3" y="4.5" width="18" height="15" rx="3"/><path d="M7.5 9.5l2.5 2.5-2.5 2.5M12.5 15h4"/>',
  "claude": claude_rays(),
  "codex": '<path d="M7.5 18.5h9a4 4 0 0 0 .55-7.96A5.5 5.5 0 0 0 6.7 9.3a4.6 4.6 0 0 0 .8 9.2z"/><path d="M9.6 12.3l1.8 1.5-1.8 1.5M13 15.4h2"/>',
  "neovim": '<path d="M7 18V6l10 12V6"/>',
  "monitor": '<rect x="3" y="4.5" width="18" height="15" rx="3"/><path d="M6.5 13h2.3l1.7-4.2 3 7.4 1.7-4.2h2.3"/>',
  "docker": '<rect x="5.4" y="9" width="3.4" height="3.2" rx=".6"/><rect x="9.8" y="9" width="3.4" height="3.2" rx=".6"/><rect x="14.2" y="9" width="3.4" height="3.2" rx=".6"/><rect x="9.8" y="4.8" width="3.4" height="3.2" rx=".6"/><path d="M3 14.5h18c-1 3.5-4.2 5.5-9 5.5s-8-2-9-5.5z"/>',
  "git": '<circle cx="6.5" cy="6" r="2.2"/><circle cx="6.5" cy="18" r="2.2"/><circle cx="17.5" cy="7.5" r="2.2"/><path d="M6.5 8.2v7.6M17.5 9.7c0 4.3-5 4-9.3 6.9"/>',
  "python": '<path d="M12 8.5H8V6.5C8 4.5 9.5 3 12 3s4 1.5 4 3.5v4c0 1.1-.9 2-2 2h-4c-1.1 0-2 .9-2 2v3c0 2 1.5 3.5 4 3.5s4-1.5 4-3.5v-2h-4"/><path d="M8 8.5H6.5C4.6 8.5 3.5 10 3.5 12s1.1 3.5 3 3.5H8M16 8.5h1.5c1.9 0 3 1.5 3 3.5s-1.1 3.5-3 3.5H16"/>' + dot(10.4, 5.7, .8) + dot(13.6, 18.3, .8),
  "node": '<path d="M12 3l7.8 4.5v9L12 21l-7.8-4.5v-9z"/><path d="M9.6 15.5v-3.6a2.4 2.4 0 0 1 4.8 0v3.6"/>',
  "server": '<rect x="4" y="4.5" width="16" height="6.5" rx="2"/><rect x="4" y="13" width="16" height="6.5" rx="2"/><path d="M11 7.75h5.5M11 16.25h5.5"/>' + dot(7.5, 7.75) + dot(7.5, 16.25),
  "document": '<path d="M6.5 3.5h7l4 4v13h-11z"/><path d="M13.5 3.5v4h4M9 12h6M9 15.5h6"/>',
  "tmux": '<rect x="3" y="4.5" width="18" height="15" rx="3"/><path d="M12 4.5v15M12 12h9"/>',
  "folder": '<path d="M3.5 7.5a2 2 0 0 1 2-2h3.8l2 2.2h7.2a2 2 0 0 1 2 2v7.8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/>',
  "music": '<path d="M9 17.5V6.5l10-2v11"/><circle cx="6.8" cy="17.5" r="2.2"/><circle cx="16.8" cy="15.5" r="2.2"/>',
  "browser": '<circle cx="12" cy="12" r="8.5"/><ellipse cx="12" cy="12" rx="3.8" ry="8.5"/><path d="M3.5 12h17"/>',
  "code": '<path d="M8.5 7.5L4 12l4.5 4.5M15.5 7.5L20 12l-4.5 4.5M13.2 5.5l-2.4 13"/>',
  "chat": '<path d="M4.5 6.5a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-7l-4 3.5v-3.5a2 2 0 0 1-2-2z"/>',
  "video": '<rect x="3" y="7" width="12.5" height="10" rx="2.2"/><path d="M15.5 10.5l5-2.8v8.6l-5-2.8"/>',
  "play": '<circle cx="12" cy="12" r="8.5"/><path d="M10.2 8.8l5 3.2-5 3.2z"/>',
  "image": '<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="9" cy="9.5" r="1.6"/><path d="M20.5 15.5L16 11l-8 8.5"/>',
  "pen": '<path d="M15.5 4.5l4 4L9 19H5v-4z"/><path d="M13.5 6.5l4 4"/>',
  "send": '<path d="M20.5 3.5l-17 7 7 2.8 2.8 7z"/><path d="M20.5 3.5l-10 9.8"/>',
  "app": '<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><path d="M3.5 8.5h17"/>' + dot(6, 6.5, .6) + dot(8, 6.5, .6),
}

out = pathlib.Path.home() / ".config/omarchy/bar/modules/taskbar-icons.js"
out.write_text(
  ".pragma library\n\n"
  "// Taskbar icon set: Omarchy-style line icons on a 24px grid. \"%C\" is the\n"
  "// draw colour, filled in at runtime so one drawing serves dark and light\n"
  "// themes and every state (active, inactive, minimized).\n"
  "var icons = " + json.dumps(icons, indent=2) + "\n\n"
  "function svg(name, color) {\n"
  "  var body = (icons[name] || icons.app).split(\"%C\").join(color)\n"
  "  return \"data:image/svg+xml;utf8,\" + encodeURIComponent(\n"
  "    '<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"' + color +\n"
  "    '\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">' + body + '</svg>')\n"
  "}\n")

# Preview sheet: every icon in the retro-82 dark colours and a light theme.
sheet = pathlib.Path("/tmp/claude-1000/icons")
for mode, bg, fg, accent in [("dark", "#031222", "#f6dcac", "#faa968"), ("light", "#f4f1ea", "#2b2b2b", "#c2572b")]:
    cells = []
    for i, (name, body) in enumerate(icons.items()):
        col, row = i % 8, i // 8
        x, y = 20 + col * 110, 20 + row * 110
        color = accent if name == "terminal" else fg
        cells.append(f'<g transform="translate({x} {y}) scale(2.5)" fill="none" stroke="{color}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{body.replace("%C", color)}</g>'
                     f'<text x="{x+30}" y="{y+85}" font-family="JetBrains Mono" font-size="12" fill="{fg}" text-anchor="middle">{name}</text>')
    rows = (len(icons) + 7) // 8
    (sheet / f"sheet-{mode}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{20+8*110}" height="{20+rows*110}"><rect width="100%" height="100%" fill="{bg}"/>{"".join(cells)}</svg>')
print(len(icons), "icons")
PYEOF
python3 /tmp/claude-1000/icons/gen.py && cd /tmp/claude-1000/icons && for m in dark light; do rsvg-convert sheet-$m.svg -o sheet-$m.png; done && magick sheet-dark.png sheet-light.png -append sheet.png && echo ok
