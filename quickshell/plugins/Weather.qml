import QtQuick
import Quickshell
import Quickshell.Io
import "WeatherIcons.js" as WeatherIcons

// Bar-side weather summary. Location comes from ipinfo.io and forecast data
// from Open-Meteo. Its interaction surface follows the same BarWidget /
// WidgetButton contract as the other bar modules.
BarWidget {
  id: root

  signal activated()
  signal secondaryActivated()
  property var theme: null
  property color textColor: theme ? theme.foreground : "#cacccc"
  property color hoverColor: theme ? theme.panel : "#1e2327"
  property string summary: ""
  property string location: ""
  property real latitude: NaN
  property real longitude: NaN
  property int fontSize: 19
  property string fontFamily: "JetBrainsMono Nerd Font"
  property bool hovered: button.containsMouse

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!weather.running) weather.running = true
  }

  Component.onCompleted: refresh()

  Process {
    id: weather
    command: ["curl", "-fsS", "--max-time", "6", "https://ipinfo.io/json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var report = JSON.parse(String(text || "{}"))
          var coordinates = String(report.loc || "").split(",")
          root.latitude = Number(coordinates[0])
          root.longitude = Number(coordinates[1])
          if (isNaN(root.latitude) || isNaN(root.longitude)) throw new Error("No coordinates")
          root.location = String(report.city || "Current location")
          forecast.command = ["curl", "-fsS", "--max-time", "6",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude
            + "&longitude=" + root.longitude
            + "&current=temperature_2m,weather_code,is_day&timezone=auto"]
          forecast.running = true
        } catch (e) {
          root.summary = ""
        }
      }
    }
  }

  Process {
    id: forecast
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var current = (JSON.parse(String(text || "{}")) || {}).current || ({})
          // Match Omarchy's bar: one Nerd Font weather glyph, no temperature
          // in the bar. The details panel still contains all measurements.
          root.summary = root.codeIcon(current.weather_code, current.is_day)
        } catch (e) {
          root.summary = ""
        }
      }
    }
  }

  function codeIcon(code, isDay) {
    return WeatherIcons.icon(code, isDay)
  }

  Timer {
    interval: 900000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    text: root.summary
    foreground: root.textColor
    hoverColor: root.hoverColor
    fontSize: root.fontSize
    fontFamily: root.fontFamily
    onPressed: function(button) {
      if (button === Qt.RightButton || button === Qt.MiddleButton)
        root.secondaryActivated()
      else
        root.activated()
    }
  }

}
