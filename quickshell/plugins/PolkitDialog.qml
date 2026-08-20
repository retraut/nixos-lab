import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

// Adapted from Omarchy's PolkitAgent.qml (MIT); see LICENSES/Omarchy-MIT.txt.

Item {
  id: root

  required property var theme
  property bool closing: false
  property bool submitted: false
  property string feedbackState: "idle"
  readonly property bool failed: feedbackState === "failure"
  readonly property bool succeeded: feedbackState === "success"
  readonly property color feedbackColor: succeeded ? theme.base0B : (failed ? theme.urgent : theme.accent)
  readonly property bool dialogVisible: agent.isActive || closing
  readonly property bool fingerprintMode: dialogVisible && (feedbackState !== "idle" || (!agent.flow?.isResponseRequired && !submitted))

  function authorizationLabel(rawMessage) {
    var text = String(rawMessage || "Authentication required")
    var match = text.match(/^Authentication is (?:needed|required) to run [`']([^`']+)[`'] as /i)
    return match ? "Authorize: " + match[1] : text
  }

  function reset() {
    closing = false
    submitted = false
    feedbackState = "idle"
    password.text = ""
  }

  function focusInput() {
    if (!dialogVisible) return
    if (fingerprintMode) keyCatcher.forceActiveFocus()
    else password.forceActiveFocus()
  }

  function submit() {
    if (!agent.flow?.isResponseRequired) return
    submitted = true
    feedbackState = "idle"
    agent.flow.submit(password.text)
    password.text = ""
    keyCatcher.forceActiveFocus()
  }

  function cancel() {
    password.text = ""
    closing = true
    closeTimer.restart()
    agent.flow?.cancelAuthenticationRequest()
  }

  PolkitAgent {
    id: agent
    path: "/org/nixos/PolkitAgent"

    onAuthenticationRequestStarted: {
      root.reset()
      Qt.callLater(root.focusInput)
    }
    onIsActiveChanged: {
      if (isActive) Qt.callLater(root.focusInput)
      else if (!root.closing) root.reset()
    }
  }

  Connections {
    target: agent.flow

    function onIsResponseRequiredChanged() {
      root.submitted = false
      Qt.callLater(root.focusInput)
    }
    function onAuthenticationFailed() {
      root.submitted = false
      root.feedbackState = "failure"
      password.text = ""
      errorTimer.restart()
      shake.restart()
      Qt.callLater(root.focusInput)
    }
    function onAuthenticationSucceeded() {
      root.feedbackState = "success"
      root.closing = true
      closeTimer.restart()
    }
    function onAuthenticationRequestCancelled() {
      root.closing = true
      closeTimer.restart()
    }
  }

  Timer {
    id: closeTimer
    interval: root.succeeded ? 900 : 240
    onTriggered: root.reset()
  }

  Timer {
    id: errorTimer
    interval: 1100
    onTriggered: {
      root.feedbackState = "idle"
      Qt.callLater(root.focusInput)
    }
  }

  SequentialAnimation {
    id: shake
    NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -8; duration: 40 }
    NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 8; duration: 55 }
    NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 55 }
  }

  PanelWindow {
    id: panel
    visible: root.dialogVisible
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: root.theme.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.focusInput()
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: root.fingerprintMode ? 112 : 344
      height: 112
      radius: 18
      color: root.theme.background
      border.width: 2
      border.color: root.feedbackColor

      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            root.cancel()
            event.accepted = true
          }
        }
      }

      // The same Nerd Font fingerprint glyph used by Omarchy's Polkit UI.
      Text {
        anchors.centerIn: parent
        visible: root.fingerprintMode
        text: "󰈷"
        color: root.feedbackColor
        font.family: root.theme.fontFamily
        font.pixelSize: 62
      }

      Row {
        visible: !root.fingerprintMode
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        Text {
          width: 34
          height: parent.height
          text: ""
          color: root.feedbackColor
          font.family: root.theme.fontFamily
          font.pixelSize: 24
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Item {
          width: parent.width - 52
          height: parent.height

          TextInput {
            id: password
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            color: root.failed ? root.theme.urgent : root.theme.foreground
            selectionColor: root.theme.accent
            font.family: root.theme.fontFamily
            font.pixelSize: 20
            echoMode: agent.flow?.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            readOnly: root.submitted || root.failed
            onAccepted: root.submit()
            Keys.onEscapePressed: root.cancel()
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: password.text.length === 0
            text: root.failed ? "Wrong" : (root.submitted ? "Checking…" : "Enter password")
            color: root.failed ? root.theme.urgent : root.theme.muted
            font.family: root.theme.fontFamily
            font.pixelSize: 20
          }
        }
      }
    }

    Rectangle {
      anchors.horizontalCenter: card.horizontalCenter
      anchors.bottom: card.top
      anchors.bottomMargin: 10
      width: Math.min(760, panel.width - 40)
      height: Math.max(34, message.implicitHeight + 18)
      radius: 12
      color: root.theme.background

      Text {
        id: message
        anchors.fill: parent
        anchors.margins: 9
        text: root.authorizationLabel(agent.flow?.message)
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WrapAnywhere
      }
    }
  }
}
