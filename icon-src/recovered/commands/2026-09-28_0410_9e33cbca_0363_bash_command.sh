f=~/.claude/skills/taskbar-icons/scripts/icon-preview; python3 - "$f" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
rep=[
('''# Render icon drafts for review, one row per body file:
#   large | real taskbar size (18px, enlarged 6x) inactive | same, accent
# Colours come from the current Omarchy theme.
#   icon-preview <out.png> <body-file> [<body-file> ...]''','''# Render icon drafts for review, one row per body file:
#   large | real taskbar size (enlarged) inactive | same, accent
# Real size is 23px: taskbar.qml draws icons at 55% of the bar, and the bar is
# 42px ([bar] size-horizontal = 36 at base-size 14). ICON_PX overrides it.
# Colours come from the current Omarchy theme.
#   icon-preview <out.png> <body-file> [<body-file> ...]'''),
('''work="$(mktemp -d)"''','''px="${ICON_PX:-23}"
work="$(mktemp -d)"'''),
('''    rsvg-convert -w 18 -h 18 -b "$bg" "$work/$n-$variant.svg" -o "$work/$n-$variant-18.png"
    magick "$work/$n-$variant-18.png" -filter point -resize 600% "$work/$n-$variant-x6.png"''','''    rsvg-convert -w "$px" -h "$px" -b "$bg" "$work/$n-$variant.svg" -o "$work/$n-$variant-real.png"
    magick "$work/$n-$variant-real.png" -filter point -resize 500% "$work/$n-$variant-x6.png"'''),
('''echo "wrote $out ($n row(s): large | 18px inactive | 18px accent)"''','''echo "wrote $out ($n row(s): large | ${px}px inactive | ${px}px accent)"'''),
]
for a,b in rep:
    assert a in s, a[:50]; s=s.replace(a,b,1)
open(p,'w').write(s)
PY
bash -n "$f" && echo "script ok"
sed -i 's/legible at the real taskbar size (about 18px)/legible at the real taskbar size (about 23px: 55% of the 42px bar)/' ~/.claude/skills/taskbar-icons/SKILL.md; grep -n '23px' ~/.claude/skills/taskbar-icons/SKILL.md
S=/tmp/claude-1000/-home-user-Work/9e33cbca-f705-4147-928b-bb34b1860cb1/scratchpad; cd $S && ~/.claude/skills/taskbar-icons/scripts/icon-preview ytm3.png ytm-a.svg ytm-f1.svg ytm-f2.svg ytm-f3.svg play-existing.svg
