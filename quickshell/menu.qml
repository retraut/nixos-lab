import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// NixOS-native root menu modeled after Omarchy's centered menu surface.
// Rows are intentionally data-driven so future entries can be added without
// touching the bar widget or the popup shell.
ShellRoot {
  id: root

  Theme { id: theme }

  readonly property var items: [
    { title: "Clipboard history", detail: "Super + Shift + V", icon: "󰅍", command: ["nixos-clipboard"] },
    { title: "Emoji picker", detail: "Super + Ctrl + Space", icon: "󰞅", command: ["nixos-emoji"] },
    { title: "Screenshot region", detail: "Print", icon: "󰹑", command: ["nixos-capture", "region"] },
    { title: "Screenshot window", detail: "Super + Print", icon: "󱣴", command: ["nixos-capture", "window"] },
    { title: "Screenshot fullscreen", detail: "Shift + Print", icon: "󰍹", command: ["nixos-capture", "fullscreen"] },
    { title: "Notifications", detail: "Super + N", icon: "󰂚", command: ["quickshell", "ipc", "--path", Quickshell.env("HOME") + "/.config/quickshell/shell.qml", "call", "nixos-notifications", "toggleCenter"] },
    { title: "Lock session", detail: "Super + Escape", icon: "󰌾", command: ["nixos-lock"] }
  ]

  function close() { Qt.quit() }

  PanelWindow {
    id: panel
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
      id: card
      implicitWidth: content.implicitWidth + 32
      implicitHeight: content.implicitHeight + 32
      width: Math.min(Math.max(520, implicitWidth), 1200)
      height: Math.min(Math.max(186, implicitHeight), 900)
      anchors.centerIn: parent
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
        anchors.margins: 16
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Text { text: "Menu"; color: theme.foreground; font.pixelSize: theme.widgetFontSize; font.weight: Font.Medium }
          Item { Layout.fillWidth: true }
        }

        Repeater {
          model: root.items
          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: Math.max(50, menuInfo.implicitHeight + 24)
            radius: 0
            color: rowMouse.containsMouse ? theme.selected : theme.panel
            border.width: 1
            border.color: theme.border

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 10
              Text { text: modelData.icon; color: theme.accent; font.pixelSize: 18 }
              Column {
                id: menuInfo
                Layout.fillWidth: true
                spacing: 2
              Text { text: modelData.title; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
                Text { text: modelData.detail; color: theme.muted; font.pixelSize: theme.widgetFontSize; elide: Text.ElideRight; width: parent.width }
              }
              Text { text: "→"; color: theme.muted; font.pixelSize: theme.widgetFontSize }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                Quickshell.execDetached(modelData.command)
                root.close()
              }
            }
          }
        }
      }
    }
  }
}
