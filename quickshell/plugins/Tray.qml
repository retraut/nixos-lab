import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Omarchy-style system tray drawer. Tray applications such as ChatGPT, Steam,
// and Bitwarden belong to this one group instead of being rendered as loose
// status widgets at the edge of the bar.
Item {
  id: root

  property var theme: null
  property string fontFamily: "JetBrainsMono Nerd Font"
  property bool expanded: false
  property bool trayMenuOpen: false
  property var activeTrayWindow: null
  property real activeTrayX: 0
  property real activeTrayY: 0
  property var activeTrayMenu: null
  property var trayMenuStack: []
  readonly property color foreground: theme ? theme.foreground : "#cacccc"
  readonly property color hover: theme ? theme.panel : "#1e2327"
  readonly property color border: theme ? theme.border : "#252b30"
  readonly property int itemExtent: 28
  readonly property int iconExtent: 18

  readonly property var items: {
    var values = SystemTray.items.values || []
    var result = []
    for (var i = 0; i < values.length; i++) {
      if (values[i].status !== Status.Passive) result.push(values[i])
    }
    return result
  }

  visible: root.items.length > 0
  implicitWidth: visible ? (root.expanded ? root.itemExtent * (root.items.length + 1) : root.itemExtent) : 0
  implicitHeight: root.itemExtent

  Behavior on implicitWidth {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  QsMenuOpener {
    id: trayMenuOpener
    menu: root.activeTrayMenu
  }

  function closeTrayMenu() {
    root.trayMenuOpen = false
    root.activeTrayMenu = null
    root.trayMenuStack = []
  }

  function openTrayMenu(item, anchorItem, mouse) {
    if (!item) return

    // Items without a nested menu expose the platform tray menu directly.
    // This is the same fallback Omarchy uses for simple tray applications.
    if (!item.menu && typeof item.display === "function") {
      var window = anchorItem.QsWindow.window
      var point = anchorItem.QsWindow.contentItem.mapFromItem(anchorItem, mouse.x, mouse.y)
      item.display(window, point.x, point.y)
      return
    }

    if (!item.menu) return
    var trayWindow = anchorItem.QsWindow.window
    var trayPoint = anchorItem.QsWindow.contentItem.mapFromItem(
      anchorItem, anchorItem.width, anchorItem.height + 4
    )
    root.trayMenuStack = []
    root.activeTrayWindow = trayWindow
    root.activeTrayX = Math.round(trayPoint.x)
    root.activeTrayY = Math.round(trayPoint.y)
    root.activeTrayMenu = item.menu
    root.trayMenuOpen = true
  }

  function enterTraySubmenu(entry) {
    if (!entry || !entry.hasChildren) return
    var stack = root.trayMenuStack.slice()
    stack.push(root.activeTrayMenu)
    root.trayMenuStack = stack
    root.activeTrayMenu = entry
  }

  function leaveTraySubmenu() {
    if (root.trayMenuStack.length === 0) return
    var stack = root.trayMenuStack.slice()
    root.activeTrayMenu = stack.pop()
    root.trayMenuStack = stack
  }

  HoverHandler {
    id: trayHover
    onHoveredChanged: root.expanded = hovered
  }

  Rectangle {
    id: drawerButton
    width: root.itemExtent
    height: root.itemExtent
    color: drawerMouse.containsMouse ? root.hover : "transparent"
    border.width: drawerMouse.containsMouse ? 1 : 0
    border.color: root.border
    radius: 0

    Text {
      anchors.centerIn: parent
      text: root.expanded ? "›" : "‹"
      color: root.foreground
      font.pixelSize: 20
      font.family: root.fontFamily
      font.bold: true
    }

    MouseArea {
      id: drawerMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.expanded = !root.expanded
        else root.expanded = !root.expanded
      }
    }
  }

  Row {
    id: trayRow
    x: root.itemExtent
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    visible: root.expanded

    function displayMenu(item, anchorItem, mouse) {
      if (!item) return

      var window = anchorItem.QsWindow ? anchorItem.QsWindow.window : null
      var contentItem = anchorItem.QsWindow ? anchorItem.QsWindow.contentItem : null
      if (!window || !contentItem) return

      var point = contentItem.mapFromItem(anchorItem, mouse.x, mouse.y)

      // Quickshell tray items without a nested QsMenu expose the platform
      // menu through item.display(). Some items expose a menu handle instead;
      // support both forms, matching Omarchy's tray implementation.
      if (typeof item.display === "function") {
        item.display(window, point.x, point.y)
      } else if (item.menu && typeof item.menu.display === "function") {
        item.menu.display(window, point.x, point.y)
      }
    }

    Repeater {
      model: root.items

      delegate: Item {
        required property var modelData
        width: root.itemExtent
        height: root.itemExtent

        Rectangle {
          anchors.fill: parent
          color: itemMouse.containsMouse ? root.hover : "transparent"
          border.width: itemMouse.containsMouse ? 1 : 0
          border.color: root.border
          radius: 0
        }

        Image {
          anchors.centerIn: parent
          width: root.iconExtent
          height: root.iconExtent
          source: String(modelData.icon || "")
          sourceSize.width: 36
          sourceSize.height: 36
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }

        MouseArea {
          id: itemMouse
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
              if (modelData.secondaryActivate) modelData.secondaryActivate()
            } else if (mouse.button === Qt.RightButton) {
              root.openTrayMenu(modelData, parent, mouse)
            } else if (modelData.onlyMenu) {
              root.openTrayMenu(modelData, parent, mouse)
            } else if (modelData.activate) {
              modelData.activate()
            }
          }

          // Tray apps may expose a different primary action for a deliberate
          // double click. Keep the normal left click and right-click menu
          // behavior intact, but make the missing double-click gesture useful
          // for Slack, ChatGPT, and similar tray applications.
          onDoubleClicked: {
            if (modelData.activate) modelData.activate()
          }
        }
      }
    }
  }

  PopupWindow {
    id: trayMenuPopup
    visible: root.trayMenuOpen
    color: "transparent"
    implicitWidth: 280
    implicitHeight: Math.min(420, Math.max(44, trayMenuColumn.implicitHeight + 12))

    anchor {
      window: root.activeTrayWindow
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Left
      rect.x: root.activeTrayX
      rect.y: root.activeTrayY
      rect.width: 1
      rect.height: 1
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      color: root.theme ? root.theme.background : "#101315"
      border.width: 1
      border.color: root.border
      radius: 0

      Column {
        id: trayMenuColumn
        anchors.fill: parent
        anchors.margins: 6
        spacing: 0

        Item {
          visible: root.trayMenuStack.length > 0
          width: parent.width
          height: visible ? 28 : 0

          Text {
            anchors.fill: parent
            text: "‹  Back"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.leaveTraySubmenu()
          }
        }

        Repeater {
          model: trayMenuOpener.children

          delegate: Item {
            required property var modelData
            width: trayMenuColumn.width
            height: modelData.isSeparator ? 10 : 30
            opacity: modelData.enabled === false ? 0.45 : 1.0

            Rectangle {
              anchors.fill: parent
              visible: !modelData.isSeparator
              color: menuMouse.containsMouse ? root.hover : "transparent"
              radius: 0
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: 1
              visible: modelData.isSeparator
              color: root.border
            }

            Image {
              anchors.left: parent.left
              anchors.leftMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              width: 16
              height: 16
              visible: !modelData.isSeparator && String(modelData.icon || "") !== ""
              source: String(modelData.icon || "")
              fillMode: Image.PreserveAspectFit
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 28
              anchors.right: parent.right
              anchors.rightMargin: modelData.hasChildren ? 24 : 8
              anchors.verticalCenter: parent.verticalCenter
              visible: !modelData.isSeparator
              text: String(modelData.text || "")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 16
              elide: Text.ElideRight
            }

            Text {
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              visible: !modelData.isSeparator && modelData.hasChildren
              text: "›"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 18
            }

            MouseArea {
              id: menuMouse
              anchors.fill: parent
              enabled: !modelData.isSeparator && modelData.enabled !== false
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.hasChildren) root.enterTraySubmenu(modelData)
                else {
                  if (modelData.triggered) modelData.triggered()
                  root.closeTrayMenu()
                }
              }
            }
          }
        }
      }
    }
  }
}
