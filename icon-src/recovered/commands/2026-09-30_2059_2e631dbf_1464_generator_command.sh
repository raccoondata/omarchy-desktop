cd ~/.claude/skills/taskbar-icons/scripts && python3 - <<'PYEOF'
p='iconkit.py'
s=open(p).read()
def rep(old,new):
    global s
    assert old in s, old[:60]
    s=s.replace(old,new,1)
rep('''STROKE = 1.75        # the only stroke weight; round caps and joins''','''STROKE = 1.75        # the default stroke weight (round caps and joins); an
                     # element can set its own with weight=
WEIGHTS = (1.0, 2.5) # stroke weights outside this range get a warning''')
rep('''ATTRS = {"d", "cx", "cy", "r", "rx", "ry", "x", "y", "width", "height", "fill", "stroke"}''','''ATTRS = {"d", "cx", "cy", "r", "rx", "ry", "x", "y", "width", "height", "fill", "stroke", "stroke-width"}''')
rep('''def path(d):
    """A stroked path. d: SVG path data (hand-written, or from the helpers below)."""
    return f'<path d="{d}"/>'


def circle(cx, cy, r):
    return f"<circle{_attrs(cx=cx, cy=cy, r=r)}/>"


def ellipse(cx, cy, rx, ry):
    return f"<ellipse{_attrs(cx=cx, cy=cy, rx=rx, ry=ry)}/>"


def rect(x, y, w, h, rx=None):
    return f"<rect{_attrs(x=x, y=y, width=w, height=h, rx=rx)}/>"''','''# weight=: this element's stroke weight, when not the default STROKE.
def path(d, weight=None):
    """A stroked path. d: SVG path data (hand-written, or from the helpers below)."""
    return f'<path d="{d}"{_attrs(stroke_width=weight)}/>'


def circle(cx, cy, r, weight=None):
    return f"<circle{_attrs(cx=cx, cy=cy, r=r, stroke_width=weight)}/>"


def ellipse(cx, cy, rx, ry, weight=None):
    return f"<ellipse{_attrs(cx=cx, cy=cy, rx=rx, ry=ry, stroke_width=weight)}/>"


def rect(x, y, w, h, rx=None, weight=None):
    return f"<rect{_attrs(x=x, y=y, width=w, height=h, rx=rx, stroke_width=weight)}/>"''')
rep('''def rotate(points, deg, cx=12, cy=12):''','''def ellipse_path(cx, cy, rx, ry, deg=0):
    """Path data for an ellipse turned `deg` clockwise about its centre (the
    spec has no transforms; the turn is in the arc itself)."""
    a = math.radians(deg)
    p1 = (cx - rx * math.cos(a), cy - rx * math.sin(a))
    p2 = (cx + rx * math.cos(a), cy + rx * math.sin(a))
    r = f"{num(rx)} {num(ry)} {num(deg)}"
    return f"M{pt(p1)}A{r} 0 1 {pt(p2)}A{r} 0 1 {pt(p1)}Z"


def rotate(points, deg, cx=12, cy=12):''')
rep('''            problems.append(("error", f"{attr}=: not allowed (one stroke weight, no transforms or styles)"))''','''            problems.append(("error", f"{attr}=: not allowed (no transforms, classes or styles)"))
        elif attr == "stroke-width":
            try:
                w = float(value)
            except ValueError:
                w = -1
            if not WEIGHTS[0] <= w <= WEIGHTS[1]:
                problems.append(("warn", f"stroke weight {value} is outside {WEIGHTS[0]:g}..{WEIGHTS[1]:g}"))''')
# to_script: carry stroke-width as weight=
rep('''        filled = at.get("fill") == "%C" and at.get("stroke") == "none"
        g = lambda k: at.get(k, "0")''','''        filled = at.get("fill") == "%C" and at.get("stroke") == "none"
        g = lambda k: at.get(k, "0")
        w = f", weight={at.pop('stroke-width')}" if "stroke-width" in at else ""''')
rep('''            calls.append(f'path("{at["d"]}")')''','''            calls.append(f'path("{at["d"]}"{w})')''')
rep('''            calls.append(f"circle({g('cx')}, {g('cy')}, {g('r')})")''','''            calls.append(f"circle({g('cx')}, {g('cy')}, {g('r')}{w})")''')
rep('''            calls.append(f"ellipse({g('cx')}, {g('cy')}, {g('rx')}, {g('ry')})")''','''            calls.append(f"ellipse({g('cx')}, {g('cy')}, {g('rx')}, {g('ry')}{w})")''')
rep('''            calls.append(f"rect({g('x')}, {g('y')}, {g('width')}, {g('height')}{rx})")''','''            calls.append(f"rect({g('x')}, {g('y')}, {g('width')}, {g('height')}{rx}{w})")''')
open(p,'w').write(s)
PYEOF
python3 -c "
import sys; sys.path.insert(0,'.'); from iconkit import *
print(path('M1 1', weight=1.4)); print(ellipse_path(12,12,9,4,60)); print(num(3.0), num(0.125), num(-0.001), num(12.50))
print(lint(rect(3,4.5,18,15,rx=3)+path('M7.5 9.5l2.5 2.5-2.5 2.5M12.5 15h4')))
print(lint('<g transform=\"x\"><path d=\"M0 0L24 24\" stroke=\"#fff\"/></g>'))"
