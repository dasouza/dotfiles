import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs

// Hover card for the Wi-Fi icon, in the style of the performance and battery cards: signal ring
// and network name, band / channel / link speed tiles, live traffic with a small graph, and the
// addresses. Off or disconnected, it only says so.
// (Inline components fail to load in some modules here, so it's built from plain items.)
HoverPopup {
    id: popup

    property var device: null
    property var network: null
    readonly property string iface: device?.name ?? ""
    readonly property bool connected: Networking.wifiEnabled && network !== null
    readonly property int signal: Math.round((network?.signalStrength ?? 0) * 100)
    readonly property color signalColor: signal < 25 ? Theme.urgent : signal < 45 ? Theme.warning : Theme.accent

    // From scripts/net-info.sh; refreshed while the card is open.
    property var info: ({})

    edge: Edges.Right
    onOpening: infoQuery.running = true

    function signalGlyph(strength) {
        return [0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928][Math.min(4, Math.floor(strength * 5))];
    }
    readonly property int freq: Number(info.freq ?? 0)
    readonly property string band: freq >= 5925 ? "6 GHz" : freq >= 4900 ? "5 GHz" : freq > 0 ? "2.4 GHz" : "—"
    // Wi-Fi 6 on 6 GHz is sold as 6E.
    readonly property string generation: !info.gen ? "" : info.gen === "6" && freq >= 5925 ? "Wi-Fi 6E" : `Wi-Fi ${info.gen}`

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

    // Signal and bitrate drift, so the details are re-read every few seconds while open.
    Timer {
        running: popup.open && popup.connected
        interval: 4000
        repeat: true
        onTriggered: infoQuery.running = true
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

            // Signal ring with the Wi-Fi icon, network name and security, big signal %.
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Gauge {
                    implicitWidth: 40
                    implicitHeight: 40
                    thickness: 3
                    value: popup.connected ? popup.signal / 100 : 0
                    color: popup.signalColor

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(!Networking.wifiEnabled ? 0xf092e
                            : !popup.connected ? 0xf0923 : popup.signalGlyph(popup.network.signalStrength))
                        color: Networking.wifiEnabled ? Theme.accent : Theme.urgent
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
                        text: popup.connected ? popup.network.name : "Wi-Fi"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize + 1
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: !Networking.wifiEnabled ? "Off · click to turn on"
                            : !popup.connected ? "Not connected · click to choose a network"
                            : [String.fromCodePoint(popup.info.security ? 0xf033e : 0xf0fc6) + " " + (popup.info.security || "Open"),
                               popup.generation].filter(s => s).join("  ·  ")
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize - 3
                    }
                }
                ColumnLayout {
                    visible: popup.connected
                    spacing: -2

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: `${popup.signal}%`
                        color: popup.signalColor
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize + 9
                        font.bold: true
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        visible: popup.info.dbm !== undefined
                        text: `${popup.info.dbm} dBm`
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize - 4
                    }
                }
            }

            // Band, channel and link speed.
            RowLayout {
                visible: popup.connected
                Layout.fillWidth: true
                spacing: 8

                StatTile {
                    glyph: 0xf05a9
                    label: "Band"
                    value: popup.band
                }
                // Wider than the others: "149 · 160 MHz" is the longest value.
                StatTile {
                    Layout.preferredWidth: 1.6
                    label: "Channel"
                    value: !popup.info.chan ? "—" : popup.info.width ? `${popup.info.chan} · ${popup.info.width} MHz` : popup.info.chan
                }
                StatTile {
                    glyph: 0xf04c5
                    label: "Link"
                    value: popup.info.rx ? `${Math.round(Number(popup.info.rx))} Mb/s` : "—"
                }
            }

            TrafficGraph {
                visible: popup.connected
                iface: popup.iface
                active: popup.open && popup.connected
            }

            // Addresses: label column and value column.
            GridLayout {
                visible: popup.connected
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
