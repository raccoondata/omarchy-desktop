O=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/sheet; mkdir -p $O; cd $O; python3 - <<'PYEOF'
import json,re,os,sys
sys.path.insert(0,os.path.expanduser('~/.claude/skills/taskbar-icons/scripts'))
from iconkit import wrap
js=open(os.path.expanduser('~/.config/omarchy/bar/modules/taskbar-icons.js')).read()
icons=[(json.loads(a),json.loads(b)) for a,b in re.findall(r'^  ("[a-z0-9_-]+"): (".*"),?$',js,re.M)]
old=icons[:56]
cells=[]
for i,(n,b) in enumerate(old):
    c,r=i%8,i//8; x,y=10+c*110,10+r*100
    inner=wrap(b,'#f6dcac').replace('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"',f'<svg x="{x+25}" y="{y}" width="60" height="60" viewBox="0 0 24 24"')
    cells.append(inner+f'<text x="{x+55}" y="{y+80}" font-family="monospace" font-size="13" fill="#f6dcac" text-anchor="middle">{n}</text>')
open('s.svg','w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="900" height="{10+7*100}"><rect width="100%" height="100%" fill="#031222"/>{"".join(cells)}</svg>')
print([n for n,_ in old])
PYEOF
rsvg-convert s.svg -o s.png && echo ok
