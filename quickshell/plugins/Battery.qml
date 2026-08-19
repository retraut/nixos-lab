import QtQuick
import Quickshell
import Quickshell.Services.UPower

BarWidget {
  id: root

  signal activated()
  property bool hovered: button.containsMouse
  property color textColor: "#a9b1d6"
  property color accentColor: "#7aa2f7"
  property int fontSize: 20
  property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property var device: UPower.displayDevice
  readonly property bool present: !!device && device.isPresent
  readonly property bool discharging: present && UPower.onBattery
  readonly property real fraction: present ? Math.max(0, Math.min(1, Number(device.percentage))) : 0
  readonly property string icon: {
    if (!present) return "󰚥"
    var icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    return icons[Math.max(0, Math.min(9, Math.floor(fraction * 10)))]
  }
  visible: root.present
  implicitWidth: 30
  implicitHeight: 26

  BarIconButton {
    id: button
    anchors.fill: parent
    slotSize: 30
    text: root.icon
    foreground: root.textColor
    active: root.hovered
    activeColor: root.accentColor
    hoverColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
    fontSize: root.fontSize
    fontFamily: root.fontFamily
    onPressed: root.activated()
  }
}
