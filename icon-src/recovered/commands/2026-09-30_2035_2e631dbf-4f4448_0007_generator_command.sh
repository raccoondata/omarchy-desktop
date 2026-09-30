cd /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/c/
cat > keyboard2.svgbody <<'E'
<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="M8.5 15.2h7"/><circle cx="7" cy="9" r="0.95" fill="%C" stroke="none"/><circle cx="10.3" cy="9" r="0.95" fill="%C" stroke="none"/><circle cx="13.7" cy="9" r="0.95" fill="%C" stroke="none"/><circle cx="17" cy="9" r="0.95" fill="%C" stroke="none"/><circle cx="8.6" cy="12" r="0.95" fill="%C" stroke="none"/><circle cx="12" cy="12" r="0.95" fill="%C" stroke="none"/><circle cx="15.4" cy="12" r="0.95" fill="%C" stroke="none"/>
E
cat > uuctl2.svgbody <<'E'
<path d="M7 4.5H4v15h3M17 4.5h3v15h-3"/><circle cx="8.8" cy="12" r="1.7" fill="%C" stroke="none"/><path d="M13 8.8l3.4 3.2-3.4 3.2z" fill="%C"/>
E
python3 - <<'P' > uuctl3.svgbody
import math
cx=cy=12; n=8; ro=8.6; ri=6.4
pts=[]
for i in range(n):
    a=2*math.pi*i/n
    hw_o=0.20; hw_i=0.30
    for ang,r in [(a-hw_i,ri),(a-hw_o,ro),(a+hw_o,ro),(a+hw_i,ri)]:
        pts.append((cx+r*math.cos(ang),cy+r*math.sin(ang)))
d="M"+"L".join(f"{x:.2f} {y:.2f}" for x,y in pts)+"Z"
print(f'<path d="{d}"/><circle cx="12" cy="12" r="2.6"/>')
P
S=~/.claude/skills/taskbar-icons/scripts/icon-preview
$S p3.png keyboard.svgbody keyboard2.svgbody disks.svgbody uuctl.svgbody uuctl2.svgbody uuctl3.svgbody
