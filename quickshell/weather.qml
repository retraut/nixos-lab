import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "plugins/WeatherIcons.js" as WeatherIcons

// Small Open-Meteo weather panel. Location is detected through ipinfo.io, then
// the coordinates are used for the current, hourly, and seven-day forecast.
ShellRoot {
  id: root

  Theme { id: theme }
  property bool opened: false
  property string mode: "now"
  property var weather: ({})
  property string location: "Detecting location…"
  property real latitude: NaN
  property real longitude: NaN
  property string errorText: ""

  function open(which) {
    root.mode = which === "week" ? "week" : "now"
    root.opened = true
    root.errorText = ""
    locationProcess.running = true
  }

  function close() { root.opened = false }

  Component.onCompleted: {
    var requested = Quickshell.env("NIXOS_WEATHER_MODE")
    if (requested) root.open(requested)
  }

  IpcHandler {
    target: "nixos-weather"
    function now(): void { root.open("now") }
    function week(): void { root.open("week") }
    function toggle(): void { root.opened ? root.close() : root.open("now") }
  }

  function codeIcon(code, isDay) {
    return WeatherIcons.icon(code, isDay)
  }

  function codeText(code) {
    var c = Number(code)
    if (c === 0) return "Clear"
    if (c === 1 || c === 2) return "Partly cloudy"
    if (c === 3) return "Overcast"
    if (c === 45 || c === 48) return "Fog"
    if (c >= 51 && c <= 57) return "Drizzle"
    if (c >= 61 && c <= 67) return "Rain"
    if (c >= 71 && c <= 77) return "Snow"
    if (c >= 80 && c <= 82) return "Showers"
    if (c >= 95) return "Thunderstorm"
    return "Unknown"
  }

  function hourLabel(value) {
    var d = new Date(String(value || ""))
    return isNaN(d.getTime()) ? "--" : Qt.formatTime(d, "HH:mm")
  }

  function dayLabel(value) {
    var d = new Date(String(value || "") + "T12:00:00")
    return isNaN(d.getTime()) ? "--" : Qt.formatDate(d, "dddd")
  }

  function current() { return root.weather.current || ({}) }
  function hourly() { return root.weather.hourly || ({}) }
  function daily() { return root.weather.daily || ({}) }

  // Open-Meteo returns current.time and hourly.time in the same local
  // timezone because the request uses timezone=auto. Start the hourly row at
  // the current local hour instead of always rendering the array from 00:00.
  function hourlyStartIndex() {
    var times = root.hourly().time || []
    if (!times.length) return 0

    var currentTime = String(root.current().time || "")
    var currentHour = currentTime.length >= 13 ? currentTime.substring(0, 13) : ""
    if (currentHour) {
      for (var i = 0; i < times.length; i++) {
        if (String(times[i]).substring(0, 13) === currentHour) return i
      }
    }

    // Fallback for a response without current.time: choose the latest hourly
    // point that has already started according to the local machine clock.
    var now = new Date().getTime()
    var best = 0
    for (var j = 0; j < times.length; j++) {
      var point = new Date(String(times[j])).getTime()
      if (!isNaN(point) && point <= now) best = j
    }
    return best
  }

  Process {
    id: locationProcess
    command: ["curl", "-fsS", "--max-time", "8", "https://ipinfo.io/json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var report = JSON.parse(String(text || "{}"))
          var coordinates = String(report.loc || "").split(",")
          root.latitude = Number(coordinates[0])
          root.longitude = Number(coordinates[1])
          root.location = String(report.city || "Current location")
          if (isNaN(root.latitude) || isNaN(root.longitude)) throw new Error("No coordinates")
          weatherProcess.command = ["curl", "-fsS", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude
            + "&longitude=" + root.longitude
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&forecast_days=7&timezone=auto"]
          weatherProcess.running = true
        } catch (e) {
          root.errorText = "Could not detect location"
        }
      }
    }
  }

  Process {
    id: weatherProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.weather = JSON.parse(String(text || "{}"))
          root.errorText = ""
        } catch (e) {
          root.errorText = "Weather service unavailable"
        }
      }
    }
  }

  Timer {
    interval: 900000
    repeat: true
    running: root.opened
    onTriggered: locationProcess.running = true
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nixos-weather"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
      id: card
      implicitWidth: content.implicitWidth + 36
      implicitHeight: content.implicitHeight + 36
      width: Math.min(Math.max(1100, implicitWidth), 1600)
      height: Math.min(root.mode === "week" ? Math.max(456, implicitHeight) : implicitHeight, 900)
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.topMargin: 44
      color: theme.background
      border.width: 1
      border.color: theme.border
      focus: true

      MouseArea { anchors.fill: parent; onClicked: {} }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
        if (event.key === Qt.Key_1) { root.mode = "now"; event.accepted = true }
        if (event.key === Qt.Key_2) { root.mode = "week"; event.accepted = true }
      }

      ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 22
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          Column {
            spacing: 2
            Text { text: root.location; color: theme.foreground; font.pixelSize: theme.widgetFontSize; font.weight: Font.Medium }
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            implicitWidth: 110; implicitHeight: 42; color: root.mode === "now" ? theme.selected : theme.panel
            Text { anchors.centerIn: parent; text: "NOW"; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
            MouseArea { anchors.fill: parent; onClicked: root.mode = "now" }
          }
          Rectangle {
            implicitWidth: 110; implicitHeight: 42; color: root.mode === "week" ? theme.selected : theme.panel
            Text { anchors.centerIn: parent; text: "7 DAYS"; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
            MouseArea { anchors.fill: parent; onClicked: root.mode = "week" }
          }
        }

        Text {
          visible: root.errorText !== ""
          text: root.errorText
          color: theme.urgent
          font.pixelSize: theme.widgetFontSize
        }

        RowLayout {
          visible: root.mode === "now" && root.errorText === ""
          Layout.fillWidth: true
          spacing: 16
          Text {
            text: root.codeIcon(root.current().weather_code, root.current().is_day)
            color: theme.accent
            font.pixelSize: 72
            font.family: theme.fontFamily
          }
          Column {
            spacing: 3
            Text { text: root.current().temperature_2m !== undefined ? Math.round(root.current().temperature_2m) + "°C" : "…"; color: theme.brightForeground; font.pixelSize: 30 }
            Text { text: root.codeText(root.current().weather_code); color: theme.foreground; font.pixelSize: theme.widgetFontSize }
          }
          Item { Layout.fillWidth: true }
          RowLayout {
            Layout.preferredWidth: 420
            Layout.fillHeight: true
            spacing: 24

            Column {
              Layout.fillWidth: true
              spacing: 3
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Feels"; color: theme.muted; font.pixelSize: theme.widgetFontSize }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.current().apparent_temperature !== undefined ? Math.round(root.current().apparent_temperature) + "°C" : "…"; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
            }

            Column {
              Layout.fillWidth: true
              spacing: 3
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Wind"; color: theme.muted; font.pixelSize: theme.widgetFontSize }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.current().wind_speed_10m !== undefined ? Math.round(root.current().wind_speed_10m) + " km/h" : "…"; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
            }

            Column {
              Layout.fillWidth: true
              spacing: 3
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Humidity"; color: theme.muted; font.pixelSize: theme.widgetFontSize }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.current().relative_humidity_2m !== undefined ? root.current().relative_humidity_2m + "%" : "…"; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
            }
          }
        }

        RowLayout {
          visible: root.mode === "now"
          Layout.fillWidth: true
          spacing: 3
          Repeater {
            model: 8
            delegate: Rectangle {
              required property int index
              readonly property int hourIndex: root.hourlyStartIndex() + index
              Layout.fillWidth: true
              Layout.preferredWidth: 118
              Layout.preferredHeight: 124
              color: theme.panel
              Column {
                anchors.centerIn: parent
                spacing: 5
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.hourLabel(root.hourly().time && root.hourly().time[hourIndex] ? root.hourly().time[hourIndex] : ""); color: theme.muted; font.pixelSize: theme.widgetFontSize }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.codeIcon(root.hourly().weather_code && root.hourly().weather_code[hourIndex] !== undefined ? root.hourly().weather_code[hourIndex] : -1, 1)
                  color: theme.accent
                  font.pixelSize: 28
                  font.family: theme.fontFamily
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.hourly().temperature_2m && root.hourly().temperature_2m[hourIndex] !== undefined ? Math.round(root.hourly().temperature_2m[hourIndex]) + "°" : "…"; color: theme.foreground; font.pixelSize: theme.widgetFontSize }
              }
            }
          }
        }

        ColumnLayout {
          visible: root.mode === "week"
          Layout.fillWidth: true
          spacing: 4
          Repeater {
            model: 7
            delegate: Rectangle {
              required property int index
              Layout.fillWidth: true
              Layout.preferredHeight: 58
              color: index % 2 === 0 ? theme.panel : "transparent"
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                Item {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Layout.preferredWidth: 1
                  Text {
                    anchors.centerIn: parent
                    text: root.daily().time ? root.dayLabel(root.daily().time[index]) : "…"
                    color: theme.foreground
                    font.pixelSize: theme.widgetFontSize
                  }
                }
                Item {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Layout.preferredWidth: 1
                  Row {
                    anchors.centerIn: parent
                    width: 200
                    spacing: 10
                    Text {
                      width: 32
                      text: root.daily().weather_code && root.daily().weather_code[index] !== undefined ? root.codeIcon(root.daily().weather_code[index], 1) : "…"
                      color: theme.accent
                      font.pixelSize: 28
                      font.family: theme.fontFamily
                      horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.daily().weather_code && root.daily().weather_code[index] !== undefined ? root.codeText(root.daily().weather_code[index]) : "…"
                      color: theme.muted
                      font.pixelSize: theme.widgetFontSize
                    }
                  }
                }
                Item {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Layout.preferredWidth: 1
                  Text {
                    anchors.centerIn: parent
                    text: root.daily().temperature_2m_max && root.daily().temperature_2m_min ? Math.round(root.daily().temperature_2m_max[index]) + "° / " + Math.round(root.daily().temperature_2m_min[index]) + "°" : "…"
                    color: theme.foreground
                    font.pixelSize: theme.widgetFontSize
                  }
                }
              }
            }
          }
        }

        Item { Layout.fillHeight: root.mode === "week" }
      }
    }
  }
}
