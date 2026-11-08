import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Click to keep the screen awake (hypridle won't dim/lock).
Text {
    id: root
    property bool active: false

    IdleInhibitor {
        enabled: root.active
        window: root.QsWindow.window
    }

    text: String.fromCodePoint(active ? 0xf06e8 : 0xf06e9)
    color: active ? Theme.accent : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.barFontSize

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.active = !root.active
    }
}
