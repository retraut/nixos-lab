import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// NixOS-native port of the live Omarchy Agents dashboard. The collector is
// Python and emits one stable JSON record; this file only renders it.
ShellRoot {
  id: root

  Theme { id: theme }
  property var usage: ({})
  readonly property int bodySize: 16
  readonly property int captionSize: 13
  readonly property int sectionSize: 14
  readonly property int titleSize: 20

  function parseUsage(raw) {
    try { root.usage = JSON.parse(String(raw || "").trim()) || ({}) }
    catch (e) { root.usage = ({}) }
  }

  function formatTokens(value) {
    var n = Number(value || 0)
    if (n >= 1000000000) return (n / 1000000000).toFixed(1) + "B"
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(1) + "K"
    return String(Math.round(n))
  }

  function formatPercent(value) {
    return Math.round(Number(value || 0) * 100) + "%"
  }

  function formatReset(value) {
    var target = new Date(String(value || "")).getTime()
    if (!isFinite(target)) return ""
    var minutes = Math.max(0, Math.floor((target - Date.now()) / 60000))
    var days = Math.floor(minutes / 1440)
    var hours = Math.floor((minutes % 1440) / 60)
    if (days > 0) return "Resets in " + days + "d " + hours + "h"
    if (hours > 0) return "Resets in " + hours + "h " + (minutes % 60) + "m"
    return "Resets soon"
  }

  function modelRows() {
    var source = root.usage.modelUsage || ({})
    var rows = []
    for (var name in source) {
      var bucket = source[name] || ({})
      rows.push({
        name: name,
        total: Number(bucket.inputTokens || 0) + Number(bucket.outputTokens || 0)
          + Number(bucket.cacheReadInputTokens || 0) + Number(bucket.cacheCreationInputTokens || 0)
      })
    }
    rows.sort(function(a, b) { return b.total - a.total })
    return rows.slice(0, 4)
  }

  Process {
    id: usageProcess
    command: ["sh", "-lc", "exec \"$HOME/.local/bin/nixos-agent-usage\""]
    running: true
    stdout: StdioCollector { id: usageOutput }
    onExited: root.parseUsage(usageOutput.text)
  }

  Timer {
    interval: 900000
    repeat: true
    running: true
    onTriggered: {
      usageProcess.running = false
      usageProcess.running = true
    }
  }

  PanelWindow {
    id: panel
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-agents"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

    Rectangle {
      id: card
      implicitWidth: content.implicitWidth + 40
      implicitHeight: content.implicitHeight + 40
      width: Math.min(Math.max(480, implicitWidth), 900)
      height: Math.min(Math.max(300, implicitHeight), 900)
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
        if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true }
      }

      ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Image {
            source: Qt.resolvedUrl("assets/agents/codex.svg")
            sourceSize.width: 38
            sourceSize.height: 38
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            fillMode: Image.PreserveAspectFit
          }

          Column {
            spacing: 1
            Text { text: "Codex"; color: theme.foreground; font.pixelSize: root.titleSize; font.weight: Font.Medium }
            Text { text: root.usage.tierLabel || "Subscription"; color: theme.foreground; font.pixelSize: root.bodySize; font.weight: Font.Medium }
          }

          Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16) }

        Text { visible: (root.usage.limits || []).length > 0; text: "LIMITS"; color: theme.foreground; font.pixelSize: root.sectionSize; font.weight: Font.Medium }

        Repeater {
          model: root.usage.limits || []
          delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              Text { text: modelData.title || "Weekly"; color: theme.foreground; font.pixelSize: root.bodySize }
              Item { Layout.fillWidth: true }
              Text { text: root.formatPercent(modelData.percent); color: theme.foreground; font.pixelSize: root.captionSize }
            }

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 5
              color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.20)
              Rectangle { width: parent.width * Math.max(0, Math.min(1, Number(modelData.percent || 0))); height: parent.height; color: theme.foreground }
            }

            Text { text: root.formatReset(modelData.resetsAt); color: theme.muted; font.pixelSize: root.captionSize }
          }
        }

        Rectangle { visible: (root.usage.recentDays || []).length > 0; Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16) }
        Text { visible: (root.usage.recentDays || []).length > 0; text: "TOKENS BY DAY"; color: theme.foreground; font.pixelSize: root.sectionSize; font.weight: Font.Medium }

        Repeater {
          model: root.usage.recentDays || []
          delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 10
            Text { Layout.preferredWidth: 56; text: modelData.date === root.usage.recentDays[root.usage.recentDays.length - 1].date ? "Today" : modelData.date.slice(5); color: theme.foreground; font.pixelSize: root.captionSize }
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 5
              color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.20)
              Rectangle {
                width: {
                  var peak = 1
                  var days = root.usage.recentDays || []
                  for (var i = 0; i < days.length; i++) peak = Math.max(peak, Number(days[i].messageCount || 0))
                  return parent.width * Number(modelData.messageCount || 0) / peak
                }
                height: parent.height
                color: theme.muted
              }
            }
            Text { Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight; text: root.formatTokens(modelData.messageCount); color: theme.foreground; font.pixelSize: root.captionSize }
          }
        }

        Rectangle { visible: root.modelRows().length > 0; Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16) }
        Text { visible: root.modelRows().length > 0; text: "TOKENS BY MODEL"; color: theme.foreground; font.pixelSize: root.sectionSize; font.weight: Font.Medium }

        Repeater {
          model: root.modelRows()
          delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: modelData.name; color: theme.foreground; font.pixelSize: root.bodySize; elide: Text.ElideRight }
            Text { text: root.formatTokens(modelData.total); color: theme.foreground; font.pixelSize: root.bodySize }
          }
        }

        Text {
          visible: !root.usage.ready
          Layout.fillWidth: true
          text: root.usage.usageStatusText || "No Codex usage data found"
          color: theme.muted
          font.pixelSize: root.bodySize
          horizontalAlignment: Text.AlignHCenter
        }

        Item { Layout.fillHeight: true }
      }
    }
  }
}
