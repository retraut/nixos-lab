import QtQuick
import Quickshell

BarWidget {
  id: root

  property var theme: null
  property int fontSize: 20
  property string fontFamily: "JetBrainsMono Nerd Font"
  property bool hovered: button.containsMouse
  implicitWidth: 30
  implicitHeight: 28

  BarIconButton {
    id: button
    anchors.fill: parent
    text: ""
    foreground: root.theme ? root.theme.foreground : "#c0caf5"
    active: root.hovered
    activeColor: root.theme ? root.theme.accent : "#7aa2f7"
    hoverColor: root.theme ? root.theme.selected : "#24283b"
    fontSize: root.fontSize
    fontFamily: root.fontFamily
    onPressed: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/nixos-menu"])
  }
}
