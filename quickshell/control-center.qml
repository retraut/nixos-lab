import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// NixOS-native port of the live retraut.control-center.  Its typography is
// intentionally independent from the 150% launcher scale: this is a compact
// information surface, not a search UI.
ShellRoot {
  id: root

  Theme { id: theme }

  property var stats: ({})
  property string activePanel: ""
  readonly property int textSmall: 13
  readonly property int textBody: 15
  readonly property int textTitle: 18
  readonly property var controlItems: {
    var caps = root.stats.capabilities || ({})
    return [
      { label: "Wi-Fi", icon: "󰖩", kind: "wifi", available: caps.wifi === true,
        detail: caps.wifi === true ? "Networks" : "No adapter in VM" },
      { label: "Bluetooth", icon: "󰂯", kind: "bluetooth", available: caps.bluetooth === true,
        detail: caps.bluetooth === true ? "Devices" : "No adapter in VM" },
      { label: "Audio", icon: "󰕾", kind: "volume", available: true, detail: "Output & input" },
      { label: "Display", icon: "󰍹", kind: "display", available: true, detail: "Monitors & brightness" },
      { label: "Tailscale", icon: "󰒍", kind: "tailscale", available: caps.tailscale === true,
        detail: caps.tailscale === true ? "Tailnet" : "Not installed" },
      { label: "Power", icon: "󰌪", kind: "power", available: true, detail: "Performance profile" }
    ]
  }

  function parseStats(raw) {
    try { root.stats = JSON.parse(String(raw || "").trim()) || ({}) }
    catch (e) { root.stats = ({}) }
  }

  function close() { Qt.quit() }
  function openPanel(kind) { root.activePanel = kind }
  function closePanel() { root.activePanel = "" }

  IpcHandler {
    target: "nixos-control-center"
    function panel(kind: string): string {
      root.openPanel(kind)
      return root.activePanel
    }
    function dashboard(): string {
      root.closePanel()
      return "ok"
    }
    function dismiss(): string {
      root.close()
      return "ok"
    }
  }

  Process {
    id: statsProcess
    command: ["sh", "-lc", "exec \"$HOME/.local/bin/nixos-system-stats\""]
    running: true
    stdout: StdioCollector { id: statsOutput }
    onExited: root.parseStats(statsOutput.text)
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: if (!statsProcess.running) statsProcess.running = true
  }

  PanelWindow {
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-control-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
      id: card
      width: 480
      height: root.activePanel === "" ? 540 : 610
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 44
      anchors.rightMargin: 12
      color: theme.background
      border.width: 1
      border.color: theme.border
      radius: 0
      focus: true

      MouseArea { anchors.fill: parent; onClicked: {} }
      Keys.onPressed: function(event) {
        if (event.key !== Qt.Key_Escape) return
        if (root.activePanel !== "") root.closePanel()
        else root.close()
        event.accepted = true
      }

      ColumnLayout {
        id: dashboard
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10
        visible: root.activePanel === ""

        RowLayout {
          Layout.fillWidth: true
          spacing: 12
          Text {
            text: "󰒓"
            color: theme.accent
            font.family: theme.fontFamily
            font.pixelSize: 28
          }
          Column {
            spacing: 1
            Text {
              text: "Control Center"
              color: theme.foreground
              font.family: theme.fontFamily
              font.pixelSize: root.textTitle
              font.weight: Font.DemiBold
            }
            Text {
              text: "QUICK CONTROLS"
              color: theme.muted
              font.family: theme.fontFamily
              font.pixelSize: root.textSmall
              font.letterSpacing: 1.2
            }
          }
          Item { Layout.fillWidth: true }
        }

        Text {
          text: "SYSTEM"
          color: theme.muted
          font.family: theme.fontFamily
          font.pixelSize: root.textSmall
          font.weight: Font.Medium
          font.letterSpacing: 0.8
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: 24
          rowSpacing: 5

          Repeater {
            model: [
              { label: "CPU", value: root.stats.cpu !== undefined ? root.stats.cpu + "%" : "…" },
              { label: "Temp", value: root.stats.temp !== undefined ? root.stats.temp + "°" : "…" },
              { label: "RAM", value: root.stats.mem ? root.stats.mem.percent + "%" : "…" },
              { label: "Swap", value: root.stats.mem ? root.stats.mem.swapPercent + "%" : "…" },
              { label: "Storage", value: root.stats.storage !== undefined && root.stats.storage !== null ? root.stats.storage + "%" : "…" },
              { label: "Power", value: root.stats.power !== undefined && root.stats.power !== null ? root.stats.power + "W" : "AC" }
            ]
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Text { text: modelData.label; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: root.textSmall }
              Item { Layout.fillWidth: true }
              Text { text: modelData.value; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: root.textBody }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.14) }

        Text {
          text: root.stats.power !== undefined && root.stats.power !== null ? "TOP POWER · EST." : "TOP CPU"
          color: theme.muted
          font.family: theme.fontFamily
          font.pixelSize: root.textSmall
          font.weight: Font.Medium
          font.letterSpacing: 0.8
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 3
          Repeater {
            model: root.stats.topProcesses || []
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Text {
                text: modelData.name
                color: theme.foreground
                opacity: 0.82
                font.family: theme.fontFamily
                font.pixelSize: root.textSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              Text {
                visible: modelData.w !== undefined && modelData.w !== null
                text: visible ? Number(modelData.w).toFixed(1) + "W" : ""
                color: theme.foreground
                font.family: theme.fontFamily
                font.pixelSize: root.textSmall
                Layout.preferredWidth: 58
                horizontalAlignment: Text.AlignRight
              }
              Text {
                text: Number(modelData.cpu || 0).toFixed(1) + "%"
                color: theme.foreground
                font.family: theme.fontFamily
                font.pixelSize: root.textSmall
                Layout.preferredWidth: 58
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.14) }

        Text {
          text: "CONTROLS"
          color: theme.muted
          font.family: theme.fontFamily
          font.pixelSize: root.textSmall
          font.weight: Font.Medium
          font.letterSpacing: 0.8
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: 8
          rowSpacing: 8

          Repeater {
            model: root.controlItems
            delegate: Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: 54
              color: tileMouse.containsMouse ? theme.selected : theme.panel
              border.width: 1
              border.color: tileMouse.containsMouse ? theme.accent : theme.border
              radius: 0

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 10
                Text {
                  text: modelData.icon
                  color: modelData.available ? theme.accent : theme.muted
                  font.family: theme.fontFamily
                  font.pixelSize: 20
                  Layout.preferredWidth: 24
                  horizontalAlignment: Text.AlignHCenter
                }
                Column {
                  Layout.fillWidth: true
                  spacing: 1
                  Text { text: modelData.label; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: root.textBody }
                  Text { text: modelData.detail; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                }
                Text { text: "›"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 18 }
              }

              MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openPanel(modelData.kind)
              }
            }
          }
        }

        Item { Layout.fillHeight: true }
      }

      Loader {
        id: detailsLoader
        anchors.fill: parent
        anchors.margins: 18
        active: root.activePanel !== ""
        source: Qt.resolvedUrl("control-panel.qml")
        onLoaded: if (item) item.panelKind = root.activePanel
      }

      Connections {
        target: root
        function onActivePanelChanged() {
          if (detailsLoader.item) detailsLoader.item.panelKind = root.activePanel
        }
      }

      Connections {
        target: detailsLoader.item
        function onCloseRequested() { root.closePanel() }
      }
    }
  }
}
