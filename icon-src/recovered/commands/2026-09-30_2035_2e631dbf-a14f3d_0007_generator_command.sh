cd /tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/d/
python3 - <<'EOF'
import math
r=8.3; half=12  # degrees half-arc
parts=[]
for k in range(8):
    c=k*45
    a0=math.radians(c-half); a1=math.radians(c+half)
    x0=12+r*math.cos(a0); y0=12+r*math.sin(a0); x1=12+r*math.cos(a1); y1=12+r*math.sin(a1)
    parts.append(f"M{x0:.2f} {y0:.2f}A{r} {r} 0 0 1 {x1:.2f} {y1:.2f}")
open("localsend.svgbody","w").write(f'<path d="{"".join(parts)}"/><circle cx="12" cy="12" r="3.6" fill="%C" stroke="none"/>')
EOF
cat > bluetui.svgbody <<'EOF'
<path d="M7 7.5l10 9L12 21V3l5 4.5-10 9"/>
EOF
cat > fastfetch.svgbody <<'EOF'
<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5"/><circle cx="12" cy="7.9" r="1.05" fill="%C" stroke="none"/>
EOF
cat > fastfetch2.svgbody <<'EOF'
<rect x="3" y="4.5" width="18" height="15" rx="3"/><circle cx="8.5" cy="10.5" r="2.2"/><path d="M13 9h4.5M13 12h4.5M7 15.5h10.5"/>
EOF
cat > lazygit.svgbody <<'EOF'
<rect x="3" y="4.5" width="18" height="15" rx="3"/><circle cx="8.3" cy="8.8" r="1.3" fill="%C" stroke="none"/><circle cx="8.3" cy="15.2" r="1.3" fill="%C" stroke="none"/><circle cx="15.7" cy="9.6" r="1.3" fill="%C" stroke="none"/><path d="M8.3 8.8v6.4M15.7 9.6c0 3-3.8 2.6-7.4 5.6"/>
EOF
cat > lazydocker.svgbody <<'EOF'
<rect x="3" y="4.5" width="18" height="15" rx="3"/><rect x="6.3" y="12" width="3" height="3.5" rx=".5"/><rect x="10.5" y="12" width="3" height="3.5" rx=".5"/><rect x="14.7" y="12" width="3" height="3.5" rx=".5"/><rect x="10.5" y="7.7" width="3" height="3" rx=".5"/>
EOF
cat > aether.svgbody <<'EOF'
<path d="M5.5 20L12 4l6.5 16"/><path d="M3.5 14.8c2.7-1.9 5.2-.2 8.5-.9s5.3-2.6 8.5-.9"/>
EOF
cat > omacalc.svgbody <<'EOF'
<rect x="5.5" y="3" width="13" height="18" rx="2.5"/><path d="M8.5 7h7"/><circle cx="9" cy="11.5" r=".95" fill="%C" stroke="none"/><circle cx="12" cy="11.5" r=".95" fill="%C" stroke="none"/><circle cx="15" cy="11.5" r=".95" fill="%C" stroke="none"/><circle cx="9" cy="14.5" r=".95" fill="%C" stroke="none"/><circle cx="12" cy="14.5" r=".95" fill="%C" stroke="none"/><circle cx="15" cy="14.5" r=".95" fill="%C" stroke="none"/><circle cx="9" cy="17.5" r=".95" fill="%C" stroke="none"/><path d="M12 17.5h3"/>
EOF
cat > github.svgbody <<'EOF'
<path d="M9 19c-4.3 1.4-4.3-2.5-6-3m12 5v-3.5c0-1 .1-1.4-.5-2 2.8-.3 5.5-1.4 5.5-6a4.6 4.6 0 0 0-1.3-3.2 4.2 4.2 0 0 0-.1-3.2s-1.1-.3-3.5 1.3a12.3 12.3 0 0 0-6.2 0C6.5 2.8 5.4 3.1 5.4 3.1a4.2 4.2 0 0 0-.1 3.2A4.6 4.6 0 0 0 4 9.5c0 4.6 2.7 5.7 5.5 6-.6.6-.6 1.2-.5 2V21"/>
EOF
cat > network.svgbody <<'EOF'
<circle cx="12" cy="12" r="2.3"/><circle cx="12" cy="4.8" r="1.8"/><circle cx="5.5" cy="17.2" r="1.8"/><circle cx="18.5" cy="17.2" r="1.8"/><path d="M12 6.6v3.1M7.1 16.1l2.9-2.2M16.9 16.1l-2.9-2.2"/>
EOF
cat > network2.svgbody <<'EOF'
<circle cx="12" cy="5.5" r="2.2"/><circle cx="5.5" cy="17.5" r="2.2"/><circle cx="18.5" cy="17.5" r="2.2"/><path d="M10.9 7.5L6.6 15.5M13.1 7.5l4.3 8M7.7 17.5h8.6"/>
EOF
P=~/.claude/skills/taskbar-icons/scripts/icon-preview
$P p1.png bluetui.svgbody fastfetch.svgbody fastfetch2.svgbody lazygit.svgbody lazydocker.svgbody aether.svgbody
$P p2.png localsend.svgbody omacalc.svgbody github.svgbody network.svgbody network2.svgbody
