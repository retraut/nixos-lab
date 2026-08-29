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

  readonly property int titleSize: 20
  readonly property int bodySize: 15
  readonly property int captionSize: 13

  readonly property var device: UPower.displayDevice
  // displayDevice is an aggregate and does not carry the physical battery's
  // Capacity/health value. Select the real laptop battery for health data.
  readonly property var physicalBattery: {
    var devices = UPower.devices.values
    for (var i = 0; i < devices.length; i++) {
      var candidate = devices[i]
      if (candidate && candidate.isLaptopBattery && candidate.isPresent)
        return candidate
    }
    return null
  }
  readonly property var healthDevice: physicalBattery || device
  readonly property bool present: !!device && device.isPresent
  readonly property bool discharging: present && UPower.onBattery
  readonly property bool charging: present && device.state === UPowerDeviceState.Charging
  readonly property real fraction: present ? Math.max(0, Math.min(1, Number(device.percentage))) : 0
  readonly property real currentEnergy: present ? Number(device.energy) : NaN
  readonly property real energyCapacity: present ? Number(device.energyCapacity) : NaN
  readonly property string percentageText: present ? Math.round(fraction * 100) + "%" : "AC"
  readonly property string stateText: !present ? "Plugged in" : (discharging ? "On battery" : "Charging")
  property var energySamples: []
  readonly property int sampleWindowMs: 5 * 60 * 1000
  readonly property string batteryIcon: {
    if (!present) return "󰚥"
    var icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    if (charging) {
      var chargingIcons = ["󰂄", "󰂆", "󰂆", "󰂇", "󰂈", "󰂈", "󰂉", "󰂉", "󰂊", "󰂋", "󰂅"]
      return chargingIcons[Math.max(0, Math.min(10, Math.round(fraction * 10)))]
    }
    return icons[Math.max(0, Math.min(9, Math.floor(fraction * 10)))]
  }
  readonly property real measuredRateWatts: {
    if (energySamples.length < 2) return 0
    var first = energySamples[0]
    var last = energySamples[energySamples.length - 1]
    var hours = (last.timestamp - first.timestamp) / 3600000
    if (hours <= 0) return 0
    return (last.energy - first.energy) / hours
  }
  readonly property real etaSeconds: {
    if (!present) return -1

    // UPower provides the best estimate. timeToEmpty is only populated while
    // discharging; timeToFull is only populated while charging.
    var upowerEta = Number(discharging ? device.timeToEmpty : device.timeToFull)
    if (isFinite(upowerEta) && upowerEta > 0) return upowerEta
    if (charging && fraction >= 0.999) return 0

    // Some firmware/UPower combinations do not report an ETA. Fall back to
    // the live energy rate, then to the samples collected while this panel is
    // open, so the widget still reports an estimate instead of "—".
    var rate = Number(device.changeRate)
    if (!isFinite(rate) || rate === 0)
      rate = measuredRateWatts

    if (charging) {
      var remaining = energyCapacity - currentEnergy
      if (rate > 0 && isFinite(remaining) && remaining > 0)
        return remaining / rate * 3600
    } else if (discharging && rate < 0 && isFinite(currentEnergy) && currentEnergy > 0) {
      return currentEnergy / Math.abs(rate) * 3600
    }

    return -1
  }
  readonly property string healthText: {
    var battery = healthDevice
    if (!present || !battery || !battery.ready) return "—"
    // healthSupported is false for the aggregate display device on some
    // UPower versions even though the physical battery reports Capacity.
    var health = Number(battery.healthPercentage)
    if (!isFinite(health) || health <= 0) return "—"
    return Math.round(health) + "%"
  }

  function formatDuration(seconds) {
    if (seconds < 0) return "—"
    if (seconds === 0) return "Full"
    var minutes = Math.max(1, Math.ceil(seconds / 60))
    var hours = Math.floor(minutes / 60)
    var rest = minutes % 60
    return hours > 0 ? hours + "h " + rest + "m" : minutes + "m"
  }

  function recordEnergySample() {
    if (!root.present || !isFinite(root.currentEnergy)) return

    var now = Date.now()
    var samples = root.energySamples.filter(sample => now - sample.timestamp <= root.sampleWindowMs)
    samples.push({ timestamp: now, energy: root.currentEnergy })
    root.energySamples = samples
  }

  property string activeProfile: ""

  readonly property var profileRows: [
    { id: "power-saver", label: "Power saver", icon: "󰌪" },
    { id: "balanced", label: "Balanced", icon: "󰊚" },
    { id: "performance", label: "Performance", icon: "󰓅" }
  ]

  function refresh() {
    profileProc.running = false
    profileProc.running = true
  }

  function setProfile(profile) {
    if (profileAction.running) return
    profileAction.command = ["powerprofilesctl", "set", profile]
    profileAction.running = true
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
    id: profileAction
    onExited: Qt.callLater(root.refresh)
  }

  Timer {
    id: energyTimer
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.recordEnergySample()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.recordEnergySample()
  onChargingChanged: root.energySamples = []
  onPresentChanged: root.energySamples = []

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
      implicitWidth: content.implicitWidth + theme.popupPadding * 2
      implicitHeight: content.implicitHeight + theme.popupPadding * 2
      width: Math.min(theme.popupWidth, panel.width - theme.popupEdgeMargin * 2)
      height: Math.min(Math.max(620, implicitHeight), panel.height - theme.popupTopMargin - theme.popupEdgeMargin)
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: theme.popupTopMargin
      anchors.rightMargin: theme.popupEdgeMargin
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
        anchors.margins: theme.popupPadding
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Text { text: root.batteryIcon; color: theme.foreground; font.pixelSize: 25 }
          Column {
            spacing: 1
            Text { text: "Battery"; color: theme.foreground; font.pixelSize: root.titleSize; font.weight: Font.Medium }
            Text { text: root.stateText.toUpperCase(); color: theme.muted; font.pixelSize: root.captionSize; font.letterSpacing: 1.1 }
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
              { label: "Battery health", value: root.healthText },
              { label: root.discharging ? "Time left" : "Time to full", value: root.formatDuration(root.etaSeconds) },
              { label: "Power state", value: root.stateText }
            ]
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Text { text: modelData.label; color: theme.muted; font.pixelSize: root.captionSize }
              Item { Layout.fillWidth: true }
              Text { text: modelData.value; color: theme.foreground; font.pixelSize: root.bodySize }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16) }

        Text { text: "POWER PROFILE"; color: theme.muted; font.pixelSize: root.captionSize; font.weight: Font.Medium }

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
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: theme.foreground; font.pixelSize: root.captionSize }
              }
              MouseArea { anchors.fill: parent; enabled: !profileAction.running; onClicked: root.setProfile(modelData.id) }
            }
          }
        }

        Item { Layout.fillHeight: true }
      }
    }
  }
}
