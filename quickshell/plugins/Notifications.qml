import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

Item {
  id: root

  property var theme: null
  property bool centerOpen: false
  property bool doNotDisturb: false
  property bool dndToastVisible: false
  property var liveNotifications: ({})
  readonly property int historyLimit: 50

  ListModel { id: popupModel }
  ListModel { id: historyModel }

  function plainText(value) {
    return String(value || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&")
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
    dismissPopup(uid)
  }

  function clearHistory() {
    while (historyModel.count > 0) {
      root.release(historyModel.get(0).uid)
      historyModel.remove(0)
    }
    popupModel.clear()
  }

  function toggleDoNotDisturb() {
    root.doNotDisturb = !root.doNotDisturb
    if (root.doNotDisturb) popupModel.clear()
    root.dndToastVisible = true
    dndToastTimer.restart()
    return root.doNotDisturb
  }

  Timer {
    id: dndToastTimer
    interval: 2400
    onTriggered: root.dndToastVisible = false
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
        width: 430
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 44
        anchors.rightMargin: 12
        spacing: 8

        Rectangle {
          width: toastColumn.width
          height: 72
          visible: root.dndToastVisible
          color: root.theme ? Qt.rgba(root.theme.background.r, root.theme.background.g, root.theme.background.b, 0.97) : "#101315"
          border.width: 2
          border.color: root.theme ? root.theme.accent : "#7aa2f7"
          radius: 0

          Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.doNotDisturb ? "󰂛" : "󰂚"
              color: root.theme ? root.theme.accent : "#7aa2f7"
              font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
              font.pixelSize: 28
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 3

              Text {
                text: "Do Not Disturb"
                color: root.theme ? root.theme.foreground : "#c0caf5"
                font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                font.bold: true
              }

              Text {
                text: root.doNotDisturb ? "Enabled — notifications are muted" : "Disabled — notifications are visible"
                color: root.theme ? root.theme.muted : "#9aa5ce"
                font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 13
              }
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

              Text {
                width: parent.width
                text: app
                color: root.theme ? root.theme.accent : "#7aa2f7"
                font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                elide: Text.ElideRight
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
      width: 560
      height: Math.min(760, parent.height - 64)
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 44
      anchors.rightMargin: 12
      color: root.theme ? root.theme.background : "#101315"
      border.width: 2
      border.color: root.theme ? root.theme.border : "#414868"
      radius: 0

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
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
            width: dndText.implicitWidth + 18
            height: 34
            color: root.doNotDisturb && root.theme ? root.theme.selected : (root.theme ? root.theme.panel : "#24283b")
            border.width: 1
            border.color: root.theme ? root.theme.border : "#414868"
            Text {
              id: dndText
              anchors.centerIn: parent
              text: root.doNotDisturb ? "DND ON" : "DND"
              color: root.theme ? root.theme.foreground : "#c0caf5"
              font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
              font.pixelSize: 14
            }
            MouseArea { anchors.fill: parent; onClicked: root.toggleDoNotDisturb() }
          }
          Rectangle {
            width: clearText.implicitWidth + 18
            height: 34
            color: root.theme ? root.theme.panel : "#24283b"
            border.width: 1
            border.color: root.theme ? root.theme.border : "#414868"
            Text {
              id: clearText
              anchors.centerIn: parent
              text: "Clear"
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
          text: root.doNotDisturb ? "Do Not Disturb is enabled" : "No notifications yet"
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
                  width: parent.width - timeLabel.width - 12
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
