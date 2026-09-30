cd /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad; python3 - <<'EOF'
import math
def pt(cx,cy,r,a): return (cx+r*math.cos(math.radians(a)), cy+r*math.sin(math.radians(a)))
def arc(cx,cy,r,a0,a1):
    x0,y0=pt(cx,cy,r,a0); x1,y1=pt(cx,cy,r,a1)
    large=1 if (a1-a0)%360>180 else 0
    return f'<path d="M{x0:.2f} {y0:.2f}A{r} {r} 0 {large} 1 {x1:.2f} {y1:.2f}"/>'
variants={
 'i-rust3.svg':(arc(12,12,7.8,152,298),arc(12,12,7.8,332,118)),
 'i-rust4.svg':(arc(11.4,12.6,7.6,150,300),arc(12.6,11.4,7.6,330,120)),
 'i-rust5.svg':(arc(11.3,11.3,7.4,150,300),arc(12.7,12.7,7.4,330,120)),
}
for f,(a,b) in variants.items(): open(f,'w').write(a+b+"\n")
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview prev2.png i-rust2.svg i-rust3.svg i-rust4.svg i-rust5.svg
