d=~/.claude/skills/taskbar-icons; chmod +x $d/scripts/*; python3 - <<'PYEOF'
import pathlib
p = pathlib.Path.home() / ".claude/skills/taskbar-icons/SKILL.md"; s = p.read_text()
s = s.replace("`scripts/icon-preview <body-file> <out.png>` and Read the PNG. When unsure,\n   draw two or three options and preview them together (pass several body\n   files).",
              "`scripts/icon-preview <out.png> <body-file>` and Read the PNG. When unsure,\n   draw two or three options and preview them together (pass several body\n   files; one row each).")
s = s.replace("`scripts/icon-test <class> [<class>...]`. It opens\n   a dummy window per class, screenshots the bar to the given path,",
              "`scripts/icon-test <out.png> <class> [<class>...]`. It opens\n   a dummy window per class, screenshots the bar to `<out.png>`,")
s = s.replace("## Workflow\n", "## Workflow\n\nScripts live in `~/.claude/skills/taskbar-icons/scripts/`.\n")
p.write_text(s)
PYEOF
grep -n 'icon-preview <\|icon-test <\|Scripts live' $d/SKILL.md
