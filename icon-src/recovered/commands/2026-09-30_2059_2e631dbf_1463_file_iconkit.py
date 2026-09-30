# written to: ~/.claude/skills/taskbar-icons/scripts/iconkit.py
"""iconkit: the one place the taskbar icon spec lives in code (ICON-SPEC.md
is the prose). Every icon is a script that builds its drawing with these
helpers and ends with icon(...); every icon tool (icon-preview, icon-lint,
icon-build, icon-set, icon-new) uses the same wrapper, renderer and checks.

An icon script:

    \"\"\"steam: the Steam logo: a piston rod joining a large and a small wheel.\"\"\"
    from iconkit import *

    icon(
        circle(12, 12, 9),
        path("M7 14.5l5-2.5"),
        dot(16, 9, 1.2),
    )

Run it and it prints the SVG body (plus spec warnings on stderr).
"""
import math
import os
import pathlib
import re
import subprocess
import sys
import tempfile

# --- the spec ---------------------------------------------------------------
GRID = 24            # viewBox 0 0 24 24
STROKE = 1.75        # the only stroke weight; round caps and joins
LIVE = (2.0, 22.0)   # ink (stroke included) stays inside this square
CENTRE_TOL = 1.0     # ink box centre within this of (12, 12)
MIN_SIDE = 14.0      # the ink box's longer side is at least this
MAX_DECIMALS = 2
MIN_DOT_R = 0.6      # solid dots: dot(); smaller vanishes at 23px
REAL_PX = 23         # drawn size on the taskbar (55% of a 42px bar)
ELEMENTS = {"path", "circle", "rect", "ellipse"}
ATTRS = {"d", "cx", "cy", "r", "rx", "ry", "x", "y", "width", "height", "fill", "stroke"}


def num(x):
    """A coordinate as the spec writes it: at most 2 decimals, no trailing zeros."""
    s = f"{round(float(x), MAX_DECIMALS):.{MAX_DECIMALS}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def _attrs(**kw):
    return "".join(f' {k.replace("_", "-")}="{num(v) if isinstance(v, (int, float)) else v}"'
                   for k, v in kw.items() if v is not None)


# --- elements -----------------------------------------------------------------
def path(d):
    """A stroked path. d: SVG path data (hand-written, or from the helpers below)."""
    return f'<path d="{d}"/>'


def circle(cx, cy, r):
    return f"<circle{_attrs(cx=cx, cy=cy, r=r)}/>"


def ellipse(cx, cy, rx, ry):
    return f"<ellipse{_attrs(cx=cx, cy=cy, rx=rx, ry=ry)}/>"


def rect(x, y, w, h, rx=None):
    return f"<rect{_attrs(x=x, y=y, width=w, height=h, rx=rx)}/>"


def dot(cx, cy, r=1.0):
    """A solid dot in the draw colour (the only fill the spec allows)."""
    return f'<circle{_attrs(cx=cx, cy=cy, r=r)} fill="%C" stroke="none"/>'


def solid(d):
    """A solid shape in the draw colour, no stroke (for small filled marks)."""
    return f'<path d="{d}" fill="%C" stroke="none"/>'


# --- geometry -------------------------------------------------------------------
# Angles are degrees clockwise from 12 o'clock, like a clock face.
def polar(r, deg, cx=12, cy=12):
    a = math.radians(deg)
    return (cx + r * math.sin(a), cy - r * math.cos(a))


def pt(p):
    return f"{num(p[0])} {num(p[1])}"


def poly(points, closed=True):
    """Path data through points (M ... L ... [Z])."""
    d = "M" + "L".join(pt(p) for p in points)
    return d + ("Z" if closed else "")


def rays(lengths, start=0.0, offset=0.0, jitter=None, cx=12, cy=12):
    """Path data for rays from the centre: one per length, evenly spaced from
    `offset`, each nudged by jitter[i] degrees, starting `start` from the centre."""
    n = len(lengths)
    d = ""
    for i, length in enumerate(lengths):
        a = offset + i * 360 / n + (jitter[i] if jitter else 0)
        d += "M" + pt(polar(start, a, cx, cy)) + "L" + pt(polar(length, a, cx, cy))
    return d


def arc(r, a0, a1, cx=12, cy=12):
    """Path data for a circular arc from angle a0 clockwise to a1."""
    sweep = (a1 - a0) % 360
    large = 1 if sweep > 180 else 0
    return f"M{pt(polar(r, a0, cx, cy))}A{num(r)} {num(r)} 0 {large} 1 {pt(polar(r, a1, cx, cy))}"


def rotate(points, deg, cx=12, cy=12):
    """Points turned `deg` clockwise about (cx, cy)."""
    a = math.radians(deg)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a),
             cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a)) for x, y in points]


def scallop(n, R, r, cx=12, cy=12, offset=0.0):
    """Path data for a closed badge of n outward arcs of radius r whose ends sit
    on a circle of radius R."""
    pts = [polar(R, offset + k * 360 / n, cx, cy) for k in range(n)]
    d = "M" + pt(pts[0])
    for k in range(1, n + 1):
        d += f"A{num(r)} {num(r)} 0 0 1 {pt(pts[k % n])}"
    return d + "Z"


# --- output ---------------------------------------------------------------------
def body(*elements):
    return "".join(elements)


def icon(*elements):
    """End of every icon script: print the body; spec problems go to stderr
    (icon-lint and icon-build treat errors as failures)."""
    b = body(*elements)
    for level, msg in lint(b):
        print(f"{level}: {msg}", file=sys.stderr)
    print(b)
    return b


# --- rendering and checks -----------------------------------------------------------
def wrap(b, color="#000", stroke=STROKE):
    """The SVG the taskbar draws (taskbar-icons.js svg()), for rendering."""
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
            f'stroke="{color}" stroke-width="{stroke}" stroke-linecap="round" '
            f'stroke-linejoin="round">{b.replace("%C", color)}</svg>')


def render(b, out, px, color, bg=None):
    args = ["rsvg-convert", "-w", str(px), "-h", str(px), "-o", str(out)]
    if bg:
        args[1:1] = ["-b", bg]
    subprocess.run(args, input=wrap(b, color).encode(), check=True)


def ink_box(b, scale=20):
    """The drawn area (stroke included) in grid units: (x0, y0, x1, y1)."""
    with tempfile.TemporaryDirectory() as tmp:
        png = pathlib.Path(tmp) / "i.png"
        render(b, png, GRID * scale, "#000")
        out = subprocess.run(["magick", str(png), "-alpha", "extract", "-threshold", "1%",
                              "-format", "%@", "info:"], capture_output=True, text=True).stdout
    m = re.match(r"(\d+)x(\d+)\+(\d+)\+(\d+)", out)
    if not m:
        return None
    w, h, x, y = (int(v) for v in m.groups())
    return (x / scale, y / scale, (x + w) / scale, (y + h) / scale)


def lint(b, measure=True):
    """[(level, message)]: 'error' breaks the spec, 'warn' is worth a look."""
    problems = []
    for tag in re.findall(r"<([a-zA-Z]+)\b", b):
        if tag not in ELEMENTS:
            problems.append(("error", f"<{tag}>: only {', '.join(sorted(ELEMENTS))}"))
    for attr, value in re.findall(r'\s([a-zA-Z-]+)="([^"]*)"', b):
        if attr not in ATTRS:
            problems.append(("error", f"{attr}=: not allowed (one stroke weight, no transforms or styles)"))
        elif attr == "fill" and value not in ("%C", "none"):
            problems.append(("error", f'fill="{value}": only "%C" (solid) or "none"'))
        elif attr == "stroke" and value != "none":
            problems.append(("error", f'stroke="{value}": colours come from the wrapper'))
    for n in re.findall(r"\d*\.(\d+)", b):
        if len(n) > MAX_DECIMALS:
            problems.append(("error", f"a number with {len(n)} decimals (max {MAX_DECIMALS})"))
            break
    for r in re.findall(r'<circle[^>]*\sr="([\d.]+)"[^>]*fill="%C"', b):
        if float(r) < MIN_DOT_R:
            problems.append(("warn", f"dot r={r} is under {MIN_DOT_R}: may vanish at {REAL_PX}px"))
    if measure:
        box = ink_box(b)
        if box is None:
            problems.append(("error", "draws nothing"))
        else:
            x0, y0, x1, y1 = box
            lo, hi = LIVE
            if x0 < lo - 0.01 or y0 < lo - 0.01 or x1 > hi + 0.01 or y1 > hi + 0.01:
                problems.append(("error", f"ink {x0:.2f},{y0:.2f}..{x1:.2f},{y1:.2f} leaves the live area {lo:g}..{hi:g}"))
            dx, dy = (x0 + x1) / 2 - 12, (y0 + y1) / 2 - 12
            if abs(dx) > CENTRE_TOL or abs(dy) > CENTRE_TOL:
                problems.append(("warn", f"off centre by {dx:+.1f},{dy:+.1f}"))
            if max(x1 - x0, y1 - y0) < MIN_SIDE:
                problems.append(("warn", f"small: {x1 - x0:.1f}x{y1 - y0:.1f} (longer side under {MIN_SIDE:g})"))
    return problems


# --- running icon scripts -----------------------------------------------------------
KIT = pathlib.Path(__file__).resolve().parent


def run_script(script):
    """(body, stderr) from an icon script, run with iconkit importable."""
    env = dict(os.environ, PYTHONPATH=str(KIT) + os.pathsep + os.environ.get("PYTHONPATH", ""))
    res = subprocess.run([sys.executable, str(script)], capture_output=True, text=True, env=env)
    if res.returncode != 0:
        raise RuntimeError(f"{script}: {res.stderr.strip() or 'failed'}")
    return res.stdout.strip(), res.stderr.strip()


def read_body(file):
    """The drawing in an icon script (.py, run) or a bare body (.svgbody/.svg)."""
    file = pathlib.Path(file)
    if file.suffix == ".py":
        return run_script(file)[0]
    text = re.sub(r"<!--.*?-->", "", file.read_text(), flags=re.S).strip()
    m = re.search(r"<svg[^>]*>(.*)</svg>", text, re.S)
    return (m.group(1) if m else text).strip()


def depicts(script):
    """The first line of an icon script's docstring, after 'name: '."""
    text = pathlib.Path(script).read_text()
    m = re.search(r'"""\s*[a-z0-9_-]+:\s*(.*?)(?:\n|""")', text)
    return m.group(1).strip() if m else ""


# --- where things live ----------------------------------------------------------------
HOME = pathlib.Path.home()
CONF = HOME / ".config/omarchy/desktop.conf"
BUILTIN_JS = HOME / ".config/omarchy/bar/modules/taskbar-icons.js"
USER_JSON = HOME / ".config/omarchy/taskbar-icons.json"
USER_SRC = HOME / ".config/omarchy/taskbar-icons-src"


def conf_value(key):
    try:
        for line in CONF.read_text().split("\n"):
            if line.startswith(key + "="):
                return line.split("=", 1)[1]
    except OSError:
        pass
    return ""


def maintainer():
    return conf_value("maintainer") == "on" and bool(conf_value("repo"))


def source_dir(user=False):
    """Where icon scripts live: the desktop repo's icon-src/icons (maintainer:
    the built-in set) or ~/.config/omarchy/taskbar-icons-src/icons (yours)."""
    if maintainer() and not user:
        return pathlib.Path(conf_value("repo")) / "icon-src" / "icons"
    return USER_SRC / "icons"


def drafts_dir(user=False):
    if maintainer() and not user:
        return pathlib.Path(conf_value("repo")) / "icon-src" / "drafts"
    return USER_SRC / "drafts"


# --- turning a bare body into a script --------------------------------------------------
def to_script(name, what, b):
    """An icon script that draws body `b` with iconkit calls (for hand-drawn
    bodies and old drawings)."""
    calls = []
    for el in re.findall(r"<[a-z]+\b[^>]*/>", b):
        tag = re.match(r"<([a-z]+)", el).group(1)
        at = dict(re.findall(r'\s([a-zA-Z-]+)="([^"]*)"', el))
        filled = at.get("fill") == "%C" and at.get("stroke") == "none"
        g = lambda k: at.get(k, "0")
        if tag == "path" and set(at) <= {"d"}:
            calls.append(f'path("{at["d"]}")')
        elif tag == "path" and filled and set(at) <= {"d", "fill", "stroke"}:
            calls.append(f'solid("{at["d"]}")')
        elif tag == "circle" and filled and set(at) <= {"cx", "cy", "r", "fill", "stroke"}:
            calls.append(f"dot({g('cx')}, {g('cy')}, {g('r')})")
        elif tag == "circle" and set(at) <= {"cx", "cy", "r"}:
            calls.append(f"circle({g('cx')}, {g('cy')}, {g('r')})")
        elif tag == "ellipse" and set(at) <= {"cx", "cy", "rx", "ry"}:
            calls.append(f"ellipse({g('cx')}, {g('cy')}, {g('rx')}, {g('ry')})")
        elif tag == "rect" and set(at) <= {"x", "y", "width", "height", "rx"}:
            rx = f", rx={at['rx']}" if "rx" in at else ""
            calls.append(f"rect({g('x')}, {g('y')}, {g('width')}, {g('height')}{rx})")
        else:
            raise ValueError(f"{name}: can't express {el} with iconkit (it breaks the spec)")
    lines = ",\n".join(f"    {c}" for c in calls)
    return f'"""{name}: {what}"""\nfrom iconkit import *\n\nicon(\n{lines},\n)\n'
