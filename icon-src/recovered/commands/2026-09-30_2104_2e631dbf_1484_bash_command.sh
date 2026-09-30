cd ~/.claude/skills/taskbar-icons/scripts && python3 - <<'PYEOF'
p='iconkit.py'
s=open(p).read()
old='''def rotate(points, deg, cx=12, cy=12):'''
new='''def adjust_pt(x, y, dx=0.0, dy=0.0, scale=1.0, cx=12, cy=12):
    """A point moved and scaled like adjust() moves path data."""
    return (cx + (x - cx) * scale + dx, cy + (y - cy) * scale + dy)


def rotate(points, deg, cx=12, cy=12):'''
assert old in s; s=s.replace(old,new,1)
open(p,'w').write(s)
PYEOF
cd ~/Projects/personal/omarchy-desktop/icon-src/icons && mkdir -p /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/before && cp discord.icon.py openclaw.icon.py neovim.icon.py youtube.icon.py /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/before/ && cat > discord.icon.py <<'EOF'
"""discord: Discord: the game-controller face, with two eyes."""
from iconkit import *

# Drawn 1.7 low and a hair wider than the live area: lifted and scaled to 98%.
FIX = dict(dy=-1.65, scale=0.98)

icon(
    path(adjust("M8.7 7.2c-1.6.3-3 .9-4.3 1.7-1.4 3-1.8 6-1.4 9 1.4 1.1 3 1.8 4.6 2.2l1.1-1.8M15.3 7.2c1.6.3 3 .9 4.3 1.7 1.4 3 1.8 6 1.4 9-1.4 1.1-3 1.8-4.6 2.2l-1.1-1.8M7.6 16.9c2.9 1.3 5.9 1.3 8.8 0M8.6 8.7c2.3-.6 4.5-.6 6.8 0", **FIX)),
    dot(*adjust_pt(9.4, 13.2, **FIX), 1.15),
    dot(*adjust_pt(14.6, 13.2, **FIX), 1.15),
)
EOF
cat > openclaw.icon.py <<'EOF'
"""openclaw: OpenClaw: a curled claw."""
from iconkit import *

# Drawn 1.6 right of centre: moved back.
icon(
    path(adjust("M7 20.2C6.2 15.6 6.8 11.4 9.4 8.2C11.8 5.4 15.4 4 19.4 4.4C17.6 6 16.4 7.6 15.8 9.6C17.6 9.2 19.4 9.6 20.6 10.6C18.4 13 15.2 14 12.2 13.4C10.8 15.4 10.2 17.6 10.4 20.2", dx=-1.6)),
)
EOF
cat > neovim.icon.py <<'EOF'
"""neovim: Neovim: the N stroke."""
from iconkit import *

# A bare letter reads small next to framed icons: drawn 15% larger.
icon(
    path(adjust("M7 18V6l10 12V6", scale=1.15)),
)
EOF
cat > youtube.icon.py <<'EOF'
"""youtube: YouTube: the rounded play button (a wide rounded rectangle with a triangle)."""
from iconkit import *

icon(
    rect(3, 5.5, 18, 13, rx=4),
    path("M10.2 9.4l4.6 2.6-4.6 2.6z"),
)
EOF
S=~/.claude/skills/taskbar-icons/scripts; $S/icon-lint discord.icon.py openclaw.icon.py neovim.icon.py youtube.icon.py chatgpt.icon.py; B=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/before; $S/icon-preview /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/fix.png $B/youtube.icon.py youtube.icon.py $B/discord.icon.py discord.icon.py $B/openclaw.icon.py openclaw.icon.py $B/neovim.icon.py neovim.icon.py 2>&1 | tail -1
