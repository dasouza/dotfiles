import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Hover card for the Ethernet icon, in the style of the Wi-Fi card: connection name and link
// speed, speed / duplex / MTU tiles, live traffic, and the addresses.
HoverPopup {
    id: popup

    property var device: null
    readonly property string iface: device?.name ?? ""
    readonly property bool connected: device?.connected ?? false

    // From scripts/net-info.sh; refreshed when the card opens.
    property var info: ({})
    property int mtu: 0
    readonly property int speed: Number(info.speed ?? -1)
    readonly property string speedText: speed >= 1000 ? `${+(speed / 1000).toFixed(1)} Gb/s` : speed > 0 ? `${speed} Mb/s` : "—"

    edge: Edges.Right
    onOpening: {
        infoQuery.running = true;
        mtuFile.reload();
    }

    Process {
        id: infoQuery
        command: ["sh", Quickshell.shellPath("scripts/net-info.sh"), popup.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        found[line.slice(0, i)] = line.slice(i + 1);
                }
                popup.info = found;
            }
        }
    }
    FileView {
        id: mtuFile
        path: popup.iface ? `/sys/class/net/${popup.iface}/mtu` : ""
        onLoaded: popup.mtu = Number(text().trim()) || 0
    }

    Rectangle {
        implicitWidth: 400
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

            // Full ring when connected, empty while waiting for an address.
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Gauge {
                    implicitWidth: 40
                    implicitHeight: 40
                    thickness: 3
                    sweep: 360
                    value: popup.connected ? 1 : 0
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(popup.connected ? 0xef09 : 0xf1616)
                        color: popup.connected ? Theme.accent : Theme.textDim
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
                        text: popup.info.conn || "Ethernet"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize + 1
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: popup.connected ? "Connected  ·  click for network settings" : "Cable plugged in, no connection yet"
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize - 3
                    }
                }
                Text {
                    visible: popup.speed > 0
                    text: popup.speedText
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.barFontSize + 5
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StatTile {
                    glyph: 0xf04c5
                    label: "Speed"
                    value: popup.speed > 0 ? `${popup.speed} Mb/s` : "—"
                }
                StatTile {
                    label: "Duplex"
                    value: popup.info.duplex === "full" ? "Full" : popup.info.duplex === "half" ? "Half" : "—"
                }
                StatTile {
                    label: "MTU"
                    value: popup.mtu > 0 ? `${popup.mtu}` : "—"
                }
            }

            TrafficGraph {
                visible: popup.connected
                iface: popup.iface
                active: popup.open && popup.connected
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 14
                rowSpacing: 3

                Repeater {
                    model: [
                        ["IP", popup.info.ip],
                        ["Gateway", popup.info.gateway],
                        ["DNS", popup.info.dns],
                        ["MAC", popup.info.mac],
                        ["Interface", popup.iface]
                    ].filter(r => r[1]).reduce((cells, r) => cells.concat([{ label: true, text: r[0] }, { label: false, text: r[1].split(" | ").join(", ") }]), [])

                    Text {
                        required property var modelData
                        Layout.fillWidth: !modelData.label
                        elide: Text.ElideRight
                        text: modelData.text
                        color: modelData.label ? Theme.textDim : Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize - 3
                    }
                }
            }
        }
    }
}
