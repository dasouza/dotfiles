import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs

// Live traffic of a network interface for the Wi-Fi and Ethernet cards: current download and
// upload rates above a graph of the last 40 s (download filled, upload dashed). Samples the
// byte counters once a second while `active`, and starts over each time it becomes active.
Rectangle {
    id: graph

    property string iface: ""
    property bool active: false

    // Bytes per second, newest last.
    property var down: []
    property var up: []
    property var lastBytes: null
    readonly property int samples: 40

    function rate(bytes) {
        return bytes >= 1048576 ? `${(bytes / 1048576).toFixed(1)} MB/s`
             : bytes >= 1024 ? `${Math.round(bytes / 1024)} KB/s` : `${Math.round(bytes)} B/s`;
    }

    onActiveChanged: {
        if (active) {
            down = [];
            up = [];
            lastBytes = null;
        }
    }

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 20
    radius: 8
    color: Theme.background
    border.color: Theme.track
    border.width: 1

    Process {
        id: bytesQuery
        command: ["cat", `/sys/class/net/${graph.iface}/statistics/rx_bytes`, `/sys/class/net/${graph.iface}/statistics/tx_bytes`]
        stdout: StdioCollector {
            onStreamFinished: {
                const [rx, tx] = text.trim().split("\n").map(Number);
                const now = Date.now();
                const last = graph.lastBytes;
                if (last && now > last.t) {
                    const dt = (now - last.t) / 1000;
                    graph.down = graph.down.concat([Math.max(0, (rx - last.rx) / dt)]).slice(-graph.samples);
                    graph.up = graph.up.concat([Math.max(0, (tx - last.tx) / dt)]).slice(-graph.samples);
                }
                graph.lastBytes = { rx, tx, t: now };
            }
        }
    }

    Timer {
        running: graph.active && graph.iface !== ""
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: bytesQuery.running = true
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: String.fromCodePoint(0xf0045) + " " + (graph.down.length ? graph.rate(graph.down[graph.down.length - 1]) : "…")
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.barFontSize - 1
                font.bold: true
            }
            Text {
                text: String.fromCodePoint(0xf005d) + " " + (graph.up.length ? graph.rate(graph.up[graph.up.length - 1]) : "…")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.barFontSize - 1
                font.bold: true
            }
        }

        Canvas {
            id: canvas
            Layout.fillWidth: true
            implicitHeight: 46

            readonly property var series: [graph.down, graph.up]
            onSeriesChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                // Baseline.
                ctx.strokeStyle = Theme.track;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, height - 0.5);
                ctx.lineTo(width, height - 0.5);
                ctx.stroke();

                // Shared scale, at least 64 KB/s so an idle link stays flat.
                const peak = Math.max(65536, ...graph.down, ...graph.up);
                const step = width / (graph.samples - 1);
                const points = data => data.map((v, i) => [width - (data.length - 1 - i) * step, height - 2 - (height - 4) * v / peak]);

                const d = points(graph.down);
                if (d.length > 1) {
                    ctx.beginPath();
                    ctx.moveTo(d[0][0], height);
                    for (const [x, y] of d)
                        ctx.lineTo(x, y);
                    ctx.lineTo(d[d.length - 1][0], height);
                    ctx.closePath();
                    const grad = ctx.createLinearGradient(0, 0, 0, height);
                    grad.addColorStop(0, Qt.alpha(Theme.accent, 0.45));
                    grad.addColorStop(1, Qt.alpha(Theme.accent, 0.03));
                    ctx.fillStyle = grad;
                    ctx.fill();

                    ctx.beginPath();
                    d.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y));
                    ctx.strokeStyle = Theme.accent;
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                }

                const u = points(graph.up);
                if (u.length > 1) {
                    ctx.beginPath();
                    u.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y));
                    ctx.strokeStyle = Theme.textDim;
                    ctx.lineWidth = 1.2;
                    ctx.setLineDash([3, 2]);
                    ctx.stroke();
                }
            }
        }
    }
}
