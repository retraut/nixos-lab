import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
  id: page

  property string panelKind: ""
  property var state: ({})
  property bool busy: false
  property bool refreshQueued: false
  property string message: ""
  property string passwordSsid: ""
  property bool passwordOpen: false
  property bool qrOpen: false
  property string qrSource: ""
  property string qrSsid: ""
  readonly property int textSmall: 13
  readonly property int textBody: 15
  readonly property int textTitle: 18
  readonly property string helperRoot: Quickshell.env("HOME") + "/.local/bin/"
  signal closeRequested()

  Theme { id: theme }

  readonly property var panelInfo: {
    if (panelKind === "wifi") return ({ title: "Wi-Fi", subtitle: "Networks and connection", icon: "󰖩" })
    if (panelKind === "bluetooth") return ({ title: "Bluetooth", subtitle: "Devices and pairing", icon: "󰂯" })
    if (panelKind === "volume") return ({ title: "Audio", subtitle: "Output, input and streams", icon: "󰕾" })
    if (panelKind === "display") return ({ title: "Display", subtitle: "Monitors and brightness", icon: "󰍹" })
    if (panelKind === "tailscale") return ({ title: "Tailscale", subtitle: "Tailnet, peers and exit nodes", icon: "󰒍" })
    if (panelKind === "power") return ({ title: "Power", subtitle: "Performance profile", icon: "󰌪" })
    return ({ title: "Control", subtitle: "Quick settings", icon: "◇" })
  }

  function parseState(raw) {
    try { page.state = JSON.parse(String(raw || "").trim()) || ({}) }
    catch (e) { page.state = ({ error: "Could not parse control state" }) }
  }

  function refresh() {
    if (page.panelKind === "") return
    if (stateProcess.running) {
      page.refreshQueued = true
      return
    }
    stateProcess.command = [page.helperRoot + "nixos-control-state", page.panelKind]
    stateProcess.running = true
  }

  function runAction(action, args, secret) {
    if (page.busy || page.panelKind === "") return
    var command = [page.helperRoot + "nixos-control-action", page.panelKind, action]
    var values = args || []
    for (var i = 0; i < values.length; i++) command.push(String(values[i]))
    actionProcess.secret = String(secret || "")
    actionProcess.command = command
    page.busy = true
    page.message = "Working…"
    actionProcess.running = true
  }

  function signalIcon(strength) {
    var value = Number(strength || 0)
    if (value >= 75) return "󰤨"
    if (value >= 50) return "󰤥"
    if (value >= 25) return "󰤢"
    return "󰤟"
  }

  function openWifi(network) {
    if (!network) return
    if (network.active) {
      page.runAction("disconnect", [])
      return
    }
    var secured = String(network.security || "") !== "" && String(network.security) !== "--"
    if (network.known || !secured) {
      page.runAction("connect", [network.ssid], "")
      return
    }
    page.passwordSsid = network.ssid
    page.passwordOpen = true
    wifiPassword.forceActiveFocus()
  }

  function openWifiQr() {
    if (qrProcess.running) return
    page.message = "Creating private QR…"
    qrProcess.command = [page.helperRoot + "nixos-wifi-qr"]
    qrProcess.running = true
  }

  function launch(program) { Quickshell.execDetached([program]) }

  onPanelKindChanged: {
    page.state = ({})
    page.passwordOpen = false
    page.qrOpen = false
    Qt.callLater(page.refresh)
  }
  Component.onCompleted: refresh()

  Process {
    id: stateProcess
    stdout: StdioCollector { id: stateOutput }
    onExited: {
      page.parseState(stateOutput.text)
      if (page.refreshQueued) {
        page.refreshQueued = false
        Qt.callLater(page.refresh)
      }
    }
  }

  Process {
    id: actionProcess
    property string secret: ""
    stdinEnabled: true
    stdout: StdioCollector { id: actionOutput }
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
    onExited: {
      page.busy = false
      try {
        var result = JSON.parse(String(actionOutput.text || "{}"))
        page.message = result.ok ? "Done" : (result.detail || "Action failed")
      } catch (e) {
        page.message = "Action finished"
      }
      messageTimer.restart()
      refreshTimer.restart()
    }
  }

  Process {
    id: qrProcess
    stdout: StdioCollector { id: qrOutput }
    onExited: {
      try {
        var result = JSON.parse(String(qrOutput.text || "{}"))
        if (result.ok) {
          page.qrSsid = result.ssid || "Wi-Fi"
          page.qrSource = "file://" + result.path + "?v=" + Date.now()
          page.qrOpen = true
          page.message = ""
        } else {
          page.message = result.detail || "Could not create Wi-Fi QR"
          messageTimer.restart()
        }
      } catch (e) {
        page.message = "Could not create Wi-Fi QR"
        messageTimer.restart()
      }
    }
  }

  Timer { id: refreshTimer; interval: 700; onTriggered: page.refresh() }
  Timer { id: messageTimer; interval: 2600; onTriggered: page.message = "" }
  Timer { interval: 5000; repeat: true; running: page.panelKind !== ""; onTriggered: page.refresh() }

  component PanelButton: Rectangle {
    id: panelButton
    property string label: ""
    property string icon: ""
    property bool selected: false
    signal activated()
    implicitHeight: 40
    implicitWidth: Math.max(90, buttonRow.implicitWidth + 22)
    color: !panelButton.enabled ? Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.55)
      : (buttonMouse.containsMouse || selected ? theme.selected : theme.panel)
    border.width: 1
    border.color: selected || buttonMouse.containsMouse ? theme.accent : theme.border
    opacity: enabled ? 1 : 0.5
    radius: 0
    Row {
      id: buttonRow
      anchors.centerIn: parent
      spacing: 7
      Text { text: panelButton.icon; visible: text !== ""; color: theme.accent; font.family: theme.fontFamily; font.pixelSize: 16 }
      Text { text: panelButton.label; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textSmall }
    }
    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      enabled: panelButton.enabled
      hoverEnabled: true
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: panelButton.activated()
    }
  }

  component ControlSlider: Item {
    id: sliderControl
    property real controlValue: 0
    property real maximum: 100
    property string icon: ""
    property string label: ""
    property bool muted: false
    signal committed(real value)
    implicitHeight: 42
    onControlValueChanged: if (!control.pressed) control.value = controlValue

    RowLayout {
      anchors.fill: parent
      spacing: 9
      Text {
        text: sliderControl.icon
        color: sliderControl.muted ? theme.muted : theme.accent
        font.family: theme.fontFamily
        font.pixelSize: 18
        Layout.preferredWidth: 22
        horizontalAlignment: Text.AlignHCenter
      }
      Text {
        text: sliderControl.label
        color: theme.foreground
        font.family: theme.fontFamily
        font.pixelSize: page.textSmall
        Layout.preferredWidth: 54
      }
      Slider {
        id: control
        Layout.fillWidth: true
        from: 0
        to: sliderControl.maximum
        stepSize: 1
        Component.onCompleted: value = sliderControl.controlValue
        onPressedChanged: if (!pressed) sliderControl.committed(value)
        background: Rectangle {
          x: control.leftPadding
          y: control.topPadding + control.availableHeight / 2 - height / 2
          width: control.availableWidth
          height: 5
          color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16)
          Rectangle { width: control.visualPosition * parent.width; height: parent.height; color: sliderControl.muted ? theme.muted : theme.accent }
        }
        handle: Rectangle {
          x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
          y: control.topPadding + control.availableHeight / 2 - height / 2
          width: 10
          height: 20
          color: sliderControl.muted ? theme.muted : theme.foreground
          border.width: 1
          border.color: theme.background
          radius: 0
        }
      }
      Text {
        text: Math.round(control.value) + "%"
        color: theme.foreground
        font.family: theme.fontFamily
        font.pixelSize: page.textSmall
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      PanelButton { label: ""; icon: "‹"; implicitWidth: 30; onActivated: page.closeRequested() }
      Text { text: page.panelInfo.icon; color: theme.accent; font.family: theme.fontFamily; font.pixelSize: 25 }
      Column {
        spacing: 1
        Text { text: page.panelInfo.title; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textTitle; font.weight: Font.DemiBold }
        Text { text: page.panelInfo.subtitle.toUpperCase(); color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.letterSpacing: 0.8 }
      }
      Item { Layout.fillWidth: true }
      Text { visible: page.busy; text: "󰑐"; color: theme.accent; font.family: theme.fontFamily; font.pixelSize: 16 }
      PanelButton { label: ""; icon: "󰑐"; implicitWidth: 30; enabled: !page.busy; onActivated: page.refresh() }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: page.message !== "" ? 30 : 0
      visible: page.message !== ""
      color: theme.selected
      border.width: 1
      border.color: theme.accent
      Text { anchors.centerIn: parent; text: page.message; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textSmall; elide: Text.ElideRight; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter }
    }

    Loader {
      Layout.fillWidth: true
      Layout.fillHeight: true
      sourceComponent: {
        if (page.panelKind === "wifi") return wifiPanel
        if (page.panelKind === "bluetooth") return bluetoothPanel
        if (page.panelKind === "volume") return audioPanel
        if (page.panelKind === "display") return displayPanel
        if (page.panelKind === "tailscale") return tailscalePanel
        if (page.panelKind === "power") return powerPanel
        return emptyPanel
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: "NixOS native · declarative services"
      color: theme.muted
      opacity: 0.7
      font.family: theme.fontFamily
      font.pixelSize: 11
    }
  }

  Component {
    id: emptyPanel
    Item { Text { anchors.centerIn: parent; text: page.state.error || "Loading…"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textBody } }
  }

  Component {
    id: wifiPanel
    Item {
      ColumnLayout {
        anchors.fill: parent
        spacing: 9
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: page.state.available === false ? "No Wi-Fi adapter" : (page.state.enabled ? "Wi-Fi is on" : "Wi-Fi is off")
            color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textBody; Layout.fillWidth: true
          }
          PanelButton { label: page.state.enabled ? "Off" : "On"; icon: "󰖩"; enabled: !page.busy && page.state.available === true; onActivated: page.runAction("toggle", []) }
          PanelButton { label: "Scan"; icon: "󰑐"; enabled: !page.busy && page.state.available === true && page.state.enabled === true; onActivated: page.runAction("rescan", []) }
          PanelButton { label: "QR"; icon: "󰐲"; implicitWidth: 64; enabled: !qrProcess.running && (page.state.networks || []).some(network => network.active); onActivated: page.openWifiQr() }
          PanelButton { label: ""; icon: "󰒓"; implicitWidth: 36; onActivated: page.launch("nm-connection-editor") }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: theme.panel
          border.width: 1
          border.color: theme.border
          ListView {
            id: wifiList
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            spacing: 3
            model: page.state.networks || []
            delegate: Rectangle {
              required property var modelData
              width: wifiList.width
              height: 52
              color: wifiMouse.containsMouse ? theme.selected : "transparent"
              border.width: modelData.active ? 1 : 0
              border.color: theme.accent
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 9
                Text { text: page.signalIcon(modelData.signal); color: modelData.active ? theme.accent : theme.foreground; font.family: theme.fontFamily; font.pixelSize: 19; Layout.preferredWidth: 23 }
                Column {
                  Layout.fillWidth: true
                  spacing: 1
                  Text { text: modelData.ssid; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textBody; elide: Text.ElideRight; width: parent.width }
                  Text {
                    text: (modelData.active ? "Connected · " : "") + modelData.signal + "% · " + (modelData.security || "Open")
                    color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width
                  }
                }
                Text { visible: modelData.known && !modelData.active; text: "Known"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 11 }
                Text { text: modelData.active ? "Disconnect" : "Connect"; color: theme.accent; font.family: theme.fontFamily; font.pixelSize: page.textSmall }
              }
              MouseArea { id: wifiMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: mouse => { if (mouse.button === Qt.RightButton && modelData.known) page.runAction("forget", [modelData.ssid]); else page.openWifi(modelData) } }
            }
            Text { anchors.centerIn: parent; visible: wifiList.count === 0; text: page.state.enabled === false ? "Turn Wi-Fi on to scan" : "No networks found"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textBody }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: page.passwordOpen
        color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.96)
        border.width: 1
        border.color: theme.accent
        z: 20
        ColumnLayout {
          width: Math.min(parent.width - 50, 380)
          anchors.centerIn: parent
          spacing: 10
          Text { text: "Connect to " + page.passwordSsid; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textTitle; Layout.fillWidth: true; wrapMode: Text.Wrap }
          Text { text: "Password is sent through stdin and never appears in the process list."; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; Layout.fillWidth: true; wrapMode: Text.Wrap }
          TextField {
            id: wifiPassword
            Layout.fillWidth: true
            echoMode: TextInput.Password
            color: theme.foreground
            font.family: theme.fontFamily
            font.pixelSize: page.textBody
            background: Rectangle { color: theme.panel; border.width: 1; border.color: wifiPassword.activeFocus ? theme.accent : theme.border; radius: 0 }
            Keys.onReturnPressed: { page.passwordOpen = false; page.runAction("connect", [page.passwordSsid], text); text = "" }
            Keys.onEscapePressed: { page.passwordOpen = false; text = "" }
          }
          RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PanelButton { label: "Cancel"; onActivated: { page.passwordOpen = false; wifiPassword.text = "" } }
            PanelButton { label: "Connect"; icon: "󰌷"; enabled: wifiPassword.text.length > 0; onActivated: { var secret = wifiPassword.text; wifiPassword.text = ""; page.passwordOpen = false; page.runAction("connect", [page.passwordSsid], secret) } }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: page.qrOpen
        color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.97)
        border.width: 1
        border.color: theme.accent
        z: 21
        ColumnLayout {
          width: Math.min(parent.width - 48, 360)
          anchors.centerIn: parent
          spacing: 10
          Text { text: "Share " + page.qrSsid; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textTitle; Layout.alignment: Qt.AlignHCenter; elide: Text.ElideRight; Layout.maximumWidth: parent.width }
          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 300
            implicitHeight: 300
            color: "white"
            Image { anchors.fill: parent; anchors.margins: 8; source: page.qrSource; fillMode: Image.PreserveAspectFit; cache: false; asynchronous: false }
          }
          Text { text: "Scan to join this Wi-Fi network"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; Layout.alignment: Qt.AlignHCenter }
          PanelButton { label: "Close"; icon: "󰅖"; Layout.alignment: Qt.AlignHCenter; onActivated: page.qrOpen = false }
        }
      }
    }
  }

  Component {
    id: bluetoothPanel
    Item {
      ColumnLayout {
        anchors.fill: parent
        spacing: 9
        RowLayout {
          Layout.fillWidth: true
          Column {
            Layout.fillWidth: true
            Text { text: page.state.available === false ? "No Bluetooth adapter" : (page.state.powered ? "Bluetooth is on" : "Bluetooth is off"); color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textBody }
            Text { text: page.state.adapter || ""; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall }
          }
          PanelButton { label: page.state.powered ? "Off" : "On"; icon: "󰂯"; enabled: !page.busy && page.state.available === true; onActivated: page.runAction("toggle", []) }
          PanelButton { label: "Scan"; icon: "󰑐"; enabled: !page.busy && page.state.available === true && page.state.powered === true; onActivated: page.runAction("scan", []) }
          PanelButton { label: ""; icon: "󰒓"; implicitWidth: 36; onActivated: page.launch("blueman-manager") }
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: theme.panel
          border.width: 1
          border.color: theme.border
          ListView {
            id: btList
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            spacing: 3
            model: page.state.devices || []
            delegate: Rectangle {
              required property var modelData
              width: btList.width
              height: 52
              color: btMouse.containsMouse ? theme.selected : "transparent"
              border.width: modelData.connected ? 1 : 0
              border.color: theme.accent
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 9
                Text { text: modelData.connected ? "󰂱" : "󰂯"; color: modelData.connected ? theme.accent : theme.foreground; font.family: theme.fontFamily; font.pixelSize: 19; Layout.preferredWidth: 23 }
                Column {
                  Layout.fillWidth: true
                  spacing: 1
                  Text { text: modelData.name; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textBody; elide: Text.ElideRight; width: parent.width }
                  Text { text: modelData.address + (modelData.paired ? " · Paired" : ""); color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                }
                Text { visible: modelData.paired && !modelData.connected; text: "Forget"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: page.runAction("remove", [modelData.address]) } }
                Text { text: modelData.connected ? "Disconnect" : "Connect"; color: theme.accent; font.family: theme.fontFamily; font.pixelSize: page.textSmall }
              }
              MouseArea { id: btMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.runAction(modelData.connected ? "disconnect" : "connect", [modelData.address]) }
            }
            Text { anchors.centerIn: parent; visible: btList.count === 0; text: page.state.powered === false ? "Turn Bluetooth on to scan" : "No devices found"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textBody }
          }
        }
      }
    }
  }

  Component {
    id: audioPanel
    Item {
      ColumnLayout {
        anchors.fill: parent
        spacing: 8
        RowLayout {
          Layout.fillWidth: true
          Text { text: "LIVE PIPEWIRE CONTROLS"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.letterSpacing: 0.8; Layout.fillWidth: true }
          PanelButton { label: "Mixer"; icon: "󰓃"; onActivated: page.launch("pavucontrol") }
        }
        ScrollView {
          id: audioScroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          ColumnLayout {
            width: audioScroll.availableWidth
            spacing: 7
            Text { text: "OUTPUT"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.weight: Font.Medium }
            RowLayout {
              Layout.fillWidth: true
              ControlSlider { Layout.fillWidth: true; label: "Output"; icon: page.state.output && page.state.output.muted ? "󰝟" : "󰕾"; muted: page.state.output ? page.state.output.muted : false; controlValue: page.state.output ? page.state.output.percent : 0; maximum: 150; onCommitted: value => page.runAction("output-volume", [Math.round(value)]) }
              PanelButton { label: page.state.output && page.state.output.muted ? "Unmute" : "Mute"; icon: "󰝟"; onActivated: page.runAction("output-mute", []) }
            }
            Repeater {
              model: page.state.sinks || []
              delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; implicitHeight: 36; color: sinkMouse.containsMouse ? theme.selected : theme.panel; border.width: modelData.default ? 1 : 0; border.color: theme.accent
                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 9
                  anchors.rightMargin: 9
                  Text { text: modelData.default ? "󰓃" : "󰋋"; color: modelData.default ? theme.accent : theme.foreground; font.family: theme.fontFamily; font.pixelSize: 15 }
                  Text { text: modelData.name; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textSmall; elide: Text.ElideRight; Layout.fillWidth: true }
                  Text { text: modelData.default ? "Default" : "Select"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 11 }
                }
                MouseArea { id: sinkMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.runAction("default", [modelData.id]) }
              }
            }
            Text { text: "INPUT"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.weight: Font.Medium; Layout.topMargin: 5 }
            RowLayout {
              Layout.fillWidth: true
              ControlSlider { Layout.fillWidth: true; label: "Input"; icon: page.state.input && page.state.input.muted ? "󰍭" : "󰍬"; muted: page.state.input ? page.state.input.muted : false; controlValue: page.state.input ? page.state.input.percent : 0; maximum: 150; onCommitted: value => page.runAction("input-volume", [Math.round(value)]) }
              PanelButton { label: page.state.input && page.state.input.muted ? "Unmute" : "Mute"; icon: "󰍭"; onActivated: page.runAction("input-mute", []) }
            }
            Repeater {
              model: page.state.sources || []
              delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; implicitHeight: 36; color: sourceMouse.containsMouse ? theme.selected : theme.panel; border.width: modelData.default ? 1 : 0; border.color: theme.accent
                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 9
                  anchors.rightMargin: 9
                  Text { text: "󰍬"; color: modelData.default ? theme.accent : theme.foreground; font.family: theme.fontFamily; font.pixelSize: 15 }
                  Text { text: modelData.name; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textSmall; elide: Text.ElideRight; Layout.fillWidth: true }
                  Text { text: modelData.default ? "Default" : "Select"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 11 }
                }
                MouseArea { id: sourceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.runAction("default", [modelData.id]) }
              }
            }
            Text { text: "APPLICATION STREAMS"; visible: (page.state.streams || []).length > 0; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.weight: Font.Medium; Layout.topMargin: 5 }
            Repeater {
              model: page.state.streams || []
              delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                ControlSlider { Layout.fillWidth: true; label: modelData.name; icon: modelData.muted ? "󰝟" : "󰕾"; muted: modelData.muted; controlValue: modelData.percent; maximum: 150; onCommitted: value => page.runAction("stream-volume", [modelData.id, Math.round(value)]) }
                PanelButton { label: ""; icon: "󰝟"; implicitWidth: 36; onActivated: page.runAction("stream-mute", [modelData.id]) }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: displayPanel
    Item {
      ColumnLayout {
        anchors.fill: parent
        spacing: 9
        Text { text: "BRIGHTNESS"; visible: page.state.brightnessAvailable === true; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.weight: Font.Medium }
        ControlSlider { Layout.fillWidth: true; visible: page.state.brightnessAvailable === true; label: "Panel"; icon: "󰃠"; controlValue: page.state.brightness || 0; onCommitted: value => page.runAction("brightness", [Math.round(value)]) }
        RowLayout {
          Layout.fillWidth: true
          Text { text: "MONITORS"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.weight: Font.Medium; Layout.fillWidth: true }
          Text { text: "Read-only"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall }
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: theme.panel
          border.width: 1
          border.color: theme.border
          ListView {
            id: monitorList
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            spacing: 3
            model: page.state.monitors || []
            delegate: Rectangle {
              required property var modelData
              width: monitorList.width; height: 54; color: "transparent"; border.width: modelData.focused ? 1 : 0; border.color: theme.accent
              RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                Text { text: modelData.disabled ? "󰶐" : "󰍹"; color: modelData.focused ? theme.accent : theme.foreground; font.family: theme.fontFamily; font.pixelSize: 19 }
                Column {
                  Layout.fillWidth: true
                  spacing: 1
                  Text { text: modelData.name + (modelData.focused ? " · Focused" : ""); color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textBody }
                  Text { text: modelData.disabled ? "Disabled" : modelData.width + "×" + modelData.height + " @ " + modelData.refreshRate + "Hz · " + Math.round(Number(modelData.scale) * 100) + "%"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 11 }
                }
                Text { text: modelData.disabled ? "Disabled" : "Active"; color: modelData.disabled ? theme.muted : theme.accent; font.family: theme.fontFamily; font.pixelSize: page.textSmall }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: tailscalePanel
    Item {
      ColumnLayout {
        anchors.fill: parent
        spacing: 9
        RowLayout {
          Layout.fillWidth: true
          Column {
            Layout.fillWidth: true
            Text { text: page.state.installed === false ? "Tailscale is not installed" : (page.state.active ? "Connected" : (page.state.needsLogin ? "Authorization required" : "Disconnected")); color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textBody }
            Text { text: page.state.self ? ((page.state.self.host || "") + "  " + ((page.state.self.ips || [])[0] || "")) : (page.state.backend || ""); color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall }
          }
          PanelButton { label: page.state.active ? "Disconnect" : (page.state.needsLogin ? "Authorize" : "Connect"); icon: page.state.active ? "󰌸" : "󰌷"; enabled: page.state.installed !== false && !page.busy; onActivated: page.runAction(page.state.active ? "down" : "up", []) }
        }
        Text { text: "PEERS"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.weight: Font.Medium }
        Rectangle {
          Layout.fillWidth: true; Layout.fillHeight: true; color: theme.panel; border.width: 1; border.color: theme.border
          ListView {
            id: peerList
            anchors.fill: parent; anchors.margins: 6; clip: true; spacing: 3; model: page.state.peers || []
            delegate: Rectangle {
              required property var modelData
              width: peerList.width; height: 54; color: peerMouse.containsMouse ? theme.selected : "transparent"; border.width: modelData.exitNode ? 1 : 0; border.color: theme.accent
              RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                Text { text: modelData.online ? "󰒍" : "󰒎"; color: modelData.online ? theme.accent : theme.muted; font.family: theme.fontFamily; font.pixelSize: 18 }
                Column {
                  Layout.fillWidth: true
                  spacing: 1
                  Text { text: modelData.host || modelData.dns; color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: page.textBody; elide: Text.ElideRight; width: parent.width }
                  Text { text: ((modelData.ips || [])[0] || "") + (modelData.os ? " · " + modelData.os : "") + (modelData.online ? " · Online" : " · Offline"); color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                }
                Text { visible: modelData.exitNodeOption; text: modelData.exitNode ? "Stop exit" : "Use exit"; color: theme.accent; font.family: theme.fontFamily; font.pixelSize: page.textSmall }
              }
              MouseArea { id: peerMouse; anchors.fill: parent; enabled: modelData.exitNodeOption; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: page.runAction("exit-node", [modelData.exitNode ? "" : modelData.dns || modelData.host]) }
            }
            Text { anchors.centerIn: parent; visible: peerList.count === 0; text: page.state.active ? "No peers" : "Connect Tailscale to see peers"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textBody }
          }
        }
      }
    }
  }

  Component {
    id: powerPanel
    Item {
      ColumnLayout {
        anchors.fill: parent
        spacing: 10
        Text { text: "ACTIVE PROFILE"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.weight: Font.Medium }
        Text { text: String(page.state.active || "Unavailable").toUpperCase(); color: theme.foreground; font.family: theme.fontFamily; font.pixelSize: 24; font.weight: Font.DemiBold }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.14) }
        Text { text: "POWER PROFILE"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; font.weight: Font.Medium }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Repeater {
            model: [
              { id: "power-saver", label: "Power saver", icon: "󰌪" },
              { id: "balanced", label: "Balanced", icon: "󰊚" },
              { id: "performance", label: "Performance", icon: "󰓅" }
            ]
            delegate: PanelButton {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: 64
              label: modelData.label
              icon: modelData.icon
              selected: page.state.active === modelData.id
              enabled: !page.busy && ((page.state.profiles || []).length === 0 || (page.state.profiles || []).indexOf(modelData.id) >= 0)
              onActivated: page.runAction("profile", [modelData.id])
            }
          }
        }
        Text { Layout.fillWidth: true; text: "Profiles are provided by power-profiles-daemon and persist independently of this panel."; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: page.textSmall; wrapMode: Text.Wrap }
        Item { Layout.fillHeight: true }
      }
    }
  }
}
