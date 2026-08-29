import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "plugins"

// NixOS shell inspired by Omarchy Quattro's QML shell. The visuals are ours;
// no Omarchy runtime, paths, or update commands are required.
ShellRoot {
  Theme { id: serviceTheme }

  QtObject {
    id: notificationStateService
    property bool doNotDisturb: false
  }

  Notifications {
    theme: serviceTheme
    dndState: notificationStateService
  }

  Osd {
    theme: serviceTheme
  }

  AppSwitcher {}

  PolkitDialog {
    theme: serviceTheme
  }

  // Reload only Quickshell's QML tree. Do not restart the systemd unit: GUI
  // applications launched from that unit may share its cgroup and would be
  // terminated along with the shell.
  IpcHandler {
    target: "nixos-shell"

    function reload(): void {
      Quickshell.reload(true)
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 32
        exclusiveZone: 32
        color: "transparent"
        WlrLayershell.namespace: "nixos-shell-bar"
        WlrLayershell.layer: WlrLayer.Top

        // Keep the theme in the delegate's scope. A Theme declared above the
        // Variants component was not visible here, so QuattroBar fell back
        // to its old 16px typography defaults.
        Theme { id: panelTheme }

        QuattroBar {
          anchors.fill: parent
          theme: panelTheme
          notificationState: notificationStateService
        }
      }
    }
  }
}
