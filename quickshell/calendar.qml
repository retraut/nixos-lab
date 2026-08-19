import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  Theme { id: theme }
  property date displayedMonth: new Date()
  property bool opened: Quickshell.env("NIXOS_CALENDAR_OPEN") === "1"

  function monthTitle() { return Qt.formatDateTime(root.displayedMonth, "MMMM yyyy") }
  function daysInMonth(date) { return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate() }
  function firstDay(date) { return new Date(date.getFullYear(), date.getMonth(), 1).getDay() }
  function shiftMonth(delta) {
    root.displayedMonth = new Date(root.displayedMonth.getFullYear(), root.displayedMonth.getMonth() + delta, 1)
  }
  function close() { root.opened = false }

  IpcHandler {
    target: "nixos-calendar"

    function open(): void { root.opened = true }
    function close(): void { root.close() }
    function toggle(): void { root.opened = !root.opened }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-calendar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle { anchors.fill: parent; color: "transparent"; MouseArea { anchors.fill: parent; onClicked: root.close() } }

    Rectangle {
      id: card
      implicitWidth: content.implicitWidth + 36
      implicitHeight: content.implicitHeight + 36
      width: Math.min(Math.max(366, implicitWidth), 900)
      height: Math.min(Math.max(396, implicitHeight), 900)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 44
      radius: 0
      color: theme.background
      border.width: 1
      border.color: theme.border
      focus: true
      MouseArea { anchors.fill: parent; onClicked: {} }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
        if (event.key === Qt.Key_Left) { root.shiftMonth(-1); event.accepted = true }
        if (event.key === Qt.Key_Right) { root.shiftMonth(1); event.accepted = true }
      }

      ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        spacing: 12

        RowLayout {
          Layout.fillWidth: true
          Text { text: "Calendar"; color: theme.foreground; font.pixelSize: theme.widgetFontSize; font.weight: Font.Medium }
          Item { Layout.fillWidth: true }
        }

        RowLayout {
          Layout.fillWidth: true
          Rectangle {
            implicitWidth: 30; implicitHeight: 28; radius: 0; color: theme.panel
            Text { anchors.centerIn: parent; text: "‹"; color: theme.accent; font.pixelSize: 20 }
            MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(-1) }
          }
          Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.monthTitle(); color: theme.brightForeground; font.pixelSize: theme.widgetFontSize }
          Rectangle {
            implicitWidth: 30; implicitHeight: 28; radius: 0; color: theme.panel
            Text { anchors.centerIn: parent; text: "›"; color: theme.accent; font.pixelSize: 20 }
            MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(1) }
          }
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 7
          rowSpacing: 5
          columnSpacing: 5

          Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            Text { required property string modelData; text: modelData; color: theme.muted; font.pixelSize: theme.widgetFontSize; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
          }

          Repeater {
            model: 42
            delegate: Rectangle {
              required property int index
              readonly property int day: index - root.firstDay(root.displayedMonth) + 1
              readonly property bool validDay: day > 0 && day <= root.daysInMonth(root.displayedMonth)
              readonly property bool today: validDay && day === new Date().getDate() && root.displayedMonth.getMonth() === new Date().getMonth() && root.displayedMonth.getFullYear() === new Date().getFullYear()
              Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 0
              color: today ? theme.accent : (validDay ? theme.panel : "transparent")
              Text { anchors.centerIn: parent; text: parent.validDay ? parent.day : ""; color: parent.today ? theme.background : theme.foreground; font.pixelSize: theme.widgetFontSize }
            }
          }
        }

        Item { Layout.fillHeight: true }
        Text { Layout.alignment: Qt.AlignHCenter; text: "Use ← / → to change month"; color: theme.muted; font.pixelSize: theme.widgetFontSize }
      }
    }
  }
}
