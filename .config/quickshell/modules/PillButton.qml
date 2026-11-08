import QtQuick
import QtQuick.Layouts
import qs

// Rounded button with an optional glyph and label; amber while hovered or `active`.
Rectangle {
    id: pill

    property int glyph: 0
    property string label
    property bool active: false
    signal clicked

    implicitWidth: pillRow.implicitWidth + 16
    implicitHeight: 26
    radius: 13
    color: active || pillHover.hovered ? Theme.accent : Theme.surface

    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: pill.glyph !== 0
            text: pill.glyph ? String.fromCodePoint(pill.glyph) : ""
            color: pill.active || pillHover.hovered ? Theme.accentText : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Text {
            visible: pill.label !== ""
            text: pill.label
            color: pill.active || pillHover.hovered ? Theme.accentText : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
    }
    HoverHandler {
        id: pillHover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: pill.clicked()
    }
}
