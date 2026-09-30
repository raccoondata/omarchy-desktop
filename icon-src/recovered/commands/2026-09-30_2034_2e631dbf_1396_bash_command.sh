cd ~/.config/omarchy/bar/modules && python3 - <<'PYEOF'
p='taskbar-icons.js'
s=open(p).read()
old='''function svg(name, color) {'''
new='''// Your own icons (~/.config/omarchy/taskbar-icons.json "icons", loaded by
// taskbar.qml): added to the set, replacing a built-in one of the same name.
function addIcons(map) {
  for (var name in map) {
    if (typeof map[name] === "string" && map[name].indexOf("<") !== -1) icons[name] = map[name]
  }
}

function svg(name, color) {'''
assert old in s; s=s.replace(old,new,1)
open(p,'w').write(s)

p='taskbar.qml'
s=open(p).read()
old='''  readonly property var classIcons: ['''
new='''  // Your own icons and which windows get them, kept apart from the built-in
  // set so updates don't touch them (the taskbar-icons skill's icon-set
  // writes it): ~/.config/omarchy/taskbar-icons.json
  //   {"icons": {"name": "<svg body>"}, "programs": {"htop": "name"},
  //    "classes": [["^regex$", "name"]]}
  // Checked before the built-in rules. Read once at startup: restart the
  // shell after changing it.
  property var userPrograms: ({})
  property var userClasses: []
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/taskbar-icons.json"
    blockLoading: true
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text()) || {}
        if (data.icons) TaskbarIcons.addIcons(data.icons)
        root.userPrograms = data.programs || {}
        root.userClasses = (data.classes || []).map(function(c) {
          try { return [new RegExp(c[0], "i"), String(c[1])] } catch (e) { return null }
        }).filter(function(c) { return c !== null })
      } catch (e) { }
    }
  }

  readonly property var classIcons: ['''
assert old in s; s=s.replace(old,new,1)
old='''    var program = programByAddress[address]
    if (program && programIcons[program]) return programIcons[program]
    for (var i = 0; i < classIcons.length; i++) {'''
new='''    var program = programByAddress[address]
    if (program && userPrograms[program]) return userPrograms[program]
    for (var u = 0; u < userClasses.length; u++) {
      if (userClasses[u][0].test(windowClass)) return userClasses[u][1]
    }
    if (program && programIcons[program]) return programIcons[program]
    for (var i = 0; i < classIcons.length; i++) {'''
assert old in s; s=s.replace(old,new,1)
open(p,'w').write(s)
PYEOF
grep -n 'import "taskbar-icons.js"\|^import' taskbar.qml | head
