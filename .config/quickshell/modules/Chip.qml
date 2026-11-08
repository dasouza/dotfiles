import QtQuick
import qs

// Small rounded count badge.
Rectangle {
    id: chip

    property var label

    implicitWidth: Math.max(chipText.implicitWidth + 12, 20)
    implicitHeight: 20
    radius: 10
    color: Theme.track

    Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.label
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 3
    }
}
