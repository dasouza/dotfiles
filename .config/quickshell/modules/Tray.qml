import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

// Tray icons tucked into a card: click the chevron to show or hide them.
// Hidden when no app has a tray icon.
Text {
    id: root
    property bool expanded: false

    visible: SystemTray.items.values.length > 0
    text: String.fromCodePoint(expanded ? 0xf0143 : 0xf0140)
    color: expanded ? Theme.accent : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.barFontSize

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }

    // Driven by the click rather than hover, so the card stays put while an app's
    // right-click menu (a separate window) is open.
    HoverPopup {
        owner: root
        ownerHovered: root.expanded
        edge: Edges.Right

        RowLayout {
            spacing: 10

            Repeater {
                model: SystemTray.items.values

                IconImage {
                    id: icon
                    required property var modelData

                    source: modelData.icon
                    implicitSize: 22

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton && !icon.modelData.onlyMenu) {
                                icon.modelData.activate();
                                root.expanded = false;
                            } else if (icon.modelData.hasMenu) {
                                const p = icon.mapToItem(null, 0, icon.height);
                                icon.modelData.display(icon.QsWindow.window, p.x, p.y);
                            }
                        }
                    }
                }
            }
        }
    }
}
