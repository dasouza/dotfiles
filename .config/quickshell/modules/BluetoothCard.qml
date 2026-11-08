import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs

// Hover card for the Bluetooth icon, in the style of the Wi-Fi card: adapter and an on/off
// switch, then the paired devices (connected first) with their battery where they report one.
// Clicking a device connects or disconnects it.
HoverPopup {
    id: popup

    property var adapter: null
    readonly property bool btOn: adapter?.enabled ?? false
    readonly property var devices: (adapter?.devices.values ?? [])
        .filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property int connectedCount: devices.filter(d => d.connected).length

    edge: Edges.Right

    // Freedesktop icon name from BlueZ → Nerd Font glyph.
    function deviceGlyph(icon) {
        return icon.includes("headset") ? 0xf02ce
             : icon.includes("headphone") || icon === "audio-card" ? 0xf02cb
             : icon.includes("speaker") ? 0xf04c3
             : icon.includes("mouse") ? 0xf037d
             : icon.includes("keyboard") ? 0xf030c
             : icon.includes("gaming") ? 0xf0297
             : icon.includes("phone") ? 0xf011c
             : icon.includes("computer") ? 0xf0322
             : 0xf00af;
    }
    function levelColor(battery) {
        return battery <= 0.15 ? Theme.urgent : battery <= 0.3 ? Theme.warning : Theme.good;
    }

    Rectangle {
        implicitWidth: 360
        implicitHeight: body.implicitHeight + 28
        radius: 12
        color: Theme.surface
        border.color: Theme.track
        border.width: 1

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Gauge {
                    implicitWidth: 40
                    implicitHeight: 40
                    thickness: 3
                    sweep: 360
                    value: popup.connectedCount > 0 ? 1 : 0
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(!popup.btOn ? 0xf00b2 : popup.connectedCount > 0 ? 0xf00b1 : 0xf00af)
                        color: popup.btOn ? Theme.accent : Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 17
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: "Bluetooth"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize + 1
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: !popup.btOn ? "Off"
                            : popup.connectedCount === 1 ? "1 device connected"
                            : popup.connectedCount > 1 ? `${popup.connectedCount} devices connected`
                            : popup.adapter?.discovering ? "On  ·  searching…" : "On  ·  nothing connected"
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize - 3
                    }
                }
                PillButton {
                    glyph: popup.btOn ? 0xf00af : 0xf00b2
                    label: popup.btOn ? "On" : "Off"
                    active: popup.btOn
                    onClicked: popup.adapter.enabled = !popup.adapter.enabled
                }
            }

            // Paired devices.
            ColumnLayout {
                visible: popup.btOn && popup.devices.length > 0
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: ScriptModel {
                        values: popup.devices
                    }

                    Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                                                     || modelData.state === BluetoothDeviceState.Disconnecting

                        Layout.fillWidth: true
                        implicitHeight: rowContent.implicitHeight + 16
                        radius: 8
                        color: modelData.connected || rowHover.hovered ? Theme.background : "transparent"
                        border.color: modelData.connected ? Theme.accent : Theme.track
                        border.width: modelData.connected || rowHover.hovered ? 1 : 0

                        HoverHandler {
                            id: rowHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: {
                                if (row.busy)
                                    return;
                                if (row.modelData.connected)
                                    row.modelData.disconnect();
                                else
                                    row.modelData.connect();
                            }
                        }

                        RowLayout {
                            id: rowContent
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Text {
                                text: String.fromCodePoint(popup.deviceGlyph(row.modelData.icon ?? ""))
                                color: row.modelData.connected ? Theme.accent : Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: Theme.barFontSize + 2
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: row.modelData.name
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: row.modelData.connected
                                }
                                Text {
                                    text: row.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                                        : row.modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                                        : row.modelData.connected ? "Connected" : "Paired  ·  click to connect"
                                    color: row.modelData.connected ? Theme.accent : Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 3
                                }
                            }

                            // Battery: small bar + percentage.
                            RowLayout {
                                visible: row.modelData.connected && row.modelData.batteryAvailable
                                spacing: 6

                                Rectangle {
                                    implicitWidth: 34
                                    implicitHeight: 6
                                    radius: 3
                                    color: Theme.track

                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, row.modelData.battery))
                                        height: parent.height
                                        radius: parent.radius
                                        color: popup.levelColor(row.modelData.battery)
                                    }
                                }
                                Text {
                                    text: `${Math.round(row.modelData.battery * 100)}%`
                                    color: popup.levelColor(row.modelData.battery)
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            // Empty state.
            Text {
                visible: !popup.btOn || popup.devices.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                horizontalAlignment: Text.AlignHCenter
                text: popup.btOn ? "No paired devices" : "Bluetooth is off"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }
                PillButton {
                    glyph: 0xf0493
                    label: "Bluetooth settings"
                    onClicked: Quickshell.execDetached(["blueman-manager"])
                }
            }
        }
    }
}
