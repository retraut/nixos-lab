import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
  id: root

  property color activeColor: "#7aa2f7"
  property color inactiveColor: "#a9b1d6"
  property color selectedColor: "#292e42"
  property int fontSize: 16
  property string fontFamily: "JetBrainsMono Nerd Font"
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  function workspaceIds() {
    // Keep the compact 1..5 baseline, then expose any additional workspaces
    // Hyprland has created (for example after Super+Shift+6).
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function isActive(id) {
    var focused = Hyprland.focusedWorkspace
    return focused !== null && focused.id === id
  }

  function focusWorkspace(id) {
    // Hyprland's current dispatch interface is Lua-backed; the legacy
    // `dispatch workspace 2` form is parsed as invalid Lua on this system.
    Quickshell.execDetached([
      "hyprctl",
      "dispatch",
      "hl.dsp.focus({ workspace = \"" + String(id) + "\" })"
    ])
  }

  RowLayout {
    id: row
    spacing: 3

    Repeater {
      model: root.workspaceIds()

      Rectangle {
        required property int modelData

        implicitWidth: 24
        implicitHeight: 26
        radius: 0
        // Keep the active workspace marker as a dot without a filled tile.
        color: "transparent"
        border.width: 0

        Text {
          anchors.centerIn: parent
          text: root.isActive(modelData) ? "●" : (modelData === 10 ? "0" : String(modelData))
          color: root.isActive(modelData) ? root.activeColor : root.inactiveColor
          font.pixelSize: root.fontSize
          font.family: root.fontFamily
        }

        MouseArea {
          anchors.fill: parent
          onClicked: root.focusWorkspace(modelData)
        }
      }
    }
  }
}
