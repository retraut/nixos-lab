import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// NixOS-native visual port of Omarchy's retraut.power panel. UPower is used
// when a real battery exists; the VM deliberately shows a useful AC fallback.
ShellRoot {
  id: root

  Theme { id: theme }

  readonly property var device: UPower.displayDevice
  readonly property bool present: !!device && device.isPresent
  readonly property bool discharging: present && UPower.onBattery
  readonly property real fraction: present ? Math.max(0, Math.min(1, Number(device.percentage))) : 0
  readonly property string percentageText: present ? Math.round(fraction * 100) + "%" : "AC"
  readonly property string stateText: !present ? "Plugged in" : (discharging ? "On battery" : "Charging")
  readonly property string batteryIcon: {
    if (!present) return "󰚥"
    var icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    return icons[Math.max(0, Math.min(9, Math.floor(fraction * 10)))]
  }
  property string activeProfile: ""
  property var topProcesses: []

  readonly property var profileRows: [
    { id: "power-saver", label: "Power saver", icon: "󰌪" },
    { id: "balanced", label: "Balanced", icon: "󰊚" },
    { id: "performance", label: "Performance", icon: "󰓅" }
  ]

  function refresh() {
    profileProc.running = false
    profileProc.running = true
    topProc.running = false
    topProc.running = true
  }

  function setProfile(profile) {
    Quickshell.execDetached(["powerprofilesctl", "set", profile])
    root.activeProfile = profile
    Qt.callLater(root.refresh)
  }

  function parseTopProcesses(raw) {
    var result = []
    var lines = String(raw || "").trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split(/\s+/)
      if (parts.length < 2) continue
      var cpu = Number(parts[parts.length - 1])
      var name = parts.slice(0, parts.length - 1).join(" ")
      if (isFinite(cpu) && name !== "") result.push({ name: name, cpu: cpu.toFixed(1) })
    }
    root.topProcesses = result
  }

  Process {
    id: profileProc
    command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || true"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.activeProfile = String(text || "").trim()
    }
  }

  Process {
    id: topProc
    command: ["sh", "-c", "ps -eo comm=,%cpu= --sort=-%cpu 2>/dev/null | head -5"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.parseTopProcesses(text) }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  function close() { Qt.quit() }

  PanelWindow {
    id: panel
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-battery"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
      id: card
      implicitWidth: content.implicitWidth + 36
      implicitHeight: content.implicitHeight + 36
      width: Math.min(Math.max(426, implicitWidth), 1200)
      height: Math.min(Math.max(556, implicitHeight), 900)
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 44
      anchors.rightMargin: 12
      radius: 0
      color: theme.background
      border.width: 1
      border.color: theme.border
      focus: true
      MouseArea { anchors.fill: parent; onClicked: {} }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
      }

      ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Text { text: root.batteryIcon; color: theme.foreground; font.pixelSize: 25 }
          Column {
            spacing: 1
            Text { text: "Battery"; color: theme.foreground; font.pixelSize: theme.widgetFontSize; font.weight: Font.Medium }
            Text { text: root.stateText.toUpperCase(); color: theme.muted; font.pixelSize: theme.widgetFontSize; font.letterSpacing: 1.1 }
          }
          Item { Layout.fillWidth: true }
          Text { text: root.percentageText; color: theme.foreground; font.pixelSize: 28; font.weight: Font.DemiBold }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 8
          radius: 0
          color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
          Rectangle {
            height: parent.height
            width: root.present ? Math.max(parent.height, parent.width * root.fraction) : parent.width
            radius: 0
            color: theme.foreground
          }
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: 20
          rowSpacing: 5
          Repeater {
            model: [
              { label: "Battery size", value: root.present && root.device.energyCapacity !== undefined ? Math.round(root.device.energyCapacity) + " Wh" : "—" },
              { label: "Charge cycles", value: "—" },
              { label: root.discharging ? "Time left" : "Time to full", value: root.present ? "—" : "—" },
              { label: "Power state", value: root.stateText }
            ]
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Text { text: modelData.label; color: theme.muted; font.pixelSize: theme.widgetFontSize }
              Item { Layout.fillWidth: true }
              Text { text: modelData.value; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16) }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 7
          Text { text: "TOP CPU · 5S"; color: theme.muted; font.pixelSize: theme.widgetFontSize; font.weight: Font.Medium }
          Repeater {
            model: root.topProcesses
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Text { text: modelData.name; color: theme.foreground; opacity: 0.75; font.pixelSize: theme.widgetFontSize; elide: Text.ElideRight; Layout.fillWidth: true }
              Text { text: modelData.cpu + "%"; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16) }

        Text { text: "POWER PROFILE"; color: theme.muted; font.pixelSize: theme.widgetFontSize; font.weight: Font.Medium }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: root.profileRows
            delegate: Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: 54
              radius: 0
              color: root.activeProfile === modelData.id ? theme.selected : theme.panel
              border.width: 1
              border.color: root.activeProfile === modelData.id ? theme.accent : theme.border
              Column {
                anchors.centerIn: parent
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: root.activeProfile === modelData.id ? theme.accent : theme.foreground; font.pixelSize: 17 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
              }
              MouseArea { anchors.fill: parent; onClicked: root.setProfile(modelData.id) }
            }
          }
        }

        Item { Layout.fillHeight: true }
      }
    }
  }
}
