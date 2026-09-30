import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Taskbar settings window: Super+Space > Setup > Taskbar, or a taskbar icon's
// right-click menu. Built from Omarchy's own controls (toggles, button groups,
// sliders, dropdowns) and drawn like its menu. Every change applies at once:
//
//   taskbar options   ~/.config/omarchy/taskbar-setting (the taskbar's entry
//                     in shell.json, which the bar reloads by itself)
//   bar height        ~/.config/omarchy/bar-height (Omarchy's shell.toml)
//   hot corners       ~/.config/omarchy/hotcorner (hotcorners.conf)
//   title bars        ~/.config/omarchy/titlebars, taskbar-action titlebar
//   mouse             ~/.config/omarchy/mouse-setting (hypr/mouse.lua)
Item {
  id: settings

  required property var taskbar
  property bool opened: false
  property string tab: "taskbar"

  readonly property string dir: taskbar.omarchyDir
  readonly property int columnGap: Style.space(28)
  readonly property int cardWidth: Style.space(960)

  function open(which) {
    // Older names (menu entries, keybindings) for what's now inside another tab.
    var moved = { corners: "desktop", effects: "desktop", mouse: "desktop", titlebars: "windows" }
    tab = which && which.length > 0 ? (moved[which] || which) : "taskbar"
    barHeightRead.running = true
    scrollRead.running = true
    terminalScrollRead.running = true
    editorsProc.running = true
    taskbar.reloadAgents()
    cornersFile.reload()
    opened = true
  }

  function close() { opened = false }

  function set(key, value) {
    Util.execArgv([dir + "/taskbar-setting", "set", key, String(value)])
  }
  // Several settings in one write (one click that changes two keys; two
  // separate writes could undo each other).
  function setMany(pairs) {
    var args = [dir + "/taskbar-setting", "set"]
    for (var k in pairs) args.push(k, String(pairs[k]))
    Util.execArgv(args)
  }

  // ------------------------------------------------------- outside state

  property int barHeight: 36
  Process {
    id: barHeightRead
    command: [settings.dir + "/bar-height", "get"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: settings.barHeight = Number(text.trim()) || 36
    }
  }

  property real scrollFactor: 1
  Process {
    id: scrollRead
    command: [settings.dir + "/mouse-setting", "scroll"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: settings.scrollFactor = Number(text.trim()) || 1
    }
  }

  property real terminalScroll: 3
  Process {
    id: terminalScrollRead
    command: [settings.dir + "/mouse-setting", "terminal"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: settings.terminalScroll = Number(text.trim()) || 3
    }
  }

  function setTerminalScroll(v) {
    terminalScroll = Math.round(v * 4) / 4
    Util.execArgv([dir + "/mouse-setting", "terminal", String(terminalScroll)])
  }

  property var corners: ({})
  FileView {
    id: cornersFile
    path: settings.dir + "/hotcorners.conf"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var map = {}
      var lines = text().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^([a-z-]+)=(\S+)/)
        if (m) map[m[1]] = m[2]
      }
      settings.corners = map
    }
  }

  function setCorner(corner, action) {
    var next = Object.assign({}, corners)
    next[corner] = action
    corners = next
    Util.execArgv([dir + "/hotcorner", "set", corner, action])
  }

  function setRipple(on) {
    var next = Object.assign({}, corners)
    next.effect = on ? "on" : "off"
    corners = next
    Util.execArgv([dir + "/hotcorner", "effect", on ? "on" : "off"])
  }

  property bool titlebarsOn: true
  FileView {
    path: settings.dir + "/titlebars-off"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: settings.titlebarsOn = false
    onLoadFailed: settings.titlebarsOn = true
  }

  readonly property var cornerActions: [
    { value: "none", label: "Nothing" },
    { value: "desktop", label: "Show desktop" },
    { value: "minimize", label: "Minimize all" },
    { value: "restore", label: "Restore all" },
    { value: "switcher", label: "Window switcher" },
    { value: "menu", label: "Omarchy menu" },
    { value: "lock", label: "Lock screen" }
  ]

  // ------------------------------------------------------------------ ui

  // A label (and a quieter line under it) on the left, a control on the right.
  component SettingRow: Item {
    id: row
    property string label: ""
    property string description: ""
    default property alias control: slot.data

    width: parent ? parent.width : 0
    height: Math.max(texts.implicitHeight, slot.childrenRect.height) + Style.space(10)

    Column {
      id: texts
      anchors.left: parent.left
      anchors.right: slot.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: row.label
        color: Color.menu.text
        elide: Text.ElideRight
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }
      Text {
        visible: row.description !== ""
        width: parent.width
        text: row.description
        color: Color.menu.text
        opacity: 0.5
        wrapMode: Text.WordWrap
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }
    }

    Item {
      id: slot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  // A small section title with a hairline under it.
  component Section: Column {
    property string title: ""
    width: parent ? parent.width : 0
    spacing: Style.space(4)

    Text {
      text: parent.title.toUpperCase()
      color: Color.menu.text
      opacity: 0.45
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }
    Rectangle { width: parent.width; height: 1; color: Color.menu.text; opacity: 0.1 }
  }

  // A slider with its value shown beside it; writes on release.
  component ValueSlider: Row {
    id: vs
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    property bool integer: false
    property string suffix: ""
    property real scaleShown: 1
    property int decimals: 0
    property real live: value
    signal committed(real value)

    spacing: Style.space(10)
    onValueChanged: live = value

    PanelSlider {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(170)
      height: Style.space(22)
      value: vs.value
      minimum: vs.minimum
      maximum: vs.maximum
      step: vs.step
      integer: vs.integer
      trackColor: Util.alpha(Color.menu.text, 0.15)
      fillColor: Color.accent
      knobColor: Color.menu.text
      onMoved: function(v) { vs.live = v }
      onReleased: function(v) { vs.committed(v) }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(46)
      horizontalAlignment: Text.AlignRight
      text: (vs.decimals > 0 ? (vs.live * vs.scaleShown).toFixed(vs.decimals) : Math.round(vs.live * vs.scaleShown)) + vs.suffix
      color: Color.menu.text
      opacity: 0.7
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  PanelWindow {
    id: panel

    screen: settings.taskbar.QsWindow.window ? settings.taskbar.QsWindow.window.screen : null
    visible: settings.opened
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-taskbar-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: settings.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: settings.close()
    }

    BorderSurface {
      id: card

      width: settings.cardWidth + contentLeftInset + contentRightInset
      height: body.implicitHeight + contentTopInset + contentBottomInset
      // A fixed top, so switching tabs (different heights) doesn't make it jump.
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.16)
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        anchors.fill: parent
        focus: settings.opened
        Keys.onEscapePressed: settings.close()
      }

      Column {
        id: body
        x: card.contentLeftInset
        y: card.contentTopInset
        width: settings.cardWidth
        spacing: Style.space(14)

        // Header: title and close, then the tabs on a row of their own (the
        // tabs outgrew the space beside the title).
        Item {
          width: parent.width
          height: title.implicitHeight

          Column {
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Taskbar & Desktop"
              color: Color.menu.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
            }
            Text {
              text: "Changes apply as you go"
              color: Color.menu.text
              opacity: 0.45
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
            }
          }

          Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: ""
            foreground: Color.menu.text
            fontFamily: Style.font.menuFamily
            onClicked: settings.close()
          }
        }

        ButtonGroup {
          id: tabs
          options: [
            { value: "taskbar", label: "Taskbar" },
            { value: "windows", label: "Windows" },
            { value: "desktop", label: "Desktop" },
            { value: "icons", label: "Icons" },
            { value: "nowplaying", label: "Now Playing" },
            { value: "visualizers", label: "Equalizer" },
            { value: "screenshots", label: "Screenshots" },
            { value: "agents", label: "Agents" }
          ]
          value: settings.tab
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          onChanged: function(v) { settings.tab = v }
        }

        Rectangle { width: parent.width; height: 1; color: Color.menu.text; opacity: 0.12 }

        // The tab's content, scrolling when it's taller than the screen allows.
        Flickable {
          width: parent.width
          height: Math.min(tabContent.height, Math.max(Style.space(200), Screen.height * 0.72))
          contentWidth: width
          contentHeight: tabContent.height
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
        Loader {
          id: tabContent
          width: parent.width
          sourceComponent: settings.tab === "desktop" ? desktopTab
            : settings.tab === "windows" ? windowsPage
            : settings.tab === "nowplaying" ? nowPlayingTab
            : settings.tab === "agents" ? agentsTab
            : settings.tab === "screenshots" ? screenshotsTab
            : settings.tab === "icons" ? iconsTab
            : settings.tab === "visualizers" ? visualizersTab
            : taskbarTab
        }
        }
      }
    }
  }

  // ---------------------------------------------------------------- tabs

  // Desktop: the bar's size, hot corners, motion and the mouse, gathered from
  // what were small tabs of their own.
  Component {
    id: desktopTab

    Column {
      width: settings.cardWidth
      spacing: Style.space(16)

      Column {
        width: (settings.cardWidth - settings.columnGap) / 2
        spacing: Style.space(6)
        Section { title: "Bar" }
        SettingRow {
          label: "Bar height"
          description: "the whole Omarchy bar"
          ValueSlider {
            value: settings.barHeight
            minimum: 28; maximum: 56; step: 1; integer: true
            suffix: " px"
            onCommitted: function(v) {
              settings.barHeight = Math.round(v)
              Util.execArgv([settings.dir + "/bar-height", "set", String(Math.round(v))])
            }
          }
        }
      }
      Loader { width: parent.width; sourceComponent: cornersTab }
      Loader { width: parent.width; sourceComponent: effectsTab }
      Loader { width: parent.width; sourceComponent: mouseTab }
    }
  }

  // Windows: placing them, apps that come to you, and title bars.
  Component {
    id: windowsPage

    Column {
      width: settings.cardWidth
      spacing: Style.space(16)
      Loader { width: parent.width; sourceComponent: windowsTab }
      Loader { width: parent.width; sourceComponent: titlebarsTab }
    }
  }

  Component {
    id: taskbarTab

    Row {
      id: tbTab
      spacing: settings.columnGap
      readonly property var prefs: settings.taskbar.prefs || ({})
      function pick(key, fallback) { var v = prefs[key]; return v === undefined || v === null ? fallback : String(v) }
      readonly property real columnWidth: (settings.cardWidth - settings.columnGap) / 2

      Column {
        width: parent.columnWidth
        spacing: Style.space(6)

        Section { title: "Appearance" }

        SettingRow {
          label: "Icon size"
          ValueSlider {
            value: settings.taskbar.iconScale
            minimum: 0.4; maximum: 0.75; step: 0.05
            scaleShown: 100; suffix: "%"
            onCommitted: function(v) { settings.set("iconScale", v.toFixed(2)) }
          }
        }
        SettingRow {
          label: "Icon spacing"
          ValueSlider {
            value: settings.taskbar.iconSpacing
            minimum: 0; maximum: 12; step: 1; integer: true
            suffix: " px"
            onCommitted: function(v) { settings.set("iconSpacing", Math.round(v)) }
          }
        }
        SettingRow {
          label: "Window titles"
          description: "each window's title beside its icon"
          ToggleSwitch {
            checked: settings.taskbar.showLabels
            onToggled: settings.set("showLabels", !checked)
          }
        }

        Item { width: 1; height: Style.space(6) }
        Section { title: "Indicators" }

        SettingRow {
          label: "Window dots"
          description: "one per window under the icon"
          ToggleSwitch { checked: settings.taskbar.showDots; onToggled: settings.set("showDots", !checked) }
        }
        SettingRow {
          label: "Unread badges"
          ToggleSwitch { checked: settings.taskbar.showBadges; onToggled: settings.set("showBadges", !checked) }
        }
        SettingRow {
          label: "Attention flash"
          description: "when a window wants you"
          ToggleSwitch { checked: settings.taskbar.flashAttention; onToggled: settings.set("flashAttention", !checked) }
        }
        SettingRow {
          label: "Workspace hints"
          description: "hovering an icon marks its workspaces"
          ToggleSwitch { checked: settings.taskbar.hoverWorkspacesEnabled; onToggled: settings.set("hoverWorkspaces", !checked) }
        }
      }

      Column {
        width: parent.columnWidth
        spacing: Style.space(6)

        Section { title: "Behavior" }

        SettingRow {
          label: "Group windows by app"
          description: "off: every window gets its own icon"
          ToggleSwitch { checked: settings.taskbar.groupWindows; onToggled: settings.set("groupWindows", !checked) }
        }
        SettingRow {
          label: "Clicking a group"
          description: settings.taskbar.groupClick === "previews" ? "always show its windows"
            : settings.taskbar.groupClick === "recent" ? "go to the window used last"
            : "one workspace: go there; spread out: show its windows"
          ButtonGroup {
            options: [{ value: "smart", label: "Smart" }, { value: "previews", label: "Previews" }, { value: "recent", label: "Last used" }]
            value: settings.taskbar.groupClick
            foreground: Color.menu.text
            background: Color.menu.background
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { settings.set("groupClick", v) }
          }
        }
        SettingRow {
          label: "Scroll to switch windows"
          description: "scrolling over an icon steps through its windows"
          ToggleSwitch { checked: settings.taskbar.scrollCycles; onToggled: settings.set("scrollCycle", !checked) }
        }


        SettingRow {
          label: "Double-click a group"
          description: tbTab.pick("doubleClickGroup", "tile") === "here" ? "brings all its windows to the workspace you're on"
            : tbTab.pick("doubleClickGroup", "tile") === "none" ? "does nothing extra"
            : "gives its windows a workspace of their own and takes you there"
          ButtonGroup {
            options: [{ value: "tile", label: "Own workspace" }, { value: "here", label: "Bring here" }, { value: "none", label: "Nothing" }]
            value: tbTab.pick("doubleClickGroup", "tile")
            foreground: Color.menu.text
            background: Color.menu.background
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { settings.set("doubleClickGroup", v) }
          }
        }
        SettingRow {
          label: "Double-click a single window"
          description: "maximize or restore it"
          ButtonGroup {
            options: [{ value: "maximize", label: "Maximize" }, { value: "none", label: "Nothing" }]
            value: tbTab.pick("doubleClickWindow", "maximize")
            foreground: Color.menu.text
            background: Color.menu.background
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { settings.set("doubleClickWindow", v) }
          }
        }
        SettingRow {
          label: "Clicking the app you're in"
          description: "minimize it, like Windows (click again to bring it back)"
          ToggleSwitch {
            checked: tbTab.pick("clickActive", "none") === "minimize"
            onToggled: settings.set("clickActive", checked ? "none" : "minimize")
          }
        }
      }

      Column {
        width: tbTab.columnWidth
        spacing: Style.space(6)
        SettingRow {
          label: "Icon order"
          description: "forget where you've dragged icons"
          Button {
            text: "Reset"
            bordered: true
            foreground: Color.menu.text
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onClicked: Util.execArgv(["rm", "-f", settings.dir + "/taskbar-order.json"])
          }
        }
        Item { width: 1; height: Style.space(6) }
        Section { title: "Hover previews" }

        SettingRow {
          label: "Show previews"
          description: "live thumbnails when you rest on an icon"
          ToggleSwitch { checked: settings.taskbar.hoverPreviewsEnabled; onToggled: settings.set("hoverPreviews", !checked) }
        }
        SettingRow {
          label: "Delay"
          ValueSlider {
            value: settings.taskbar.hoverDelay
            minimum: 150; maximum: 1200; step: 50; integer: true
            suffix: " ms"
            onCommitted: function(v) { settings.set("hoverDelay", Math.round(v)) }
          }
        }
        SettingRow {
          label: "Thumbnail size"
          ValueSlider {
            value: settings.taskbar.previewSize
            minimum: 140; maximum: 300; step: 10; integer: true
            suffix: " px"
            onCommitted: function(v) { settings.set("previewSize", Math.round(v)) }
          }
        }
      }
    }
  }

  Component {
    id: effectsTab

    Row {
      spacing: settings.columnGap
      readonly property real columnWidth: (settings.cardWidth - settings.columnGap) / 2

      Column {
        width: parent.columnWidth
        spacing: Style.space(6)

        Section { title: "Motion" }

        SettingRow {
          label: "Motion effects"
          description: "minimize/restore outline; apps assemble and dissolve in pixels"
          ToggleSwitch { checked: settings.taskbar.motionEffects; onToggled: settings.set("motionEffects", !checked) }
        }
        SettingRow {
          label: "Snap preview"
          description: "outline where a dragged window will land at a screen edge"
          ToggleSwitch { checked: settings.taskbar.snapPreview; onToggled: settings.set("snapPreview", !checked) }
        }
      }

    }
  }

  Component {
    id: cornersTab

    Row {
      spacing: settings.columnGap

      // A small screen with a picker in each corner.
      Rectangle {
        id: screenArt
        width: Style.space(520)
        height: Math.round(width * 0.5625)
        radius: Style.cornerRadius + 4
        color: Util.alpha(Color.menu.text, 0.03)
        border.width: 2
        border.color: Util.alpha(Color.menu.text, 0.25)

        // The bar across the top, for orientation.
        Rectangle {
          x: 2; y: 2
          width: parent.width - 4
          height: Style.space(10)
          color: Util.alpha(Color.menu.text, 0.08)
        }

        Repeater {
          model: [
            { corner: "top-left", right: false, bottom: false },
            { corner: "top-right", right: true, bottom: false },
            { corner: "bottom-left", right: false, bottom: true },
            { corner: "bottom-right", right: true, bottom: true }
          ]

          Item {
            id: cornerItem
            required property var modelData
            readonly property string action: settings.corners[modelData.corner] || "none"

            width: picker.width
            height: picker.height
            x: modelData.right ? screenArt.width - width - Style.space(14) : Style.space(14)
            y: modelData.bottom ? screenArt.height - height - Style.space(14) : Style.space(20)

            // A dot in the very corner shows which one this is.
            Rectangle {
              readonly property int size: Style.space(8)
              width: size; height: size; radius: size / 2
              color: cornerItem.action === "none" ? Util.alpha(Color.menu.text, 0.3) : Color.accent
              x: cornerItem.modelData.right ? cornerItem.width + Style.space(14) - size - 4 : -Style.space(14) + 4
              y: cornerItem.modelData.bottom ? cornerItem.height + Style.space(14) - size - 4 : -Style.space(20) + 4
            }

            Dropdown {
              id: picker
              width: Style.space(170)
              showLabel: false
              options: settings.cornerActions
              value: cornerItem.action
              fontFamily: Style.font.menuFamily
              onChanged: function(v) { settings.setCorner(cornerItem.modelData.corner, v) }
            }
          }
        }
      }

      Column {
        width: settings.cardWidth - screenArt.width - settings.columnGap
        spacing: Style.space(6)

        Section { title: "Hot corners" }

        Text {
          width: parent.width
          text: "Push the pointer into a corner of the screen to run its action. Corners are ignored mid-drag and in true fullscreen."
          wrapMode: Text.WordWrap
          color: Color.menu.text
          opacity: 0.6
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
        }

        Item { width: 1; height: Style.space(6) }

        SettingRow {
          label: "Corner effect"
          description: "an accent bracket in the corner that fired"
          ToggleSwitch {
            checked: (settings.corners.effect || "on") !== "off"
            onToggled: settings.setRipple(!checked)
          }
        }
      }
    }
  }

  function setPrimaries(first, second) {
    Util.execArgv([dir + "/agents", "primary", first, second])
    agentsReload.restart()
  }
  Timer { id: agentsReload; interval: 400; onTriggered: settings.taskbar.reloadAgents() }

  Component {
    id: agentsTab

    Column {
      id: agTab
      width: settings.cardWidth
      spacing: Style.space(6)
      readonly property var list: settings.taskbar.agents
      readonly property var primaries: list.filter(function(a) { return a.primary })
      readonly property string first: primaries.length > 0 ? primaries[0].id : ""
      readonly property string second: primaries.length > 1 ? primaries[1].id : ""
      readonly property var options: list.map(function(a) { return { value: a.id, label: a.name } })

      Section { title: "Coding agents" }

      SettingRow {
        label: "First agent"
        description: "the first button wherever you can ask an agent (screenshots, Files, selected text), and Omarchy's default agent"
        ButtonGroup {
          options: agTab.options
          value: agTab.first
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) {
            settings.setPrimaries(v, v === agTab.second ? agTab.first : agTab.second)
          }
        }
      }
      SettingRow {
        label: "Second agent"
        description: "the second button; any others are under More"
        ButtonGroup {
          options: agTab.options
          value: agTab.second
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) {
            settings.setPrimaries(v === agTab.first ? agTab.second : agTab.first, v)
          }
        }
      }
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Installed: " + agTab.list.map(function(a) { return a.name }).join(", ")
          + ". Omarchy knows a dozen more (OpenCode, Gemini, Copilot, Cursor, Crush, Pi…): install one from Omarchy's menu (Setup > Default Agent) and it shows up here."
          + " Ask about selected text: Super+Alt+A."
        color: Color.menu.text
        opacity: 0.45
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Component {
    id: windowsTab

    Row {
      id: winTab
      spacing: settings.columnGap
      readonly property real columnWidth: (settings.cardWidth - settings.columnGap) / 2
      readonly property var prefs: settings.taskbar.prefs || ({})
      function pick(key, fallback) { var v = prefs[key]; return v === undefined || v === null ? fallback : String(v) }

      Column {
        width: winTab.columnWidth
        spacing: Style.space(6)

        Section { title: "Placing windows" }

        SettingRow {
          label: "Gathering windows"
          description: winTab.pick("gatherLayout", "even") === "plain"
            ? "where Hyprland puts them: each one splits whatever's focused"
            : "laid out evenly when they're alone there: 2 side by side, 3 one big + two stacked, 4 a grid (double-click, Bring here, drag to a workspace)"
          ButtonGroup {
            options: [{ value: "even", label: "Even" }, { value: "plain", label: "As placed" }]
            value: winTab.pick("gatherLayout", "even")
            foreground: Color.menu.text
            background: Color.menu.background
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { settings.set("gatherLayout", v) }
          }
        }
        SettingRow {
          label: "New window of an app"
          description: winTab.pick("newWindowPlace", "app") === "here"
            ? "opens on the workspace you're on"
            : "opens on the app's workspace (going there) when all its windows are on one; Files always opens here"
          ButtonGroup {
            options: [{ value: "app", label: "App's workspace" }, { value: "here", label: "Here" }]
            value: winTab.pick("newWindowPlace", "app")
            foreground: Color.menu.text
            background: Color.menu.background
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { settings.set("newWindowPlace", v) }
          }
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "New window = middle-click or Shift+click an icon, or Super+Return twice."
          color: Color.menu.text
          opacity: 0.45
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }

        Item { width: 1; height: Style.space(6) }
        Section { title: "Apps that come to you" }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Clicking brings their window to the workspace you're on (double-click: all of them; a preview: that one) instead of taking you to it. Add one: right-click its icon > Bring to current workspace."
          color: Color.menu.text
          opacity: 0.45
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }
        Flow {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: settings.taskbar.hereApps
            Rectangle {
              id: hereChip
              required property var modelData
              width: hereRow.implicitWidth + Style.space(16)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: Util.alpha(Color.menu.text, 0.06)
              border.width: 1
              border.color: Util.alpha(Color.menu.text, 0.2)
              Row {
                id: hereRow
                anchors.centerIn: parent
                spacing: Style.space(8)
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: settings.taskbar.appNames[hereChip.modelData] || String(hereChip.modelData).replace(/^app:/, "")
                  color: Color.menu.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "×"
                  color: Color.menu.text
                  opacity: removeMouse.containsMouse ? 1 : 0.5
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settings.set("hereApps", JSON.stringify(settings.taskbar.hereApps.filter(function(k) { return k !== hereChip.modelData })))
                  }
                }
              }
            }
          }
          Text {
            visible: settings.taskbar.hereApps.length === 0
            text: "None"
            color: Color.menu.text
            opacity: 0.45
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // Icons: the desktop's line icons (bar/modules/taskbar-icons.js, one
  // drawing per app recoloured with the theme) or each app's own colour
  // icon, per place. Apps without a line icon keep their own everywhere.
  Component {
    id: iconsTab

    Column {
      id: icTab
      width: settings.cardWidth / 2
      spacing: Style.space(6)
      readonly property var prefs: settings.taskbar.prefs || ({})

      Section { title: "Icons" }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Line: the desktop's icons in the theme's colours. Coloured: each in its app's colour. Theme-coloured: that colour matched to your theme. Original: each app's own icon. Apps without a line icon keep their own."
        color: Color.menu.text
        opacity: 0.55
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }

      Repeater {
        model: [
          { place: "Taskbar", style: "iconsTaskbar", styleDefault: "line", label: "Taskbar and switcher", description: "the taskbar, window previews and Super+Tab" },
          { place: "SuperMenu", style: "iconsSuperMenu", styleDefault: "app", label: "Super menu", description: "the app grid" },
          { place: "Launcher", style: "iconsLauncher", styleDefault: "app", label: "App launcher", description: "Omarchy's Super+Space list" },
          { place: "NowPlaying", style: "iconsNowPlaying", styleDefault: "app", label: "Now playing", description: "the card and its volume mixer" }
        ]
        SettingRow {
          id: placeRow
          required property var modelData
          readonly property string style: icTab.prefs[modelData.style] || modelData.styleDefault
          readonly property string colors: icTab.prefs["iconColors" + modelData.place] || icTab.prefs.iconColors || "mono"
          label: modelData.label
          description: modelData.description
          ButtonGroup {
            options: [{ value: "mono", label: "Line" }, { value: "brand", label: "Coloured" },
                      { value: "palette", label: "Theme-coloured" }, { value: "app", label: "Original" }]
            value: placeRow.style === "app" ? "app" : (["brand", "palette"].indexOf(placeRow.colors) !== -1 ? placeRow.colors : "mono")
            foreground: Color.menu.text
            background: Color.menu.background
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) {
              var pairs = {}
              if (v === "app") {
                pairs[placeRow.modelData.style] = "app"
              } else {
                pairs["iconColors" + placeRow.modelData.place] = v
                pairs[placeRow.modelData.style] = "line"
              }
              settings.setMany(pairs)
            }
          }
        }
      }
      SettingRow {
        label: "Omarchy menu"
        description: "Super+Alt+Space: its entries that are apps (Setup > Default, Install / Remove); one colour, it draws icons as text"
        ButtonGroup {
          options: [{ value: "line", label: "Line" }, { value: "omarchy", label: "Original" }]
          value: icTab.prefs.iconsOmarchyMenu === "line" ? "line" : "omarchy"
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) {
            settings.set("iconsOmarchyMenu", v)
            Util.execArgv([settings.dir + "/menu-icons", v === "line" ? "on" : "off"])
          }
        }
      }
    }
  }

  // Equalizer tab: where the equalizers and effects show, and which style each
  // uses. All drawn on the GPU (Equalizer.qml, Visualizer.qml, artfx), and
  // each only runs while it's shown and something plays.
  Component {
    id: visualizersTab

    Row {
      id: visTab
      spacing: Style.space(24)
      readonly property real columnWidth: (settings.cardWidth - spacing) / 2 - Style.space(12)
      readonly property var prefs: settings.taskbar.prefs || ({})
      readonly property var eqStyles: [{ value: "spectrum", label: "Spectrum" }, { value: "wave", label: "Wave" }, { value: "embers", label: "Embers" },
                    { value: "ripple", label: "Ripple" }, { value: "scope", label: "Scope" }, { value: "mist", label: "Mist" },
                    { value: "fire", label: "Fire" }, { value: "radar", label: "Radar" }, { value: "swirl", label: "Swirl" },
                    { value: "plasma", label: "Plasma" }, { value: "rain", label: "Rain" }, { value: "shuffle", label: "Shuffle" }]

      Column {
        width: parent.columnWidth
        spacing: Style.space(6)

        Section { title: "Where" }

        SettingRow {
          label: "Taskbar"
          description: "behind the icons of apps playing sound; its style on the right"
          ToggleSwitch { checked: settings.taskbar.audioMarks; onToggled: settings.set("audioMarks", !checked) }
        }
        SettingRow {
          label: "Bar, by the song"
          description: "a small one next to the now-playing title"
          Dropdown {
            width: Style.space(180)
            showLabel: false
            fontFamily: Style.font.menuFamily
            options: [{ value: "off", label: "Off" }, { value: "same", label: "Same as taskbar" }].concat(visTab.eqStyles)
            value: visTab.prefs.nowPlayingBarEq || "off"
            onChanged: function(v) { settings.set("nowPlayingBarEq", v) }
          }
        }
        SettingRow {
          label: "Card header"
          description: "by NOW PLAYING in the card, when the card visualizer is off"
          Dropdown {
            width: Style.space(180)
            showLabel: false
            fontFamily: Style.font.menuFamily
            options: [{ value: "same", label: "Same as taskbar" }].concat(visTab.eqStyles).concat([{ value: "off", label: "Off" }])
            value: visTab.prefs.nowPlayingHeaderEq || "same"
            onChanged: function(v) { settings.set("nowPlayingHeaderEq", v) }
          }
        }
      SettingRow {
        label: "Card visualizer"
        description: "under the art; right-click the art to step through them"
        Dropdown {
          width: Style.space(180)
          showLabel: false
          fontFamily: Style.font.menuFamily
          options: [{ value: "pixel", label: "Pixel equalizer" }, { value: "tunnel", label: "Tunnel" }, { value: "kaleido", label: "Kaleidoscope" },
                    { value: "starfield", label: "Starfield" }, { value: "battery", label: "Battery" }, { value: "lava", label: "Lava" },
                    { value: "lissajous", label: "Lissajous" }, { value: "aurora", label: "Aurora" }, { value: "off", label: "Off" }]
          value: visTab.prefs.nowPlayingVisual || (visTab.prefs.nowPlayingVisualizer === false ? "off" : "pixel")
          onChanged: function(v) { settings.set("nowPlayingVisual", v) }
        }
      }
        SettingRow {
          visible: (visTab.prefs.nowPlayingVisual || "pixel") === "pixel"
          label: "Card equalizer style"
          description: "for the card's pixel equalizer"
          Dropdown {
            width: Style.space(180)
            showLabel: false
            fontFamily: Style.font.menuFamily
            options: [{ value: "same", label: "Same as taskbar" }].concat(visTab.eqStyles)
            value: visTab.prefs.nowPlayingCardEq || "same"
            onChanged: function(v) { settings.set("nowPlayingCardEq", v) }
          }
        }
      SettingRow {
        label: "Album art effect"
        description: "moves with the music; middle-click the art to step through them"
        Dropdown {
          width: Style.space(180)
          showLabel: false
          fontFamily: Style.font.menuFamily
          options: [{ value: "off", label: "Off" }, { value: "glitch", label: "Glitch" }, { value: "chroma", label: "Chroma" },
                    { value: "pixel", label: "Pixelate" }, { value: "crt", label: "CRT" }, { value: "melt", label: "Melt" }, { value: "solar", label: "Solar" }]
          value: visTab.prefs.nowPlayingArtFx || "off"
          onChanged: function(v) { settings.set("nowPlayingArtFx", v) }
        }
      }
      }

      Column {
        width: parent.columnWidth
        spacing: Style.space(6)

        Section { title: "Taskbar style" }

        Grid {
          columns: 3
          columnSpacing: Style.space(8)
          rowSpacing: Style.space(8)
          readonly property real tileWidth: (parent.width - 2 * columnSpacing) / 3

          Repeater {
            model: [
              { value: "spectrum", label: "Spectrum" },
              { value: "wave", label: "Wave" },
              { value: "embers", label: "Embers" },
              { value: "ripple", label: "Ripple" },
              { value: "scope", label: "Scope" },
              { value: "mist", label: "Mist" },
              { value: "fire", label: "Fire" },
              { value: "radar", label: "Radar" },
              { value: "swirl", label: "Swirl" },
              { value: "plasma", label: "Plasma" },
              { value: "rain", label: "Rain" },
              { value: "shuffle", label: "Shuffle" }
            ]

            Rectangle {
              id: swatch
              required property var modelData
              readonly property bool current: settings.taskbar.equalizerStyle === modelData.value

              width: parent.tileWidth
              height: Style.space(76)
              radius: Style.cornerRadius
              color: current ? Color.menu.selectedBackground : (swatchMouse.containsMouse ? Util.alpha(Color.menu.text, 0.05) : "transparent")
              border.width: current ? 2 : 1
              border.color: current ? Color.accent : Util.alpha(Color.menu.text, 0.14)

              Equalizer {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space(10)
                columns: 14
                rows: 9
                pixel: 3
                gap: 1
                playing: settings.opened
                style: swatch.modelData.value
                opacity: swatch.current ? 0.9 : 0.55
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(8)
                text: swatch.modelData.label
                color: swatch.current ? Color.menu.selectedText : Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: swatchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: settings.set("equalizerStyle", swatch.modelData.value)
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: nowPlayingTab

    Column {
      id: npTab
      width: settings.cardWidth / 2
      spacing: Style.space(6)
      readonly property var prefs: settings.taskbar.prefs || ({})

      Section { title: "Now playing (bar center)" }

      SettingRow {
        label: "Left-click"
        description: "right-click does the other one; middle-click skips the track"
        ButtonGroup {
          options: [{ value: "card", label: "Opens the card" }, { value: "play", label: "Play / pause" }]
          value: npTab.prefs.nowPlayingClick === "play" ? "play" : "card"
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) { settings.set("nowPlayingClick", v) }
        }
      }
      SettingRow {
        label: "Scrolling over it"
        description: "the app's own volume, not the system's"
        ButtonGroup {
          readonly property string mode: npTab.prefs.nowPlayingScroll || "volume"
          options: [{ value: "volume", label: "Volume" }, { value: "track", label: "Changes track" }, { value: "off", label: "Nothing" }]
          value: mode
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) { settings.set("nowPlayingScroll", v) }
        }
      }
      SettingRow {
        label: "Volume while scrolling"
        description: (npTab.prefs.nowPlayingVolume || "center") === "side" ? "a bar, the percent at the right" : "the percent in the middle, the level growing out both sides"
        ButtonGroup {
          options: [{ value: "center", label: "Centered" }, { value: "side", label: "Bar + percent" }]
          value: (npTab.prefs.nowPlayingVolume || "center") === "side" ? "side" : "center"
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) { settings.set("nowPlayingVolume", v) }
        }
      }
      SettingRow {
        label: "Title on the bar"
        description: "off: just the album art"
        ToggleSwitch {
          checked: npTab.prefs.nowPlayingTitle !== false
          onToggled: settings.set("nowPlayingTitle", !checked)
        }
      }
    }
  }

  // Screenshot editor presets that are installed, and the one in use
  // (~/.config/omarchy/screenshot-editor).
  property var editorsInstalled: []
  property string editorInUse: "tensaku"
  Process {
    id: editorsProc
    command: ["bash", "-c", "e=\"$HOME/.config/omarchy/screenshot-editor\"; \"$e\" available | tr '\\n' ' '; echo; sed -n 's/^editor=//p' \"$HOME/.config/omarchy/screenshot-editor.conf\" | tail -1"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = this.text.split("\n")
        settings.editorsInstalled = (lines[0] || "").trim().split(/\s+/).filter(function(x) { return x !== "" })
        settings.editorInUse = (lines[1] || "tensaku").trim() || "tensaku"
      }
    }
  }

  Component {
    id: screenshotsTab

    Column {
      id: shotTab
      width: settings.cardWidth / 2
      spacing: Style.space(6)
      readonly property var prefs: settings.taskbar.prefs || ({})
      readonly property var names: ({ tensaku: "Tensaku", satty: "Satty", swappy: "Swappy", ksnip: "ksnip", custom: "Custom" })

      Section { title: "After a screenshot (Print Screen)" }

      SettingRow {
        label: "Open"
        description: (shotTab.prefs.screenshotMode || "editor") === "editor"
          ? "the screenshot in the editor, with Ask Claude / Ask Codex attached under it"
          : "a preview window: the screenshot, Ask Claude / Ask Codex, Edit, Open folder"
        ButtonGroup {
          options: [{ value: "editor", label: "The editor" }, { value: "preview", label: "A preview" }]
          value: (shotTab.prefs.screenshotMode || "editor") === "editor" ? "editor" : "preview"
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) { settings.set("screenshotMode", v) }
        }
      }
      SettingRow {
        label: "Ask controls"
        description: (shotTab.prefs.screenshotAsk || "panel") === "bar"
          ? "a row of buttons: under the editor window, under the preview's picture"
          : (shotTab.prefs.screenshotAsk || "panel") === "button"
          ? "just an Ask button; it opens the panel when you want it"
          : "the ask layout (agents, a big question box, Send to, Effort): beside the editor window, around the preview's picture"
        ButtonGroup {
          options: [{ value: "panel", label: "Panel" }, { value: "bar", label: "Bar" }, { value: "button", label: "Button" }]
          value: ["bar", "button"].indexOf(shotTab.prefs.screenshotAsk) !== -1 ? shotTab.prefs.screenshotAsk : "panel"
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) { settings.set("screenshotAsk", v) }
        }
      }
      SettingRow {
        label: "Editor"
        description: "installed editors that can open a screenshot (Flameshot can't: it only edits its own captures); a custom one goes in ~/.config/omarchy/screenshot-editor.conf"
        ButtonGroup {
          options: {
            var list = settings.editorsInstalled.map(function(e) { return { value: e, label: shotTab.names[e] || e } })
            if (settings.editorInUse === "custom") list.push({ value: "custom", label: "Custom" })
            return list.length ? list : [{ value: "tensaku", label: "Tensaku" }]
          }
          value: settings.editorInUse
          foreground: Color.menu.text
          background: Color.menu.background
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) {
            settings.editorInUse = v
            Util.execArgv([settings.dir + "/screenshot-editor", "set", v])
          }
        }
      }
    }
  }

  Component {
    id: mouseTab

    Column {
      width: settings.cardWidth / 2
      spacing: Style.space(6)

      Section { title: "Scrolling" }

      SettingRow {
        label: "Scroll speed"
        description: "how far each wheel notch scrolls, in every app (1× = stock)"
        ValueSlider {
          value: settings.scrollFactor
          minimum: 0.5; maximum: 4; step: 0.25
          decimals: 2; suffix: "×"
          // Live while dragging, so you can scroll something and adjust.
          onLiveChanged: if (Math.abs(live - settings.scrollFactor) > 0.01) scrollApply.restart()
          onCommitted: function(v) { settings.setScroll(v) }

          Timer {
            id: scrollApply
            interval: 120
            onTriggered: settings.setScroll(parent.live)
          }
        }
      }

      SettingRow {
        label: "Terminal scroll speed"
        description: "lines per wheel notch in Ghostty, on top of the above (3 = Ghostty's default)"
        ValueSlider {
          value: settings.terminalScroll
          minimum: 0.5; maximum: 10; step: 0.5
          decimals: 1; suffix: " lines"
          onCommitted: function(v) { settings.setTerminalScroll(v) }
        }
      }
    }
  }

  function setScroll(v) {
    scrollFactor = Math.round(v * 100) / 100
    Util.execArgv([dir + "/mouse-setting", "scroll", String(scrollFactor)])
  }

  Component {
    id: titlebarsTab

    Column {
      spacing: Style.space(6)

      SettingRow {
        label: "Title bars"
        description: "minimize, maximize and close on every window; drag them to move, or onto a workspace number"
        ToggleSwitch {
          checked: settings.titlebarsOn
          onToggled: {
            settings.titlebarsOn = !checked
            Util.execArgv([settings.dir + "/titlebars", checked ? "off" : "on"])
          }
        }
      }

      Item { width: 1; height: Style.space(6) }
      Section { title: "Apps that draw their own title bar" }

      Text {
        visible: settings.taskbar.titlebarOff.length === 0
        text: "None. Right-click an app's taskbar icon > Hide title bar to add one."
        color: Color.menu.text
        opacity: 0.5
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
      }

      Flow {
        width: parent.width
        spacing: Style.space(8)

        Repeater {
          model: settings.taskbar.titlebarOff

          Rectangle {
            id: chip
            required property var modelData
            width: chipRow.implicitWidth + Style.space(20)
            height: Style.space(34)
            radius: Style.cornerRadius
            color: "transparent"
            border.width: 1
            border.color: Util.alpha(Color.menu.text, 0.18)

            Row {
              id: chipRow
              anchors.centerIn: parent
              spacing: Style.space(10)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.modelData.name || chip.modelData.key
                color: Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: removeMouse.containsMouse ? Color.urgent : Color.menu.text
                opacity: removeMouse.containsMouse ? 1 : 0.5
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall

                MouseArea {
                  id: removeMouse
                  anchors.fill: parent
                  anchors.margins: -Style.space(6)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Util.execArgv([settings.dir + "/taskbar-action", "titlebar", "on", JSON.stringify(chip.modelData.classes || [])])
                }
              }
            }
          }
        }
      }

      Text {
        visible: settings.taskbar.titlebarOff.length > 0
        text: "× gives the app its title bar back. Add more from a taskbar icon's right-click menu."
        color: Color.menu.text
        opacity: 0.45
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
