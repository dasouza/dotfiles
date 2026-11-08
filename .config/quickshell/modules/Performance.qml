import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

// CPU, CPU temperature and RAM as small ring gauges (no numbers). Hovering opens a performance card:
// CPU and GPU (load, temperature, model) on top, memory and disk rings below.
RowLayout {
    id: root
    spacing: 8

    function levelColor(value, warning, critical) {
        return value >= critical ? Theme.urgent : value >= warning ? Theme.warning : Theme.accent;
    }
    readonly property real memPct: Resources.memTotal > 0 ? 100 * Resources.memUsed / Resources.memTotal : 0
    readonly property real diskPct: Resources.diskTotal > 0 ? 100 * Resources.diskUsed / Resources.diskTotal : 0

    HoverHandler {
        id: hover
    }

    MiniGauge {
        glyph: 0xf0ee0
        value: Resources.cpu / 100
        color: root.levelColor(Resources.cpu, 75, 90)
    }
    MiniGauge {
        glyph: 0xf2c9
        value: Resources.cpuTemp / 100
        color: root.levelColor(Resources.cpuTemp, 70, 80)
    }
    MiniGauge {
        glyph: 0xf035b
        value: root.memPct / 100
        color: root.levelColor(root.memPct, 75, 85)
    }

    HoverPopup {
        id: popup
        owner: root
        ownerHovered: hover.hovered
        edge: Edges.Left

        GridLayout {
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            HeroCard {
                title: "CPU"
                subtitle: Resources.cpuName
                glyph: 0xf0ee0
                usage: Resources.cpu
                usageColor: root.levelColor(Resources.cpu, 75, 90)
                temp: Resources.cpuTemp
            }
            HeroCard {
                visible: Resources.hasGpu
                title: "GPU"
                subtitle: Resources.gpuName
                glyph: 0xf08ae
                usage: Resources.gpu
                usageColor: root.levelColor(Resources.gpu, 75, 90)
                temp: Resources.gpuTemp
                extra: Resources.gpuAsleep ? "Asleep (power saving)"
                     : Resources.vramTotal > 0 ? `VRAM ${Resources.gib(Resources.vramUsed)} / ${Resources.gib(Resources.vramTotal)} GiB` : ""
            }
            RingCard {
                title: "Memory"
                glyph: 0xf035b
                percent: root.memPct
                ringColor: root.levelColor(root.memPct, 75, 85)
                detail: `${Resources.gib(Resources.memUsed)} / ${Resources.gib(Resources.memTotal)} GiB`
            }
            RingCard {
                title: "Disk  /"
                glyph: 0xf02ca
                percent: root.diskPct
                ringColor: root.levelColor(root.diskPct, 80, 90)
                detail: `${Resources.gib(Resources.diskUsed)} / ${Resources.gib(Resources.diskTotal)} GiB`
            }
        }
    }

    // Bar item: ring with the icon inside; the numbers are in the card.
    component MiniGauge: Gauge {
        id: mini
        property int glyph
        implicitWidth: 26
        implicitHeight: 26

        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(mini.glyph)
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // CPU / GPU: icon in a load ring, name, temperature with a 0–100°C bar, and the load % in a
    // big circle that heats up with it.
    component HeroCard: Rectangle {
        id: hero
        property string title
        property string subtitle
        property string extra
        property int glyph
        property int usage
        property color usageColor
        property int temp
        readonly property color tempColor: temp >= 80 ? Theme.urgent : temp >= 70 ? Theme.warning : Theme.accent

        implicitWidth: 300
        implicitHeight: 140
        radius: 12
        color: Theme.surface
        border.color: Theme.track
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                RowLayout {
                    spacing: 10

                    Gauge {
                        implicitWidth: 38
                        implicitHeight: 38
                        thickness: 3
                        value: hero.usage / 100
                        color: hero.usageColor

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(hero.glyph)
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 17
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        CardText {
                            text: hero.title
                            color: Theme.accent
                            font.bold: true
                            font.pixelSize: Theme.barFontSize + 1
                        }
                        CardText {
                            text: hero.subtitle
                            color: Theme.textDim
                            font.pixelSize: Theme.barFontSize - 3
                        }
                    }
                }

                CardText {
                    visible: text !== ""
                    text: hero.extra
                    color: Theme.textDim
                    font.pixelSize: Theme.barFontSize - 3
                }

                Item {
                    Layout.fillHeight: true
                }

                CardText {
                    text: String.fromCodePoint(0xf2c9) + `  ${hero.temp}°C`
                    color: hero.tempColor
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: Theme.track

                    Rectangle {
                        width: parent.width * Math.min(1, hero.temp / 100)
                        height: parent.height
                        radius: parent.radius
                        color: hero.tempColor
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
            }

            ColumnLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                CardText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Usage"
                    color: Theme.textDim
                    font.pixelSize: Theme.barFontSize - 3
                }
                Rectangle {
                    implicitWidth: 72
                    implicitHeight: 72
                    radius: 36
                    color: hero.usageColor
                    Behavior on color { ColorAnimation { duration: 300 } }

                    Text {
                        anchors.centerIn: parent
                        text: `${hero.usage}%`
                        color: Theme.accentText
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize + 5
                        font.bold: true
                    }
                }
            }
        }
    }

    // Memory / disk: big ring with the percentage inside, label and used/total beside it.
    component RingCard: Rectangle {
        id: ring
        property string title
        property string detail
        property int glyph
        property real percent
        property color ringColor

        implicitWidth: 300
        implicitHeight: 120
        radius: 12
        color: Theme.surface
        border.color: Theme.track
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 16

            Gauge {
                implicitWidth: 92
                implicitHeight: 92
                thickness: 8
                value: ring.percent / 100
                color: ring.ringColor

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: -2
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${Math.round(ring.percent)}%`
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize + 3
                        font.bold: true
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Used"
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize - 4
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                CardText {
                    text: String.fromCodePoint(ring.glyph) + `  ${ring.title}`
                    color: Theme.accent
                    font.bold: true
                    font.pixelSize: Theme.barFontSize + 1
                }
                CardText {
                    text: ring.detail
                    color: Theme.text
                    font.pixelSize: Theme.barFontSize - 2
                }
            }
        }
    }

    component CardText: Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.barFontSize - 1
    }
}
