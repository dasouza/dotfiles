import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Power menu (Super+M): the screen dims and a card with Lock / Log out / Restart / Shut down
// pops in. Left/Right or Tab move, Enter picks, the underlined letter picks directly,
// Escape or clicking the dimmed area cancels.
PanelWindow {
    id: menu

    property bool open: false
    property int selected: 0

    readonly property var choices: [
        { label: "Lock", key: Qt.Key_L, glyph: 0xf033e, run: () => Session.lock() },
        { label: "Log out", key: Qt.Key_O, glyph: 0xf0343, run: () => Session.logout() },
        { label: "Restart", key: Qt.Key_R, glyph: 0xf0709, run: () => Session.reboot() },
        { label: "Shut down", key: Qt.Key_S, glyph: 0xf0425, run: () => Session.poweroff() }
    ]

    function pick(i) {
        open = false;
        choices[i].run();
    }

    onOpenChanged: {
        if (open) {
            selected = 0;
            Qt.callLater(() => card.forceActiveFocus()); // once the window is mapped
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void {
            menu.open = !menu.open;
        }
    }

    // Kept mapped while it fades out.
    visible: open || fade.running
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        id: dim
        anchors.fill: parent
        color: "#000000"
        opacity: menu.open ? 0.55 : 0
        Behavior on opacity {
            NumberAnimation { id: fade; duration: 200 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: menu.open = false
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 40
        implicitHeight: column.implicitHeight + 40
        radius: 22
        color: Theme.background
        border.color: Theme.accent
        border.width: 2

        opacity: menu.open ? 1 : 0
        scale: menu.open ? 1 : 0.92
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Swallow clicks on the card so they don't reach the dimmed area behind it.
        MouseArea {
            anchors.fill: parent
        }

        Keys.onPressed: event => {
            const n = menu.choices.length;
            const direct = menu.choices.findIndex(c => c.key === event.key);
            if (event.key === Qt.Key_Escape) {
                menu.open = false;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                menu.selected = (menu.selected + 1) % n;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                menu.selected = (menu.selected + n - 1) % n;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                menu.pick(menu.selected);
            } else if (direct >= 0) {
                menu.pick(direct);
            } else {
                return;
            }
            event.accepted = true;
        }

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: 18

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "What do you want to do?"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.barFontSize + 1
                font.bold: true
            }

            RowLayout {
                id: row
                spacing: 14

                Repeater {
                    model: menu.choices

                    Rectangle {
                        id: choice
                        required property var modelData
                        required property int index
                        readonly property bool current: menu.selected === index

                        implicitWidth: 128
                        implicitHeight: 128
                        radius: 18
                        color: current ? Theme.accent : Theme.surface
                        border.color: current ? Theme.accent : Theme.track
                        border.width: 1
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: String.fromCodePoint(choice.modelData.glyph)
                                color: choice.current ? Theme.accentText : Theme.accent
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 40
                            }
                            // The shortcut letter is underlined.
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                textFormat: Text.StyledText
                                text: {
                                    const label = choice.modelData.label;
                                    const i = label.toLowerCase().indexOf(String.fromCharCode(choice.modelData.key).toLowerCase());
                                    return `${label.slice(0, i)}<u>${label[i]}</u>${label.slice(i + 1)}`;
                                }
                                color: choice.current ? Theme.accentText : Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 1
                                font.bold: choice.current
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: menu.selected = choice.index
                            onClicked: menu.pick(choice.index)
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Esc to cancel"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
