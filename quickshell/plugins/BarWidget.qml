import QtQuick

// Shared contract for every widget mounted in QuattroBar. This mirrors the
// useful part of Omarchy's BarWidget: the host can inject common context and
// widgets get one place for settings/helpers instead of inventing their own
// plumbing.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }
}
