import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Hover card for a network icon: interface name, optional detail line (Wi-Fi network),
// and the interface's IPv4 address(es).
HoverPopup {
    id: popup

    property string iface: ""
    property string detail: ""
    property var addresses: []

    edge: Edges.Right
    onOpening: ipQuery.running = true

    // Quickshell.Networking has no IP addresses, so ask NetworkManager each time the card opens.
    // -g prints "192.168.1.10/24 | 10.0.0.2/8" for several addresses.
    Process {
        id: ipQuery
        command: ["nmcli", "-g", "IP4.ADDRESS", "device", "show", popup.iface]
        stdout: StdioCollector {
            onStreamFinished: popup.addresses = text.split(/[|\n]/).map(s => s.trim()).filter(s => s)
        }
    }

    ColumnLayout {
        spacing: 4

        Text {
            text: popup.iface
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
        Text {
            visible: popup.detail !== ""
            text: popup.detail
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Repeater {
            model: popup.addresses.length > 0 ? popup.addresses : ["No IP address"]

            Text {
                required property string modelData
                text: modelData
                color: popup.addresses.length > 0 ? Theme.text : Theme.textDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
