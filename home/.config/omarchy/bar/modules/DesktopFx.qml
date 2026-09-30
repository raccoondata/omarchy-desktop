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
//  - Hot corner: an accent bracket draws along the two edges of the corner
//    that fired, then fades (~/.config/omarchy/hotcorner calls hotCorner).
//  - Locking (~/.config/omarchy/lock): a "Locked, type your password" card
//    just before the lock, so remote viewers see that, not the desktop.
//  - Print Screen: an accent frame around exactly what was captured, held
//    while the screenshot toolbar is up, and the capture flying into the
//    toolbar's thumbnail.
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

  property string corner: ""
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

  // Print Screen: a frame around exactly what was captured, held while the
  // screenshot toolbar is up; and the capture itself flying from where it
  // was into the toolbar's thumbnail (rects in global coordinates).
  property rect captureArea: Qt.rect(0, 0, 0, 0)
  property bool captureHeld: false
  property string flyingSource: ""
  property rect flyFrom: Qt.rect(0, 0, 0, 0)
  property rect flyTo: Qt.rect(0, 0, 0, 0)
  signal captureLanded()

  function outlineCapture(area) {
    captureArea = area
    captureHeld = true
  }

  function releaseCapture() {
    captureHeld = false
  }

  // fit: shown whole (flying into a window) rather than filling the target
  // (the toolbar's thumbnail).
  property bool flyFit: false
  function flyCapture(source, from, to, fit) {
    flyFit = !!fit
    flyingSource = source
    flyFrom = from
    flyTo = to
    captureFlight.restart()
  }

  // Locking: a full-screen card drawn just before the lock covers the screen.
  // Screen sharing freezes on its last frame while locked (Hyprland hides the
  // lock screen from capture), so a remote viewer (RustDesk) sees this card
  // instead of whatever was on the desktop, and knows to type the password.
  property bool lockCard: false

  function ripple(name) {
    corner = name
    bracket.restart()
  }

  PanelWindow {
    id: overlay

    screen: fx.taskbar.QsWindow.window ? fx.taskbar.QsWindow.window.screen : null
    visible: fx.previewShown || previewFade.running || bracket.running || morphAnimation.running
      || fx.captureHeld || captureFade.running || captureFlight.running
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

    // --------------------------------------------------------- capture

    // Drawn just outside the captured area, so it frames rather than covers.
    Rectangle {
      id: captureBox
      readonly property int w: fx.borderWidth
      x: fx.captureArea.x - overlay.originX - w
      y: fx.captureArea.y - overlay.originY - w
      width: fx.captureArea.width + w * 2
      height: fx.captureArea.height + w * 2
      color: "transparent"
      border.color: Color.accent
      border.width: w
      opacity: fx.captureHeld ? 1 : 0
      visible: opacity > 0

      Behavior on opacity { NumberAnimation { id: captureFade; duration: 220; easing.type: Easing.OutCubic } }
    }

    // The capture, lifting off where it was and shrinking into the toolbar.
    Image {
      id: flyer
      property real t: 0
      readonly property real ease: t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
      function mix(a, b) { return a + (b - a) * ease }

      x: mix(fx.flyFrom.x, fx.flyTo.x) - overlay.originX
      y: mix(fx.flyFrom.y, fx.flyTo.y) - overlay.originY
      width: Math.max(1, mix(fx.flyFrom.width, fx.flyTo.width))
      height: Math.max(1, mix(fx.flyFrom.height, fx.flyTo.height))
      source: fx.flyingSource ? "file://" + fx.flyingSource : ""
      fillMode: fx.flyFit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
      asynchronous: false
      cache: false
      smooth: true
      visible: captureFlight.running

      Rectangle {
        anchors.centerIn: parent
        width: fx.flyFit ? flyer.paintedWidth : parent.width
        height: fx.flyFit ? flyer.paintedHeight : parent.height
        color: "transparent"
        border.color: Color.accent
        border.width: 2
      }
    }

    SequentialAnimation {
      id: captureFlight
      PauseAnimation { duration: 120 }
      NumberAnimation { target: flyer; property: "t"; from: 0; to: 1; duration: 420 }
      ScriptAction { script: fx.captureLanded() }
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

    // --------------------------------------------------------- hot corner

    // An L of accent lines hugging the corner, like a window border drawn
    // into the corner and let go.
    Item {
      id: cornerMark
      readonly property bool atRight: fx.corner.indexOf("right") !== -1
      readonly property bool atBottom: fx.corner.indexOf("bottom") !== -1
      readonly property int reach: 140
      property real grow: 0

      anchors.fill: parent
      opacity: 0

      Rectangle {
        // Along the top or bottom edge.
        width: cornerMark.reach * cornerMark.grow
        height: fx.borderWidth + 1
        x: cornerMark.atRight ? parent.width - width : 0
        y: cornerMark.atBottom ? parent.height - height : 0
        color: Color.accent
      }

      Rectangle {
        // Along the left or right edge.
        width: fx.borderWidth + 1
        height: cornerMark.reach * cornerMark.grow
        x: cornerMark.atRight ? parent.width - width : 0
        y: cornerMark.atBottom ? parent.height - height : 0
        color: Color.accent
      }

      // A faint wash in the corner itself.
      Rectangle {
        readonly property real size: cornerMark.reach * 0.55 * cornerMark.grow
        width: size
        height: size
        x: cornerMark.atRight ? parent.width - width : 0
        y: cornerMark.atBottom ? parent.height - height : 0
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0.0; color: cornerMark.atBottom ? "transparent" : Util.alpha(Color.accent, 0.18) }
          GradientStop { position: 1.0; color: cornerMark.atBottom ? Util.alpha(Color.accent, 0.18) : "transparent" }
        }
      }
    }

    SequentialAnimation {
      id: bracket
      ScriptAction { script: { cornerMark.grow = 0; cornerMark.opacity = 1 } }
      NumberAnimation { target: cornerMark; property: "grow"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
      PauseAnimation { duration: 140 }
      NumberAnimation { target: cornerMark; property: "opacity"; to: 0; duration: 260; easing.type: Easing.InQuad }
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
