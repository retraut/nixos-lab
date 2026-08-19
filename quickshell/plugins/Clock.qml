import QtQuick
import Quickshell

BarWidget {
  id: root

  signal activated()
  property var theme: null
  property color textColor: "#a9b1d6"
  property color hoverColor: theme ? theme.panel : "#1e2327"
  property int fontSize: 16
  property string fontFamily: "JetBrainsMono Nerd Font"

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    text: Qt.formatDateTime(clock.date, "dddd HH:mm")
    foreground: root.textColor
    hoverColor: root.hoverColor
    fontSize: root.fontSize
    fontFamily: root.fontFamily
    onPressed: root.activated()
  }
}
