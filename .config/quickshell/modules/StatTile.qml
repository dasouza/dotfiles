import QtQuick
import QtQuick.Layouts
import qs

// Small tile for the hover cards (battery, Wi-Fi): optional icon + label on top, value below.
Rectangle {
    id: tile
    property int glyph
    property string label
    property string value

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: statCol.implicitHeight + 16
    radius: 8
    color: Theme.background
    border.color: Theme.track
    border.width: 1

    ColumnLayout {
        id: statCol
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: (tile.glyph ? String.fromCodePoint(tile.glyph) + " " : "") + tile.label
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: Theme.barFontSize - 5
        }
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: tile.value
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.barFontSize - 1
            font.bold: true
        }
    }
}
