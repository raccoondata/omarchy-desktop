import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Desktop-wide effects drawn over the windows, never taking input. Styled
// like the rest of Omarchy: theme colours only (Color.*), the theme's corner
// rounding and gaps (Style.*), thin accent borders, short calm motion.
//
//  - Snap preview: while a tiled window is dragged into a screen-edge zone
//    (top = maximize, left/right = half), the area it will take is outlined
//    like a focused window, with one soft sheen passing over it as the zone is
//    entered. Zones and areas come from the dragevents plugin
//    (windowdragzone events, via taskbar.qml).
//  - Locking (~/.config/omarchy/lock): a "Locked, type your password" card
//    just before the lock, so remote viewers see that, not the desktop.
//  - Minimize/restore: an outline travels from the window into its taskbar
//    icon, or back out (taskbar.qml watches windows move to/from the
//    scratchpad, where minimized windows live).
Item {
  id: fx

  required property var taskbar
  // Snap preview, in layout (global) coordinates.
  property string zone: "none"
  property rect area: Qt.rect(0, 0, 0, 0)
  property bool previewEnabled: true
  readonly property bool previewShown: previewEnabled && zone !== "none" && area.width > 0

  // Matches Hyprland's window border (general:border_size in Omarchy).
  readonly property int borderWidth: 2

  onZoneChanged: if (previewShown) sheen.restart()
  onPreviewShownChanged: if (previewShown) sheen.restart()

  // Minimize/restore: an outline travels between a window and its taskbar
  // icon (rects in layout/global coordinates).
  property rect morphFrom: Qt.rect(0, 0, 0, 0)
  property rect morphTo: Qt.rect(0, 0, 0, 0)

  function morph(from, to) {
    morphFrom = from
    morphTo = to
    morphAnimation.restart()
  }

  // Locking: a full-screen card drawn just before the lock covers the screen.
  // Screen sharing freezes on its last frame while locked (Hyprland hides the
  // lock screen from capture), so a remote viewer (RustDesk) sees this card
  // instead of whatever was on the desktop, and knows to type the password.
  property bool lockCard: false


  PanelWindow {
    id: overlay

    screen: fx.taskbar.QsWindow.window ? fx.taskbar.QsWindow.window.screen : null
    visible: fx.previewShown || previewFade.running || morphAnimation.running
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-desktop-fx"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Input passes straight through to the windows (and the drag) below.
    mask: Region {}

    readonly property real originX: screen ? screen.x : 0
    readonly property real originY: screen ? screen.y : 0

    // ------------------------------------------------------- snap preview

    Rectangle {
      id: preview

      x: fx.area.x - overlay.originX + Style.gapsOut
      y: fx.area.y - overlay.originY + Style.gapsOut
      width: Math.max(0, fx.area.width - Style.gapsOut * 2)
      height: Math.max(0, fx.area.height - Style.gapsOut * 2)
      radius: Style.cornerRadius
      color: Util.alpha(Color.accent, 0.08)
      border.color: Color.accent
      border.width: fx.borderWidth
      opacity: fx.previewShown ? 1 : 0
      clip: true

      Behavior on x { NumberAnimation { duration: fx.taskbar.motionMove; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: fx.taskbar.motionMove; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: fx.taskbar.motionMove; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: fx.taskbar.motionMove; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { id: previewFade; duration: fx.taskbar.motionMove; easing.type: Easing.OutCubic } }

      // One soft band of light across the area when a zone is entered.
      Rectangle {
        id: sheenBand
        width: Math.max(120, preview.width * 0.3)
        height: preview.height
        x: -width
        opacity: 0
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 0.5; color: Util.alpha(Color.accent, 0.14) }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }

      ParallelAnimation {
        id: sheen
        NumberAnimation { target: sheenBand; property: "x"; from: -sheenBand.width; to: preview.width; duration: 520; easing.type: Easing.InOutCubic }
        SequentialAnimation {
          NumberAnimation { target: sheenBand; property: "opacity"; from: 0; to: 1; duration: 120 }
          PauseAnimation { duration: 280 }
          NumberAnimation { target: sheenBand; property: "opacity"; to: 0; duration: 120 }
        }
      }
    }

    // ------------------------------------------------- minimize / restore

    Rectangle {
      id: morphBox
      property real t: 0
      readonly property real ease: t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
      function mix(a, b) { return a + (b - a) * ease }

      x: mix(fx.morphFrom.x, fx.morphTo.x) - overlay.originX
      y: mix(fx.morphFrom.y, fx.morphTo.y) - overlay.originY
      width: Math.max(2, mix(fx.morphFrom.width, fx.morphTo.width))
      height: Math.max(2, mix(fx.morphFrom.height, fx.morphTo.height))
      radius: Style.cornerRadius
      color: Util.alpha(Color.accent, 0.07)
      border.color: Color.accent
      border.width: fx.borderWidth
      opacity: 0
      visible: morphAnimation.running
    }

    ParallelAnimation {
      id: morphAnimation
      NumberAnimation { target: morphBox; property: "t"; from: 0; to: 1; duration: 260 }
      SequentialAnimation {
        NumberAnimation { target: morphBox; property: "opacity"; from: 0; to: 0.95; duration: 50 }
        PauseAnimation { duration: 120 }
        NumberAnimation { target: morphBox; property: "opacity"; to: 0; duration: 90; easing.type: Easing.InQuad }
      }
    }

  }

  // The lock card gets its own window on the top-most layer, above menus,
  // popups and notifications, since it has to cover everything.
  PanelWindow {
    screen: fx.taskbar.QsWindow.window ? fx.taskbar.QsWindow.window.screen : null
    visible: fx.lockCard
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-lock-card"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
      // ------------------------------------------------------------ lock card

      Rectangle {
        anchors.fill: parent
        color: Color.background

        Column {
          anchors.centerIn: parent
          spacing: Style.space(14)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uf023"
            color: Color.accent
            font.family: Style.font.menuFamily
            font.pixelSize: Style.space(48)
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Locked"
            color: Color.foreground
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.heading * 1.6
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Type your password, then press Enter"
            color: Color.foreground
            opacity: 0.55
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
          }
        }
      }
  }
}
