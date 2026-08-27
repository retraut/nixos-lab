import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

Item {
  id: root

  property var theme: null
  property var dndState: null
  property bool centerOpen: false
  readonly property bool doNotDisturb: dndState ? dndState.doNotDisturb : false
  property bool dndToastVisible: false
  property var liveNotifications: ({})
  readonly property int historyLimit: 50

  ListModel { id: popupModel }
  ListModel { id: historyModel }

  onDoNotDisturbChanged: {
    if (root.doNotDisturb) popupModel.clear()
    root.dndToastVisible = true
    dndToastTimer.restart()
  }

  Timer {
    id: dndToastTimer
    interval: 2200
    onTriggered: root.dndToastVisible = false
  }

  function plainText(value) {
    return String(value || "")
      // Terminal applications may accidentally include ANSI CSI/OSC escape
      // sequences in a desktop notification. Keep Ghostty notifications
      // enabled, but never render those control sequences in the shell UI.
      .replace(/\u001b\][^\u0007]*(?:\u0007|\u001b\\)/g, "")
      .replace(/\u001b\[[0-?]*[ -/]*[@-~]/g, "")
      .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f-\u009f]/g, "")
      .replace(/<[^>]*>/g, "")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .trim()
  }

  function addNotification(notification) {
    notification.tracked = true
    var timestamp = Date.now()
    var uid = String(notification.id || 0) + "-" + timestamp
    var entry = {
      uid: uid,
      app: String(notification.appName || "Notification"),
      summary: plainText(notification.summary),
      body: plainText(notification.body),
      urgency: Number(notification.urgency || 0),
      timestamp: timestamp
    }

    root.liveNotifications[uid] = notification
    historyModel.insert(0, entry)
    while (historyModel.count > root.historyLimit) {
      var old = historyModel.get(historyModel.count - 1)
      root.release(old.uid)
      historyModel.remove(historyModel.count - 1)
    }

    if (!root.doNotDisturb) {
      popupModel.insert(0, entry)
      while (popupModel.count > 4) popupModel.remove(popupModel.count - 1)
    }
  }

  function popupIndex(uid) {
    for (var i = 0; i < popupModel.count; i++) {
      if (popupModel.get(i).uid === uid) return i
    }
    return -1
  }

  function dismissPopup(uid) {
    var index = popupIndex(uid)
    if (index >= 0) popupModel.remove(index)
  }

  function release(uid) {
    var ref = root.liveNotifications[uid]
    if (!ref) return
    try { ref.tracked = false } catch (e) {}
    delete root.liveNotifications[uid]
  }

  function focusSource(uid) {
    var ref = root.liveNotifications[uid]
    if (!ref) return

    var source = [ref.appName, ref.desktopEntry, ref.summary, ref.body].join(" ").toLowerCase()
    if (!source.match(/ghostty|codex/)) return

    Quickshell.execDetached([
      Quickshell.env("HOME") + "/.local/bin/nixos-desktop-daemon",
      "focus-notification",
      String(ref.appName || ""),
      String(ref.desktopEntry || ""),
      String(ref.summary || ""),
      String(ref.body || "")
    ])
  }

  function removeNotification(uid) {
    var ref = root.liveNotifications[uid]
    if (ref) {
      try { ref.dismiss() } catch (e) {}
    }

    root.dismissPopup(uid)
    for (var i = 0; i < historyModel.count; i++) {
      if (historyModel.get(i).uid === uid) {
        historyModel.remove(i)
        break
      }
    }
    root.release(uid)
  }

  function invokeDefault(uid) {
    var ref = root.liveNotifications[uid]
    try {
      if (ref && ref.actions) {
        for (var i = 0; i < ref.actions.length; i++) {
          if (ref.actions[i] && ref.actions[i].identifier === "default") {
            ref.actions[i].invoke()
            break
          }
        }
      }
    } catch (e) {}
    root.focusSource(uid)
    root.removeNotification(uid)
  }

  function clearHistory() {
    while (historyModel.count > 0) {
      root.release(historyModel.get(0).uid)
      historyModel.remove(0)
    }
    popupModel.clear()
  }

  function toggleDoNotDisturb() {
    if (!root.dndState) return false
    root.dndState.doNotDisturb = !root.dndState.doNotDisturb
    if (root.doNotDisturb) popupModel.clear()
    return root.doNotDisturb
  }

  NotificationServer {
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: false
    persistenceSupported: true
    onNotification: notification => root.addNotification(notification)
  }

  IpcHandler {
    target: "nixos-notifications"

    function toggleCenter(): string {
      root.centerOpen = !root.centerOpen
      return root.centerOpen ? "open" : "closed"
    }

    function toggleDnd(): string {
      return root.toggleDoNotDisturb() ? "on" : "off"
    }

    function clear(): string {
      root.clearHistory()
      return "ok"
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: popupModel.count > 0 || root.dndToastVisible
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "nixos-notifications"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region { item: toastColumn }

      Column {
        id: toastColumn
        width: Math.min(root.theme ? root.theme.popupWidth : 560, parent.width - 24)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.theme ? root.theme.popupTopMargin : 44
        anchors.rightMargin: root.theme ? root.theme.popupEdgeMargin : 12
        spacing: 8

        Rectangle {
          width: toastColumn.width
          height: 64
          visible: root.dndToastVisible
          color: root.theme ? Qt.rgba(root.theme.background.r, root.theme.background.g, root.theme.background.b, 0.97) : "#101315"
          border.width: 2
          border.color: root.doNotDisturb
            ? (root.theme ? root.theme.urgent : "#f7768e")
            : (root.theme ? root.theme.accent : "#7aa2f7")
          radius: 0

          Row {
            anchors.centerIn: parent
            spacing: 14

            Text {
              text: root.doNotDisturb ? "󰂛" : "󰂚"
              color: root.doNotDisturb
                ? (root.theme ? root.theme.urgent : "#f7768e")
                : (root.theme ? root.theme.accent : "#7aa2f7")
              font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
              font.pixelSize: 28
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.doNotDisturb ? "Do Not Disturb enabled" : "Do Not Disturb disabled"
              color: root.theme ? root.theme.foreground : "#c0caf5"
              font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
              font.pixelSize: 17
              font.bold: true
            }
          }
        }

        Repeater {
          model: popupModel

          delegate: Rectangle {
            required property string uid
            required property string app
            required property string summary
            required property string body
            required property int urgency
            width: toastColumn.width
            height: toastContent.implicitHeight + 24
            color: root.theme ? Qt.rgba(root.theme.background.r, root.theme.background.g, root.theme.background.b, 0.97) : "#101315"
            border.width: 2
            border.color: urgency >= 2 && root.theme ? root.theme.urgent : (root.theme ? root.theme.border : "#414868")
            radius: 0

            Timer {
              interval: 8000
              running: urgency < 2
              onTriggered: root.dismissPopup(uid)
            }

            Column {
              id: toastContent
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 4

              Row {
                width: parent.width
                spacing: 8

                Text {
                  width: parent.width - dismissButton.width - parent.spacing
                  text: app
                  color: root.theme ? root.theme.accent : "#7aa2f7"
                  font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                  font.pixelSize: 12
                  elide: Text.ElideRight
                }

                Rectangle {
                  id: dismissButton
                  width: 22
                  height: 22
                  color: dismissMouse.containsMouse
                    ? (root.theme ? root.theme.selected : "#24283b")
                    : "transparent"
                  border.width: 1
                  border.color: root.theme ? root.theme.border : "#414868"

                  Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: root.theme ? root.theme.muted : "#9aa5ce"
                    font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                  }

                  MouseArea {
                    id: dismissMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    onClicked: root.removeNotification(uid)
                  }
                }
              }
              Text {
                width: parent.width
                text: summary
                color: root.theme ? root.theme.foreground : "#c0caf5"
                font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                font.bold: true
                wrapMode: Text.Wrap
              }
              Text {
                width: parent.width
                visible: body.length > 0
                text: body
                color: root.theme ? root.theme.muted : "#9aa5ce"
                font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: mouse => {
                if (mouse.button === Qt.RightButton) root.dismissPopup(uid)
                else root.invokeDefault(uid)
              }
            }
          }
        }
      }
    }
  }

  PanelWindow {
    visible: root.centerOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: root.centerOpen = false }

    Rectangle {
      width: Math.min(root.theme ? root.theme.popupWidth : 560, parent.width - 24)
      height: Math.min(760, parent.height - 64)
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: root.theme ? root.theme.popupTopMargin : 44
      anchors.rightMargin: root.theme ? root.theme.popupEdgeMargin : 12
      color: root.theme ? root.theme.background : "#101315"
      border.width: 2
      border.color: root.theme ? root.theme.border : "#414868"
      radius: 0

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.theme ? root.theme.popupPadding : 20
        spacing: 12

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Notifications"
            color: root.theme ? root.theme.foreground : "#c0caf5"
            font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
            font.pixelSize: 24
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            width: clearText.implicitWidth + 18
            height: 34
            color: root.theme ? root.theme.panel : "#24283b"
            border.width: 1
            border.color: root.theme ? root.theme.border : "#414868"
            Text {
              id: clearText
              anchors.centerIn: parent
              text: "Clear All"
              color: root.theme ? root.theme.foreground : "#c0caf5"
              font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
              font.pixelSize: 14
            }
            MouseArea { anchors.fill: parent; onClicked: root.clearHistory() }
          }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          visible: historyModel.count === 0
          text: "No notifications yet"
          color: root.theme ? root.theme.muted : "#9aa5ce"
          font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
          font.pixelSize: 18
        }

        ListView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 8
          model: historyModel

          delegate: Rectangle {
            required property string uid
            required property string app
            required property string summary
            required property string body
            required property double timestamp
            width: ListView.view.width
            height: historyContent.implicitHeight + 24
            color: historyMouse.containsMouse && root.theme ? root.theme.selected : (root.theme ? root.theme.panel : "#24283b")
            border.width: 1
            border.color: root.theme ? root.theme.border : "#414868"
            radius: 0

            Column {
              id: historyContent
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 4
              Row {
                width: parent.width
                Text {
                  width: parent.width - timeLabel.width - dismissHistoryButton.width - 20
                  text: app
                  color: root.theme ? root.theme.accent : "#7aa2f7"
                  font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                  font.pixelSize: 12
                  elide: Text.ElideRight
                }
                Text {
                  id: timeLabel
                  text: Qt.formatTime(new Date(timestamp), "HH:mm")
                  color: root.theme ? root.theme.muted : "#9aa5ce"
                  font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                  font.pixelSize: 12
                }
                Rectangle {
                  id: dismissHistoryButton
                  width: 22
                  height: 22
                  color: dismissHistoryMouse.containsMouse
                    ? (root.theme ? root.theme.selected : "#24283b")
                    : "transparent"
                  border.width: 1
                  border.color: root.theme ? root.theme.border : "#414868"

                  Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: root.theme ? root.theme.muted : "#9aa5ce"
                    font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                  }

                  MouseArea {
                    id: dismissHistoryMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    onClicked: root.removeNotification(uid)
                  }
                }
              }
              Text {
                width: parent.width
                text: summary
                color: root.theme ? root.theme.foreground : "#c0caf5"
                font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                font.bold: true
                wrapMode: Text.Wrap
              }
              Text {
                width: parent.width
                visible: body.length > 0
                text: body
                color: root.theme ? root.theme.muted : "#9aa5ce"
                font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: historyMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.invokeDefault(uid)
            }
          }
        }
      }

      Keys.onEscapePressed: root.centerOpen = false
    }
  }
}
