import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Compact keyboard layout indicator. It reads the active layout from the
// keyboard Hyprland marks as main and cycles layouts on click.
BarWidget {
  id: root

  signal activated()
  property var theme: null
  property color textColor: theme ? theme.foreground : "#cacccc"
  property color hoverColor: theme ? theme.panel : "#1e2327"
  property int fontSize: 12
  property string fontFamily: "JetBrainsMono Nerd Font"
  property string layoutText: "ENG"
  property string layoutFull: "English (US)"
  property string keyboardName: ""
  property int layoutIndex: 0
  property bool multipleLayouts: true
  property bool hovered: button.containsMouse

  visible: root.multipleLayouts

  function shortLabel(keymap, index) {
    var value = String(keymap || "").toLowerCase()
    if (value.indexOf("ukrain") !== -1 || value.indexOf("uk") !== -1) return "UKR"
    if (value.indexOf("english") !== -1 || value.indexOf("us") !== -1) return "ENG"
    var layouts = ["ENG", "UKR"]
    return layouts[index] || String(keymap || "???").split(/\s+/)[0].substring(0, 3).toUpperCase()
  }

  function refresh() {
    if (!query.running) query.running = true
  }

  function cycle() {
    if (root.keyboardName)
      switchLayout.command = ["hyprctl", "switchxkblayout", root.keyboardName, "next"]
    else
      switchLayout.command = ["hyprctl", "switchxkblayout", "main", "next"]
    switchLayout.running = true
    refreshTimer.restart()
  }

  Component.onCompleted: refresh()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      if (String(event.name).indexOf("activelayout") !== -1 || event.name === "configreloaded")
        root.refresh()
    }
  }

  Process {
    id: query
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var keyboards = JSON.parse(String(text || "{}")).keyboards || []
          var typed = keyboards.filter(function(k) {
            var name = String(k.name || "").toLowerCase()
            return name.indexOf("power") === -1 && name.indexOf("sleep") === -1 && name.indexOf("button") === -1
          })
          if (typed.length === 0) return
          var keyboard = typed.find(function(k) { return k.main }) || typed[0]
          root.keyboardName = String(keyboard.name || "")
          root.layoutIndex = Number(keyboard.active_layout_index || 0)
          root.layoutFull = String(keyboard.active_keymap || "")
          root.layoutText = root.shortLabel(root.layoutFull, root.layoutIndex)
          root.multipleLayouts = String(keyboard.layout || "").indexOf(",") !== -1
        } catch (e) {
          // Keep the last good label during a transient Hyprland IPC failure.
        }
      }
    }
  }

  Process { id: switchLayout }

  Timer {
    id: refreshTimer
    interval: 250
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    text: root.layoutText
    foreground: root.textColor
    hoverColor: root.hoverColor
    fontSize: root.fontSize
    fontFamily: root.fontFamily
    onPressed: root.cycle()
  }
}
