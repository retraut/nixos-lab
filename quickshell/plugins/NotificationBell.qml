import QtQuick
import Quickshell

BarWidget {
  id: root

  signal activated()
  signal secondaryActivated()
  property var theme: null
  property bool doNotDisturb: false
  property int fontSize: 20
  property string fontFamily: "JetBrainsMono Nerd Font"
  property bool hovered: button.containsMouse
  implicitWidth: 30
  implicitHeight: 28

  BarIconButton {
    id: button
    anchors.fill: parent
    text: root.doNotDisturb ? "󰂛" : "󰂚"
    foreground: root.doNotDisturb
      ? (root.theme ? root.theme.urgent : "#f7768e")
      : (root.theme ? root.theme.foreground : "#c0caf5")
    active: root.hovered
    activeColor: root.doNotDisturb
      ? (root.theme ? root.theme.urgent : "#f7768e")
      : (root.theme ? root.theme.accent : "#7aa2f7")
    hoverColor: root.theme ? root.theme.selected : "#24283b"
    fontSize: root.fontSize
    fontFamily: root.fontFamily
    // Match Agents.qml exactly: touchpad two-finger click is accepted as
    // either RightButton or MiddleButton and emitted as a secondary action.
    onPressed: function(button) {
      if (button === Qt.RightButton || button === Qt.MiddleButton)
        root.secondaryActivated()
      else
        root.activated()
    }
  }
}
