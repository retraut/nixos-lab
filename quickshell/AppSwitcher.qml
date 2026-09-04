import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Wayland._ToplevelManagement

// macOS-style application switcher for the local Quickshell desktop.
// Hyprland only sends the next/previous command; this component owns the
// visual list and commits the selected toplevel when the modifier is released.
Item {
  id: root

  Theme { id: theme }

  property bool opened: false
  property bool overviewMode: false
  property int selectedIndex: 0
  property string heldModifier: ""
  property var closeTarget: null
  property var groups: []
  // Remember the most recently focused toplevel for every application. This
  // lets app switching return to the same window after cycling windows with
  // Alt/Super+`.
  property var lastWindowByApp: ({})

  readonly property int normalGap: Math.max(4, Math.min(14, Math.floor((panel.width - 72) / Math.max(1, root.groups.length * 12))))
  readonly property int cardWidth: root.overviewMode
    ? 176
    : Math.min(176, Math.max(44, Math.floor((panel.width - 72 - Math.max(0, root.groups.length - 1) * root.normalGap) / Math.max(1, root.groups.length))))
  readonly property int iconSize: root.overviewMode
    ? 108
    : Math.max(28, Math.min(108, root.cardWidth - 12))
  readonly property int cardHeight: root.overviewMode ? 190 : root.iconSize + 54
  readonly property int overviewColumns: Math.max(1, Math.min(5, Math.floor((panel.width - 140) / (cardWidth + 14))))
  readonly property int overviewRows: Math.max(1, Math.ceil(groups.length / overviewColumns))

  function appIdFor(toplevel) {
    if (!toplevel) return ""
    return String(toplevel.appId || "").trim().toLowerCase()
  }

  // Chromium web apps expose a generated appId such as
  // "chrome-x.com__-Default". Match that host against the declarative
  // desktop entry's --app URL so web apps use their real name and icon.
  function webHostFor(id) {
    var raw = String(id || "").trim().toLowerCase()
    if (raw.indexOf("chrome-") !== 0) return ""

    var host = raw.slice("chrome-".length).split("__")[0]
    return host.replace(/^www\./, "")
  }

  function webEntryFor(id) {
    var host = root.webHostFor(id)
    if (!host) return null

    var values = DesktopEntries.applications.values || []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      var exec = String(entry.execString || "").toLowerCase()
      var match = exec.match(/--app=https?:\/\/([^ "'\t]+)/)
      if (!match) continue

      var entryHost = match[1]
        .replace(/\/.*$/, "")
        .replace(/^www\./, "")
      if (entryHost === host) return entry
    }
    return null
  }

  function entryFor(id) {
    return root.webEntryFor(id) || DesktopEntries.heuristicLookup(id)
  }

  function groupName(id) {
    var entry = root.entryFor(id)
    return entry
      ? String(entry.name || entry.genericName || entry.id || id)
      : id
  }

  function groupIcon(id) {
    var entry = root.entryFor(id)
    var icon = entry && entry.icon ? String(entry.icon) : "application-x-executable"
    return Quickshell.iconPath(icon, true)
  }

  function rememberActiveWindow() {
    var active = ToplevelManager.activeToplevel
    var id = root.appIdFor(active)
    if (!active || !id || active.parent) return
    root.lastWindowByApp[id] = active
  }

  function preferredWindow(group) {
    if (!group || group.windows.length === 0) return null

    var remembered = root.lastWindowByApp[group.id]
    for (var i = 0; i < group.windows.length; i++) {
      if (group.windows[i] === remembered) return remembered
    }
    return group.windows[0]
  }

  function refreshGroups() {
    var previousId = root.opened && root.groups[root.selectedIndex]
      ? root.groups[root.selectedIndex].id : ""
    var values = ToplevelManager.toplevels.values || []
    var next = []

    for (var i = 0; i < values.length; i++) {
      var toplevel = values[i]
      var id = root.appIdFor(toplevel)
      if (!id || toplevel.parent) continue

      var found = -1
      for (var j = 0; j < next.length; j++) {
        if (next[j].id === id) {
          found = j
          break
        }
      }

      if (found < 0) {
        next.push({
          id: id,
          name: root.groupName(id),
          icon: root.groupIcon(id),
          windows: [toplevel]
        })
      } else {
        next[found].windows.push(toplevel)
      }
    }

    // Keep navigation deterministic: Alt+Tab and horizontal gestures use
    // the same case-insensitive alphabetical app order every time.
    next.sort(function(a, b) {
      var left = String(a.name).toLowerCase()
      var right = String(b.name).toLowerCase()
      if (left < right) return -1
      if (left > right) return 1
      return String(a.id).localeCompare(String(b.id))
    })

    root.groups = next
    if (previousId) {
      for (var k = 0; k < next.length; k++) {
        if (next[k].id === previousId) {
          root.selectedIndex = k
          break
        }
      }
    }
    root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, next.length - 1))
  }

  function selectRelative(delta) {
    root.refreshGroups()
    if (root.groups.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.groups.length) % root.groups.length
  }

  function open(modifier, direction) {
    root.refreshGroups()
    if (root.groups.length === 0) return

    var activeId = root.appIdFor(ToplevelManager.activeToplevel)
    var activeIndex = -1
    for (var i = 0; i < root.groups.length; i++) {
      if (root.groups[i].id === activeId) {
        activeIndex = i
        break
      }
    }

    root.overviewMode = false
    root.heldModifier = modifier
    root.opened = true
    if (activeIndex >= 0) {
      root.selectedIndex = (activeIndex + direction + root.groups.length) % root.groups.length
    } else {
      root.selectedIndex = direction > 0 ? 0 : root.groups.length - 1
    }
    Qt.callLater(function() { keyboard.forceActiveFocus() })
  }

  function altTab() {
    root.nextApp()
  }

  function altShiftTab() {
    root.previousApp()
  }

  function commandTab() {
    if (!root.opened) root.open("command", 1)
    else root.selectRelative(1)
  }

  function commandShiftTab() {
    if (!root.opened) root.open("command", -1)
    else root.selectRelative(-1)
  }

  function cycleWindow(delta) {
    root.refreshGroups()
    var active = ToplevelManager.activeToplevel
    var activeId = root.appIdFor(active)
    if (!activeId) return

    for (var i = 0; i < root.groups.length; i++) {
      var group = root.groups[i]
      if (group.id !== activeId || group.windows.length < 2) continue

      var activeIndex = -1
      for (var j = 0; j < group.windows.length; j++) {
        if (group.windows[j] === active) {
          activeIndex = j
          break
        }
      }
      if (activeIndex < 0) activeIndex = 0
      var targetIndex = (activeIndex + delta + group.windows.length) % group.windows.length
      group.windows[targetIndex].activate()
      return
    }
  }

  function nextWindow() { root.cycleWindow(1) }
  function previousWindow() { root.cycleWindow(-1) }

  function closeCurrentWindow() {
    var active = ToplevelManager.activeToplevel
    if (!active) return

    var activeId = root.appIdFor(active)
    var values = ToplevelManager.toplevels.values || []
    var target = null
    for (var i = 0; i < values.length; i++) {
      var candidate = values[i]
      if (candidate !== active && !candidate.parent && root.appIdFor(candidate) === activeId) {
        target = candidate
        break
      }
    }

    // Keep focus inside the app group after closing one of its windows.
    root.closeTarget = target
    active.close()
    if (target) closeFocusTimer.restart()
  }

  function cycleApp(delta) {
    root.refreshGroups()
    if (root.groups.length < 2) return

    var activeId = root.appIdFor(ToplevelManager.activeToplevel)
    var activeIndex = -1
    for (var i = 0; i < root.groups.length; i++) {
      if (root.groups[i].id === activeId) {
        activeIndex = i
        break
      }
    }
    if (activeIndex < 0) activeIndex = 0

    var targetIndex = (activeIndex + delta + root.groups.length) % root.groups.length
    var target = root.groups[targetIndex]
    if (!target || target.windows.length === 0) return
    if (root.opened) root.cancel()
    var targetWindow = root.preferredWindow(target)
    if (targetWindow) targetWindow.activate()
  }

  function nextApp() { root.cycleApp(1) }
  function previousApp() { root.cycleApp(-1) }

  function commitModifier(modifier) {
    if (root.opened && root.heldModifier === modifier) {
      root.commit()
    }
  }

  function overview() {
    root.refreshGroups()
    if (root.groups.length === 0) return

    if (root.opened && root.overviewMode) {
      root.cancel()
      return
    }

    root.overviewMode = true
    root.heldModifier = ""
    var activeId = root.appIdFor(ToplevelManager.activeToplevel)
    root.selectedIndex = 0
    for (var i = 0; i < root.groups.length; i++) {
      if (root.groups[i].id === activeId) {
        root.selectedIndex = i
        break
      }
    }
    root.opened = true
    Qt.callLater(function() { keyboard.forceActiveFocus() })
  }

  function cancel() {
    root.opened = false
    root.overviewMode = false
    root.heldModifier = ""
    root.selectedIndex = 0
  }

  function commit() {
    if (!root.opened || root.groups.length === 0) return
    var group = root.groups[root.selectedIndex]
    var target = root.preferredWindow(group)
    root.cancel()
    if (target) Qt.callLater(function() { target.activate() })
  }

  IpcHandler {
    target: "nixos-app-switcher"

    function altTab(): void { root.altTab() }
    function altShiftTab(): void { root.altShiftTab() }
    function commandTab(): void { root.commandTab() }
    function commandShiftTab(): void { root.commandShiftTab() }
    function nextWindow(): void { root.nextWindow() }
    function previousWindow(): void { root.previousWindow() }
    function closeCurrentWindow(): void { root.closeCurrentWindow() }
    function nextApp(): void { root.nextApp() }
    function previousApp(): void { root.previousApp() }
    function commitCommand(): void { root.commitModifier("command") }
    function overview(): void { root.overview() }
    function cancel(): void { root.cancel() }
  }

  Timer {
    id: closeFocusTimer
    interval: 50
    repeat: false
    onTriggered: {
      if (root.closeTarget) root.closeTarget.activate()
      root.closeTarget = null
    }
  }

  Timer {
    interval: 180
    repeat: true
    running: root.opened
    onTriggered: root.refreshGroups()
  }

  Component.onCompleted: {
    root.refreshGroups()
    root.rememberActiveWindow()
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { root.rememberActiveWindow() }
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.refreshGroups() }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-app-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: theme.scrim

      MouseArea {
        anchors.fill: parent
        onClicked: root.cancel()
      }

      Rectangle {
        id: switcherCard
        width: root.overviewMode
          ? Math.min(panel.width - 72, Math.max(600, root.overviewColumns * (root.cardWidth + 14) + 44))
          : Math.min(panel.width - 72, root.groups.length * root.cardWidth + Math.max(0, root.groups.length - 1) * root.normalGap + 44)
        height: root.overviewMode
          ? Math.min(panel.height - 96, root.overviewRows * (root.cardHeight + 14) + 76)
          : root.cardHeight + 64
        anchors.centerIn: parent
        radius: 22
        color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.94)
        border.width: 1
        border.color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.28)

        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
          visible: root.overviewMode
          anchors.top: parent.top
          anchors.topMargin: 18
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Mission Control"
          color: theme.foreground
          font.family: theme.fontFamily
          font.pixelSize: 18
          font.weight: Font.Medium
        }

        Flow {
          id: appRow
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: root.overviewMode ? parent.verticalCenter : parent.verticalCenter
          width: Math.min(parent.width - 44, root.groups.length * root.cardWidth + Math.max(0, root.groups.length - 1) * (root.overviewMode ? 14 : root.normalGap))
          spacing: root.overviewMode ? 14 : root.normalGap

          Repeater {
            model: root.groups

            delegate: Rectangle {
              required property var modelData
              required property int index
              width: root.cardWidth
              height: root.cardHeight
              radius: 16
              color: index === root.selectedIndex ? theme.selected : "transparent"
              border.width: index === root.selectedIndex ? 2 : 1
              border.color: index === root.selectedIndex ? theme.accent : "transparent"

              IconImage {
                anchors.top: parent.top
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.iconSize
                height: root.iconSize
                source: modelData.icon
                asynchronous: true
                mipmap: true
              }

              Text {
                visible: index === root.selectedIndex
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                text: modelData.name
                color: theme.foreground
                font.family: theme.fontFamily
                font.pixelSize: 15
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }

              Rectangle {
                visible: modelData.windows.length > 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                width: 26
                height: 26
                radius: 13
                color: theme.accent

                Text {
                  anchors.centerIn: parent
                  text: modelData.windows.length
                  color: theme.background
                  font.family: theme.fontFamily
                  font.pixelSize: 13
                  font.weight: Font.Bold
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.selectedIndex = index
                onClicked: {
                  root.selectedIndex = index
                  root.commit()
                }
              }
            }
          }
        }

        Item {
          id: keyboard
          anchors.fill: parent
          focus: true
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.cancel()
              event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
              root.selectRelative(event.modifiers & Qt.ShiftModifier ? -1 : 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Left) {
              root.selectRelative(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Right) {
              root.selectRelative(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.commit()
              event.accepted = true
            }
          }

          Keys.onReleased: function(event) {
            var releasedAlt = event.key === Qt.Key_Alt
            var releasedCommand = event.key === Qt.Key_Meta
            if ((releasedAlt && root.heldModifier === "alt")
                || (releasedCommand && root.heldModifier === "command")) {
              root.commit()
              event.accepted = true
            }
          }
        }
      }
    }
  }
}
