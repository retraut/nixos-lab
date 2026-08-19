import QtQuick

// Common interaction surface for bar widgets. The widget decides what each
// mouse button means through onPressed(button); this component owns the hitbox,
// hover state, cursor, and visual feedback for all of them.
Item {
  id: root

  property var bar: null
  property string text: ""
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontSize: 16
  property color foreground: "#cacccc"
  property color hoverColor: "#1e2327"
  property color activeColor: foreground
  property bool active: false
  property bool useActiveColor: true
  property bool labelVisible: true
  property bool hasVisualContent: text !== ""
  property real horizontalMargin: 5
  property real verticalPadding: 0
  property real fixedWidth: -1
  property real fixedHeight: -1
  property bool interactive: true
  property bool pressable: true
  property alias acceptedButtons: mouseArea.acceptedButtons
  property alias cursorShape: mouseArea.cursorShape

  signal pressed(int button)
  signal wheelMoved(int delta)
  signal entered()
  signal exited()

  readonly property bool containsMouse: mouseArea.containsMouse
  readonly property bool isPressed: mouseArea.pressed

  visible: hasVisualContent
  implicitWidth: fixedWidth > 0 ? fixedWidth : Math.max(12, label.implicitWidth + horizontalMargin * 2)
  implicitHeight: fixedHeight > 0 ? fixedHeight : Math.max(24, label.implicitHeight + verticalPadding * 2)

  Rectangle {
    anchors.fill: parent
    color: root.containsMouse ? root.hoverColor : "transparent"
    radius: 0
  }

  Text {
    id: label
    visible: root.labelVisible
    anchors.centerIn: parent
    text: root.text
    color: root.active && root.useActiveColor ? root.activeColor : root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    enabled: root.interactive
    hoverEnabled: true
    cursorShape: root.pressable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onEntered: root.entered()
    onExited: root.exited()
    onClicked: function(mouse) {
      if (root.pressable) root.pressed(mouse.button)
    }
    onWheel: function(wheel) {
      root.wheelMoved(wheel.angleDelta.y)
    }
  }
}
