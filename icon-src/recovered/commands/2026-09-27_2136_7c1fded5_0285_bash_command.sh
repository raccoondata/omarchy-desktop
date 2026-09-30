d=~/.claude/skills/taskbar-icons/scripts; f=~/.config/omarchy/bar/modules/taskbar-icons.js; S=/tmp/claude-1000/skilltest; mkdir -p $S; cp $f $S/icons.before
echo "--- list"; $d/icon-set --list | wc -w
echo "--- replace steam with identical body (should leave file unchanged)"; node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8").replace(".pragma library",""); const icons=new Function(s+"; return icons")(); require("fs").writeFileSync(process.argv[2], icons.steam)' $f $S/steam.txt; $d/icon-set steam $S/steam.txt; cmp -s $f $S/icons.before && echo "unchanged: ok"
echo "--- guard: hardcoded colour"; echo '<path d="M1 1" stroke="#fff"/>' > $S/bad.txt; $d/icon-set zzbad $S/bad.txt; echo "exit=$?"
echo "--- guard: broken body is escaped, so add+parse works; then remove it by restoring"; echo '<path d="M4 4h16"/>' > $S/ok.txt; $d/icon-set zztest $S/ok.txt; grep -c '"zztest"' $f; cp $S/icons.before $f; cmp -s $f $S/icons.before && echo "restored: ok"
echo "--- preview"; $d/icon-preview $S/prev.png $S/steam.txt $S/ok.txt
