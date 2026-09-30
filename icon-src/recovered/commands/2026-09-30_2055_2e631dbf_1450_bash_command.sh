python3 - <<'PYEOF'
import json
f='~/.claude/projects/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc.jsonl'
for line in open(f):
    r=json.loads(line); m=r.get('message') or {}
    if r.get('type')=='assistant' and isinstance(m.get('content'),list):
        for b in m['content']:
            if b.get('type')=='tool_use' and b['name'] in ('Bash','Write'):
                t=json.dumps(b['input'])
                if 'gemini' in t and ('<path' in t or '<circle' in t or 'svgbody' in t):
                    i=b['input']; print(r.get('timestamp','')[:16], b['name'], (i.get('command') or i.get('file_path'))[:400].replace('\n',' | ')); print('---')
PYEOF
