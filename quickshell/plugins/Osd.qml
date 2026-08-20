import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  property var theme: null
  property bool opened: false
  property string kind: "volume"
  property string queryKind: "volume"
  property int value: 0
  property string message: ""
  property string voxtypeState: "idle"
  property real voxtypePeak: 0.0

  readonly property bool voxtypeActive: voxtypeState !== "idle" && voxtypeState !== ""
  readonly property bool voxtypeRecording: voxtypeState === "recording"
  readonly property bool voxtypeTranscribing: voxtypeState === "transcribing"
  readonly property color voxtypeColor: voxtypeRecording
    ? (theme ? theme.urgent : "#f7768e")
    : (theme ? theme.accent : "#7aa2f7")
  readonly property string voxtypeLabel: voxtypeRecording
    ? "RECORDING"
    : (voxtypeTranscribing ? "TRANSCRIBING" : String(voxtypeState).toUpperCase())
  readonly property string voxtypeStatePath: {
    var xdg = Quickshell.env("XDG_RUNTIME_DIR")
    return xdg && xdg.length > 0 ? xdg + "/voxtype/state" : "/run/user/1000/voxtype/state"
  }

  readonly property string icon: {
    if (kind === "volume-muted") return ""
    if (kind === "microphone-muted") return "󰍭"
    if (kind === "microphone") return "󰍬"
    if (kind === "brightness") return "󰃠"
    if (value <= 0) return ""
    if (value <= 33) return ""
    if (value <= 66) return ""
    return ""
  }

  function show(kindName, rawValue, rawMessage) {
    root.kind = String(kindName || "volume")
    root.value = Math.max(0, Math.min(150, Number(rawValue || 0)))
    root.message = String(rawMessage || (root.value + "%"))
    root.opened = true
    hideTimer.restart()
  }

  function refresh(kindName) {
    root.queryKind = kindName
    if (kindName === "brightness") {
      statusProcess.command = ["sh", "-c", "brightnessctl -m 2>/dev/null | awk -F, 'NR == 1 { gsub(/%/, \"\", $4); print $4 }'"]
    } else {
      var node = kindName === "microphone" ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@"
      statusProcess.command = ["sh", "-c", "wpctl get-volume " + node + " 2>/dev/null | awk '{ printf \"%d %s\\n\", $2 * 100, /MUTED/ ? \"muted\" : \"active\" }'"]
    }
    statusProcess.running = false
    statusProcess.running = true
  }

  function applyStatus(raw) {
    var parts = String(raw || "").trim().split(/\s+/)
    var percent = Number(parts[0] || 0)
    var shownKind = root.queryKind
    if (parts[1] === "muted") shownKind += "-muted"
    root.show(shownKind, percent, percent + "%")
  }

  function setVoxtypeState(raw) {
    var next = String(raw || "idle").trim().split(/\s+/)[0] || "idle"
    if (next !== root.voxtypeState) root.voxtypeState = next
  }

  function handleVoxtypeAudio(raw) {
    try {
      var frame = JSON.parse(String(raw || "").trim())
      if (typeof frame.peak === "number")
        root.voxtypePeak = Math.max(0.0, Math.min(1.0, frame.peak))
    } catch (error) {
      // Ignore the bridge's connected/disconnected status lines.
    }
  }

  Process {
    id: statusProcess
    stdout: StdioCollector { id: statusOutput }
    onExited: root.applyStatus(statusOutput.text)
  }

  FileView {
    path: root.voxtypeStatePath
    watchChanges: true
    printErrors: false
    onLoaded: root.setVoxtypeState(text())
    onLoadFailed: root.setVoxtypeState("idle")
    onFileChanged: reload()
  }

  Process {
    id: voxtypeAudioBridge
    command: ["voxtype-audio-bridge"]
    running: root.voxtypeRecording

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { root.handleVoxtypeAudio(data) }
    }

    onRunningChanged: {
      if (!running) root.voxtypePeak = 0.0
    }
  }

  onVoxtypeStateChanged: {
    if (!root.voxtypeRecording) root.voxtypePeak = 0.0
  }

  Timer {
    interval: 160
    repeat: true
    running: root.voxtypeRecording && root.voxtypePeak < 0.01
    onTriggered: root.voxtypePeak = 0.12
  }

  Timer {
    id: hideTimer
    interval: 1300
    onTriggered: root.opened = false
  }

  IpcHandler {
    target: "nixos-osd"

    // Quickshell 0.3's CLI advertises positional IPC arguments but rejects
    // them at runtime. Keep these calls argument-free and query live state.
    function volume(): string {
      root.refresh("volume")
      return "ok"
    }

    function microphone(): string {
      root.refresh("microphone")
      return "ok"
    }

    function brightness(): string {
      root.refresh("brightness")
      return "ok"
    }
  }

  PanelWindow {
    id: volumePanel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Rectangle {
      width: 430
      height: 86
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 66
      color: root.theme ? Qt.rgba(root.theme.background.r, root.theme.background.g, root.theme.background.b, 0.96) : "#101315"
      border.width: 2
      border.color: root.theme ? root.theme.border : "#414868"
      radius: 0

      Row {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 18

        Text {
          width: 42
          anchors.verticalCenter: parent.verticalCenter
          text: root.icon
          color: root.theme ? root.theme.foreground : "#c0caf5"
          font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
          font.pixelSize: 34
          horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
          width: 270
          height: 10
          anchors.verticalCenter: parent.verticalCenter
          color: root.theme ? Qt.rgba(root.theme.foreground.r, root.theme.foreground.g, root.theme.foreground.b, 0.28) : "#414868"

          Rectangle {
            height: parent.height
            width: parent.width * Math.min(100, root.value) / 100
            color: root.theme ? root.theme.accent : "#7aa2f7"

            Behavior on width {
              NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
          }
        }

        Text {
          width: 64
          anchors.verticalCenter: parent.verticalCenter
          text: root.message
          color: root.theme ? root.theme.foreground : "#c0caf5"
          font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          font.bold: true
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }

  PanelWindow {
    id: voxtypePanel
    visible: root.voxtypeActive
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-voxtype-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
      intersection: Intersection.Subtract
      x: 0
      y: 0
      width: voxtypePanel.width
      height: voxtypePanel.height
    }

    Rectangle {
      width: 430
      height: 82
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 72
      color: root.theme
        ? Qt.rgba(root.theme.background.r, root.theme.background.g, root.theme.background.b, 0.97)
        : "#101315"
      border.width: 2
      border.color: root.voxtypeColor
      radius: 0

      Row {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 14

        Text {
          width: 42
          anchors.verticalCenter: parent.verticalCenter
          text: root.voxtypeRecording ? "󰍬" : "󰔟"
          color: root.voxtypeColor
          font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
          font.pixelSize: 32
          horizontalAlignment: Text.AlignHCenter
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 56
          spacing: 6

          Text {
            text: "MIC  ·  " + root.voxtypeLabel
            color: root.theme ? root.theme.foreground : "#c0caf5"
            font.family: root.theme ? root.theme.fontFamily : "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.bold: true
          }

          Row {
            height: 25
            spacing: 3

            Repeater {
              model: 18

              Rectangle {
                width: 5
                height: root.voxtypeRecording
                  ? Math.max(6, Math.min(25, 6 + root.voxtypePeak * 19 + ((index * 5) % 4)))
                  : 6
                anchors.verticalCenter: parent.verticalCenter
                color: root.voxtypeColor
                opacity: root.voxtypeRecording ? 1.0 : 0.65

                Behavior on height {
                  NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
              }
            }
          }
        }
      }
    }
  }
}
