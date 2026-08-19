import QtQuick

BarWidget {
  id: root

  signal activated()
  signal closeRequested()
  property color textColor: "#a9b1d6"
  property color accentColor: "#7aa2f7"
  property bool hovered: button.containsMouse
  property int fontSize: 20
  property string fontFamily: "JetBrainsMono Nerd Font"
  implicitWidth: 30
  implicitHeight: 28

  BarIconButton {
    id: button
    anchors.fill: parent
    text: "⚙"
    foreground: root.textColor
    active: root.hovered
    activeColor: root.accentColor
    hoverColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
    fontSize: root.fontSize
    fontFamily: root.fontFamily
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.closeRequested()
      else root.activated()
    }
  }
}
