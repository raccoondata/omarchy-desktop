import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Windows-style window switcher (like Alt+Tab), drawn like Omarchy's own
// launcher. Omarchy keeps Alt+Tab for cycling tiles; this is on Super+Tab.
//
// Hyprland's SUPER+TAB / SUPER+SHIFT+TAB bindings (hypr/desktop/bindings.lua) run
// `omarchy-shell -q taskbar switcherNext|switcherPrev` (the IpcHandler in
// taskbar.qml). The first call opens this overlay on the most recently used
// windows with the previous one selected; each further call moves the
// selection. While open it holds the keyboard, so it sees Super (or Alt) being
// released and switches then. Esc cancels, Enter switches, clicking a card
// switches to that window, middle-click or the card's x closes it.
Item {
  id: switcher

  required property var taskbar
  property bool opened: false
  property var windows: []
  property int selected: 0
  // The cards fade in after a beat so a quick Alt+Tab doesn't flash them.
  property bool shown: false

  readonly property int cardThumbWidth: Style.space(230)
  readonly property int cardSpacing: Style.space(10)

  function open(step) {
    var list = taskbar.switcherWindows()
    if (list.length === 0) return
    windows = list
    selected = list.length > 1 ? (step > 0 ? 1 : list.length - 1) : 0
    opened = true
    shown = false
    showDelay.restart()
    idleGuard.restart()
  }

  function move(step) {
    if (!opened) {
      open(step)
      return
    }
    if (windows.length === 0) return
    selected = (selected + step + windows.length) % windows.length
    shown = true
    idleGuard.restart()
  }

  function commit() {
    if (!opened) return
    var target = windows[selected]
    close()
    if (target) taskbar.switchTo(target)
  }

  function close() {
    opened = false
    shown = false
    showDelay.stop()
    idleGuard.stop()
  }

  Timer {
    id: showDelay
    interval: 90
    onTriggered: switcher.shown = true
  }

  // Never leave the switcher holding the keyboard if the key release was
  // missed (a very quick tap can end before the overlay takes focus).
  Timer {
    id: idleGuard
    interval: 15000
    onTriggered: switcher.close()
  }

  PanelWindow {
    id: panel

    readonly property var focusedScreen: {
      var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      var screens = Quickshell.screens
      for (var i = 0; i < screens.length; i++) if (screens[i].name === name) return screens[i]
      return screens.length > 0 ? screens[0] : null
    }

    visible: switcher.opened
    screen: focusedScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-taskbar-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: switcher.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
      opacity: switcher.shown ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: switcher.close()
    }

    BorderSurface {
      id: frame

      readonly property int cardWidth: switcher.cardThumbWidth + Style.space(6) * 2
      readonly property int maxColumns: Math.max(1, Math.floor((panel.width - Style.gapsOut * 4 - contentLeftInset - contentRightInset + switcher.cardSpacing) / (cardWidth + switcher.cardSpacing)))
      readonly property int columns: Math.max(1, Math.min(switcher.windows.length, maxColumns, 5))

      anchors.centerIn: parent
      width: columns * cardWidth + (columns - 1) * switcher.cardSpacing + contentLeftInset + contentRightInset
      height: cards.implicitHeight + contentTopInset + contentBottomInset
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding
      opacity: switcher.shown ? 1 : 0
      scale: switcher.shown ? 1 : 0.97

      Behavior on opacity { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

      // Clicks between cards shouldn't fall through and dismiss.
      MouseArea { anchors.fill: parent }

      Flow {
        id: cards
        x: frame.contentLeftInset
        y: frame.contentTopInset
        width: frame.width - frame.contentLeftInset - frame.contentRightInset
        spacing: switcher.cardSpacing

        Repeater {
          model: switcher.opened ? switcher.windows : []

          WindowCard {
            required property var modelData
            required property int index
            readonly property var info: switcher.taskbar.windowInfo(modelData)

            toplevel: modelData
            thumbWidth: switcher.cardThumbWidth
            selected: index === switcher.selected
            icon: info.icon
            appIcon: info.appIcon
            active: false
            minimized: info.minimized
            place: info.place
            agent: info.agent
            attention: info.attention
            unread: info.unread
            live: switcher.shown
            textColor: Color.menu.text
            fontFamily: Style.font.menuFamily
            onActivated: {
              switcher.selected = index
              switcher.commit()
            }
            onCloseRequested: switcher.taskbar.closeWindow(modelData)
          }
        }
      }
    }

    Item {
      id: keys
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) switcher.close()
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) switcher.commit()
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down) switcher.move(1)
        else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Up) switcher.move(-1)
        else return
        event.accepted = true
      }
      Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta
            || event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr) {
          switcher.commit()
          event.accepted = true
        }
      }
    }
  }
}
