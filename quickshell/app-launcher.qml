import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// A small NixOS-native equivalent of Quattro's QML Apps menu. It consumes
// freedesktop .desktop entries through Quickshell and launches them with the
// standard GTK desktop-entry resolver.
ShellRoot {
  id: root

  Theme { id: theme }

  readonly property real uiScale: 1.5
  function px(value) { return Math.round(value * root.uiScale) }

  property string query: ""
  property int selectedIndex: 0
  property int baseRowHeight: px(47)
  property int detailRowHeight: px(58)
  property int rowSpacing: px(3)
  property int cardChromeHeight: px(18 * 2 + 19 + 38 + 10 * 2)
  property int frozenRowsHeight: -1

  function rowHeight(detail) {
    return root.query.length > 0 && String(detail || "").length > 0
      ? root.detailRowHeight
      : root.baseRowHeight
  }

  function naturalRowsHeight() {
    if (appModel.count === 0) return root.baseRowHeight

    var total = 0
    for (var i = 0; i < appModel.count; i++) {
      if (i > 0) total += root.rowSpacing
      total += root.rowHeight(appModel.get(i).detail)
    }
    return total
  }

  readonly property int maxRowsHeight: Math.max(
    root.baseRowHeight,
    Math.min(
      Math.round(panel.height * 0.7),
      panel.height - root.px(40) - root.cardChromeHeight
    )
  )
  readonly property int visibleRowsHeight: Math.min(
    root.naturalRowsHeight(),
    root.frozenRowsHeight >= 0 ? root.frozenRowsHeight : root.maxRowsHeight
  )
  readonly property int cardHeight: root.cardChromeHeight + root.visibleRowsHeight

  function matches(entry, needle) {
    if (!needle) return true
    var text = [entry.name, entry.genericName, entry.comment].join(" ").toLowerCase()
    return text.indexOf(needle) >= 0
  }

  function rebuild() {
    appModel.clear()
    var needle = root.query.trim().toLowerCase()
    var values = DesktopEntries.applications.values || []
    var rows = []

    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!root.matches(entry, needle)) continue
      rows.push({
        name: String(entry.name || entry.genericName || entry.id || "Application"),
        detail: String(entry.genericName || entry.comment || ""),
        desktopId: String(entry.id || ""),
        icon: String(entry.icon || "application-x-executable")
      })
    }

    rows.sort(function(a, b) {
      return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
    })

    for (var j = 0; j < rows.length; j++) appModel.append(rows[j])
    root.selectedIndex = Math.min(root.selectedIndex, Math.max(0, appModel.count - 1))
  }

  function close() {
    Qt.quit()
  }

  function freezeCardTop() {
    if (panel.cardTop >= 0) return
    panel.cardTop = panel.centeredTop
    root.frozenRowsHeight = root.visibleRowsHeight
  }

  function launch(index) {
    if (index < 0 || index >= appModel.count) return
    var id = String(appModel.get(index).desktopId || "")
    if (!id) return
    if (!id.endsWith(".desktop")) id += ".desktop"
    Quickshell.execDetached(["gtk-launch", id])
    root.close()
  }

  ListModel { id: appModel }

  Component.onCompleted: {
    root.rebuild()
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.rebuild() }
  }

  PanelWindow {
    id: panel
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-app-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    property int cardTop: -1
    readonly property int centeredTop: Math.max(root.px(20), Math.round((height - card.height) / 2))

    Rectangle {
      anchors.fill: parent
      color: "transparent"

      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }
    }

    Rectangle {
      id: card
      width: Math.min(root.px(560), panel.width - root.px(40))
      height: root.cardHeight
      anchors.horizontalCenter: parent.horizontalCenter
      y: panel.cardTop >= 0 ? panel.cardTop : panel.centeredTop
      radius: 0
      color: theme.background
      border.width: 1
      border.color: theme.border

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.px(18)
        spacing: root.px(10)

        RowLayout {
          Layout.fillWidth: true

          Text {
            text: "Applications"
            color: theme.foreground
            font.pixelSize: root.px(16)
            font.weight: Font.Medium
          }

          Item { Layout.fillWidth: true }

        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: root.px(38)
          radius: 0
          color: theme.panel
          border.width: 1
          border.color: theme.border

          TextInput {
            id: search
            anchors.fill: parent
            anchors.leftMargin: root.px(12)
            anchors.rightMargin: root.px(12)
            verticalAlignment: TextInput.AlignVCenter
            color: theme.foreground
            selectionColor: "#4d565d"
            font.pixelSize: root.px(13)
            clip: true
            text: root.query
            onTextChanged: {
              if (text.length > 0) root.freezeCardTop()
              root.query = text
              root.selectedIndex = 0
              root.rebuild()
            }

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.selectedIndex = Math.min(appModel.count - 1, root.selectedIndex + 1)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.launch(root.selectedIndex)
                event.accepted = true
              }
            }
          }
        }

        ListView {
          id: appList
          Layout.fillWidth: true
          Layout.preferredHeight: root.visibleRowsHeight
          Layout.maximumHeight: root.visibleRowsHeight
          clip: true
          spacing: root.rowSpacing
          model: appModel
          currentIndex: root.selectedIndex

          delegate: Rectangle {
            required property string name
            required property string detail
            required property string desktopId
            required property string icon
            required property int index

            width: appList.width
            height: root.rowHeight(detail)
            radius: 0
            color: index === root.selectedIndex ? theme.selected : "transparent"

            Image {
              width: root.px(24)
              height: root.px(24)
              anchors.left: parent.left
              anchors.leftMargin: root.px(12)
              anchors.verticalCenter: parent.verticalCenter
              source: Quickshell.iconPath(icon, true)
              sourceSize.width: root.px(48)
              sourceSize.height: root.px(48)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }

            Column {
              anchors.left: parent.left
              anchors.leftMargin: root.px(50)
              anchors.right: parent.right
              anchors.rightMargin: root.px(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: root.px(2)

              Text {
                text: name
                color: index === root.selectedIndex ? theme.foreground : theme.brightForeground
                font.pixelSize: root.px(13)
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                visible: root.query.length > 0 && detail.length > 0
                text: detail
                color: theme.muted
                font.pixelSize: root.px(10)
                elide: Text.ElideRight
                width: parent.width
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = index
              onClicked: root.launch(index)
            }
          }

          Text {
            anchors.centerIn: parent
            visible: appModel.count === 0
            text: "No applications found"
            color: theme.muted
            font.pixelSize: root.px(13)
          }
        }
      }
    }
  }
}
