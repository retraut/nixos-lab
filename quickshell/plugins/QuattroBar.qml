import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root

  property var theme: null
  // Match the current Omarchy workstation: opaque by default, with the
  // existing double-click gesture still available for a transparent view.
  property bool transparentMode: false
  readonly property color background: theme ? theme.background : "#101315"
  readonly property color foreground: theme ? theme.foreground : "#cacccc"
  readonly property color muted: theme ? theme.muted : "#707880"
  readonly property color accent: theme ? theme.accent : "#cacccc"
  readonly property color hover: theme ? theme.panel : "#1e2327"
  readonly property color selected: theme ? theme.selected : "#2a2a2a"
  readonly property int barFontSize: theme ? theme.barFontSize : 16
  readonly property int barIconSize: theme ? theme.barIconSize : (barFontSize + 4)
  readonly property string barFontFamily: theme ? theme.fontFamily : "JetBrainsMono Nerd Font"

  function openWeather(mode) {
    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/nixos-weather", mode])
  }

  Timer {
    id: transparencyDoubleClickTimer
    interval: 420
    repeat: false
  }

  // Keep this behind the actual widgets. Empty bar space remains a gesture
  // target regardless of which side of the clock is clicked, while menu,
  // workspace and status widgets keep their own mouse handlers.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    z: -10
    onClicked: {
      if (transparencyDoubleClickTimer.running) {
        transparencyDoubleClickTimer.stop()
        root.transparentMode = !root.transparentMode
      } else {
        transparencyDoubleClickTimer.start()
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 0
    color: root.transparentMode ? "transparent" : root.background
    border.width: 0
    border.color: root.transparentMode ? "transparent" : (theme ? theme.border : "#252b30")
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    spacing: 4

    MenuButton {
      Layout.alignment: Qt.AlignVCenter
      theme: root.theme
      fontSize: root.barIconSize
      fontFamily: root.barFontFamily
    }

    Workspaces {
      Layout.alignment: Qt.AlignVCenter
      activeColor: root.accent
      inactiveColor: root.muted
      selectedColor: root.selected
      fontSize: root.barFontSize
      fontFamily: root.barFontFamily
    }

    Item {
      Layout.fillWidth: true
      Layout.minimumWidth: 120

      // Match Omarchy's center order exactly: weather, clock, keyboard.
      // Keeping them in one centered row prevents the two side widgets from
      // drifting toward the right status group as the bar grows.
      RowLayout {
        anchors.centerIn: parent
        z: 10
        spacing: 8

        Item {
          id: weatherSlot
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredWidth: 30
          Layout.minimumWidth: 30
          Layout.preferredHeight: 28
          z: 10

          Weather {
            id: weatherWidget
            anchors.fill: parent
            theme: root.theme
            fontSize: root.barFontSize
            fontFamily: root.barFontFamily
            onActivated: root.openWeather("now")
            onSecondaryActivated: root.openWeather("week")
          }
        }

        Clock {
          Layout.alignment: Qt.AlignVCenter
          textColor: root.foreground
          fontSize: root.barFontSize
          fontFamily: root.barFontFamily
          theme: root.theme
          onActivated: Quickshell.execDetached(["sh", "-lc", "exec \"$HOME/.local/bin/nixos-calendar\""])
        }

        KeyboardLayout {
          Layout.alignment: Qt.AlignVCenter
          theme: root.theme
          fontSize: root.barFontSize
          fontFamily: root.barFontFamily
        }
      }
    }

    Tray {
      Layout.alignment: Qt.AlignVCenter
      theme: root.theme
      fontFamily: root.barFontFamily
    }

    NotificationBell {
      Layout.alignment: Qt.AlignVCenter
      theme: root.theme
      fontSize: root.barIconSize
      fontFamily: root.barFontFamily
    }

    Agents {
      Layout.alignment: Qt.AlignVCenter
      textColor: root.foreground
      accentColor: root.accent
      fontSize: root.barIconSize
      fontFamily: root.barFontFamily
      onActivated: Quickshell.execDetached(["sh", "-lc", "exec \"$HOME/.local/bin/nixos-agents\""])
      onLaunchRequested: Quickshell.execDetached(["ghostty", "--title=Codex", "-e", "codex"])
    }

    Battery {
      Layout.alignment: Qt.AlignVCenter
      textColor: root.foreground
      fontSize: root.barIconSize
      fontFamily: root.barFontFamily
      onActivated: Quickshell.execDetached(["sh", "-lc", "exec \"$HOME/.local/bin/nixos-battery\""])
    }

    ControlCenter {
      Layout.alignment: Qt.AlignVCenter
      textColor: root.foreground
      accentColor: root.accent
      fontSize: root.barIconSize
      fontFamily: root.barFontFamily
      onActivated: Quickshell.execDetached(["sh", "-lc", "exec \"$HOME/.local/bin/nixos-control-center\""])
      onCloseRequested: Quickshell.execDetached(["sh", "-lc", "exec \"$HOME/.local/bin/nixos-control-center\" close"])
    }

  }
}
