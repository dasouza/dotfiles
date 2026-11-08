import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Cloudflare WARP: shown only where warp-cli is installed. Click connects/disconnects;
// hovering shows the status. warp-cli has no usable change stream, so it's polled.
Text {
    id: root

    property bool installed: false
    // "Connected", "Disconnected", "Connecting", ...; "" when the daemon (warp-svc) isn't answering.
    property string status: ""
    property string reason: ""
    readonly property bool up: status === "Connected" || status === "Connecting"

    visible: installed
    text: String.fromCodePoint(up ? 0xe792 : 0xf0164)
    color: popup.open ? Theme.accent
         : status === "Connected" ? Theme.accent
         : status === "" ? Theme.urgent
         : status === "Disconnected" ? Theme.textDim : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.barFontSize

    // Once at startup, so machines without WARP never poll.
    Process {
        running: true
        command: ["sh", "-c", "command -v warp-cli"]
        onExited: code => root.installed = code === 0
    }

    Timer {
        running: root.installed
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: statusQuery.running = true
    }

    // {"status": "Connected", "reason": "NetworkHealthy"}
    Process {
        id: statusQuery
        command: ["warp-cli", "--accept-tos", "-j", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.status = s.status ?? "";
                    root.reason = s.reason ?? "";
                } catch (e) {
                    root.status = "";
                    root.reason = "";
                }
            }
        }
    }

    Process {
        id: toggle
        command: ["warp-cli", "--accept-tos", root.up ? "disconnect" : "connect"]
        onExited: statusQuery.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!toggle.running) toggle.running = true
    }

    HoverHandler {
        id: hover
    }

    HoverPopup {
        id: popup
        owner: root
        ownerHovered: hover.hovered
        edge: Edges.Right

        ColumnLayout {
            spacing: 4

            Text {
                text: "Cloudflare WARP"
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
            Text {
                text: root.status === "" ? "Service not running (warp-svc)" : root.status
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
            // "NetworkHealthy" -> "Network healthy"
            Text {
                visible: root.reason !== ""
                text: root.reason.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/ [A-Z]/g, c => c.toLowerCase())
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
