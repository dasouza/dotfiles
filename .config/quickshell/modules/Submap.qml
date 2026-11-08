import QtQuick
import Quickshell.Hyprland
import qs

// Pill shown while a Hyprland submap (resize mode, Super+R) is active.
// Hyprland announces it with "submap>>name"; leaving sends an empty name (or "default").
Rectangle {
    id: root
    property string submap: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap")
                root.submap = event.data === "default" ? "" : event.data;
        }
    }

    visible: submap !== ""
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 6
    radius: height / 2
    color: Theme.accent

    Text {
        id: label
        anchors.centerIn: parent
        text: String.fromCodePoint(0xf0a68) + "  " + root.submap.toUpperCase()
        color: Theme.accentText
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
    }
}
