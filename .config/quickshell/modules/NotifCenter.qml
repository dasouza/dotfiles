import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// Notification centre: a panel at the top right, under the bell, with history grouped by app
// (newest group first, three per group until expanded), do-not-disturb and clear-all. Opened by
// clicking the bell or Super+Shift+N; clicking outside it or Escape closes it. Opening it clears
// the popups. It's a layer-shell panel rather than a popup of the bar because Hyprland's focus
// grab treated every click inside a popup as outside, closing it before buttons got the click.
PanelWindow {
    id: panel

    required property Item owner

    visible: Notifs.centerOpen
    anchors {
        top: true
        right: true
    }
    margins {
        top: 6
        right: 8
    }
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: 440
    implicitHeight: card.implicitHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-centre"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // The bar is included so clicking the bell closes the panel instead of reopening it.
    HyprlandFocusGrab {
        active: panel.visible
        windows: [panel, panel.owner.QsWindow.window]
        onCleared: Notifs.centerOpen = false
    }

    readonly property var groups: {
        const byApp = new Map();
        for (const e of Notifs.history) {
            const app = e.appName || "Other";
            if (!byApp.has(app))
                byApp.set(app, []);
            byApp.get(app).push(e);
        }
        return [...byApp].map(([app, entries]) => ({ app, entries }));
    }
    property var expandedApps: ({})

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + 28
        radius: 14
        color: Theme.background
        border.color: Theme.accent
        border.width: 2
        focus: true
        Keys.onEscapePressed: Notifs.centerOpen = false

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Notifications"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.barFontSize + 1
                    font.bold: true
                }
                Chip {
                    visible: Notifs.history.length > 0
                    label: Notifs.history.length
                }
                Item {
                    Layout.fillWidth: true
                }
                PillButton {
                    glyph: Notifs.dnd ? 0xf009b : 0xf009a
                    label: "Do not disturb"
                    active: Notifs.dnd
                    onClicked: Notifs.dnd = !Notifs.dnd
                }
                PillButton {
                    visible: Notifs.history.length > 0
                    glyph: 0xf0e2c
                    label: "Clear"
                    onClicked: Notifs.clearAll()
                }
            }

            Text {
                visible: Notifs.onGameWorkspace && !Notifs.dnd
                text: "Paused while on the game workspace"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }

            // Empty state, centred across the panel. The icon uses the Propo variant of the font:
            // in the regular one icons are drawn wider than their slot, so they look off-centre.
            ColumnLayout {
                visible: Notifs.history.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 28
                Layout.bottomMargin: 28
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: String.fromCodePoint(0xf009a)
                    color: Theme.track
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 48
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "All up to date!"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: Theme.barFontSize
                }
            }

            Flickable {
                visible: Notifs.history.length > 0
                Layout.fillWidth: true
                implicitHeight: Math.min(groupList.implicitHeight, 600)
                contentHeight: groupList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: groupList
                    width: parent.width
                    spacing: 14

                    Repeater {
                        model: panel.groups

                        ColumnLayout {
                            id: group
                            required property var modelData
                            readonly property bool open: panel.expandedApps[modelData.app] ?? false
                            readonly property int hidden: modelData.entries.length - 3

                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: group.modelData.app
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                }
                                Chip {
                                    visible: group.modelData.entries.length > 1
                                    label: group.modelData.entries.length
                                }
                                Text {
                                    text: `• ${Notifs.age(group.modelData.entries[0].time)}`
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                PillButton {
                                    visible: group.hidden > 0
                                    label: group.open ? "Show less" : `Show ${group.hidden} more`
                                    onClicked: {
                                        const apps = Object.assign({}, panel.expandedApps);
                                        apps[group.modelData.app] = !group.open;
                                        panel.expandedApps = apps;
                                    }
                                }
                                PillButton {
                                    glyph: 0xf0156
                                    onClicked: {
                                        for (const e of group.modelData.entries)
                                            Notifs.remove(e);
                                    }
                                }
                            }

                            Repeater {
                                model: group.open ? group.modelData.entries : group.modelData.entries.slice(0, 3)

                                NotifCard {
                                    required property var modelData
                                    entry: modelData
                                    inCenter: true
                                    Layout.fillWidth: true
                                    onSwipedAway: Notifs.remove(entry)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
