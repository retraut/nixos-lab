import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "plugins"

// NixOS shell inspired by Omarchy Quattro's QML shell. The visuals are ours;
// no Omarchy runtime, paths, or update commands are required.
ShellRoot {
  Theme { id: serviceTheme }

  Notifications {
    theme: serviceTheme
  }

  Osd {
    theme: serviceTheme
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
        }
      }
    }
  }
}
