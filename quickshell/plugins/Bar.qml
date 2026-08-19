import QtQuick
import QtQuick.Layouts

Item {
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 8

    Workspaces {
      Layout.alignment: Qt.AlignVCenter
    }

    Item {
      Layout.fillWidth: true
    }

    Clock {
      Layout.alignment: Qt.AlignVCenter
    }

    Item {
      Layout.fillWidth: true
    }

    Status {
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
