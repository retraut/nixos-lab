import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  signal activated()
  property bool hovered: mouse.containsMouse
  property string volumeText: "VOL --"
  property color textColor: "#a9b1d6"
  property string prefix: "NIXOS"
  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  function refresh() {
    volume.running = false
    volume.running = true
  }

  Process {
    id: volume
    command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{ printf \"VOL %d%%\", $2 * 100 }'"]
    running: true

    stdout: StdioCollector {
      id: volumeOutput
    }

    onExited: root.volumeText = volumeOutput.text.trim() || "VOL --"
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Text {
    id: label
    text: root.prefix + "  ·  " + root.volumeText
    color: root.textColor
    font.pixelSize: 12
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.activated()
  }
}
