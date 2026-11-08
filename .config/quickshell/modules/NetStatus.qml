import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import qs

// Ethernet, Wi-Fi and Bluetooth state; each has a hover card with the details.
// Click opens the Wi-Fi picker / nm-connection-editor (ethernet) / blueman-manager;
// right-click toggles Bluetooth.
RowLayout {
    id: root
    spacing: 10

    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property var bluetooth: Bluetooth.defaultAdapter

    component Icon: Text {
        property var action: null
        font.family: Theme.font
        font.pixelSize: Theme.barFontSize

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => parent.action?.(event.button)
        }
    }

    // Ethernet: plugged in and connected, or cable in but no IP yet.
    // Hovering shows the connection, link speed, live traffic and addresses (EthernetCard).
    Icon {
        id: ethernet
        visible: root.wired?.hasLink ?? false
        text: String.fromCodePoint(root.wired?.connected ? 0xef09 : 0xf1616)
        color: ethPopup.open ? Theme.accent : root.wired?.connected ? Theme.text : Theme.textDim
        action: () => Quickshell.execDetached(["nm-connection-editor"])

        HoverHandler {
            id: ethHover
        }

        EthernetCard {
            id: ethPopup
            owner: ethernet
            ownerHovered: ethHover.hovered
            device: root.wired
        }
    }

    // Wi-Fi: off, disconnected, or five signal levels.
    // Hovering shows the network, signal, band, link speed, live traffic and addresses (WifiCard).
    Icon {
        id: wifiIcon
        visible: root.wifi !== null
        text: String.fromCodePoint(!Networking.wifiEnabled ? 0xf092e
            : !root.wifiNetwork ? 0xf0923
            : [0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928][Math.min(4, Math.floor(root.wifiNetwork.signalStrength * 5))])
        color: wifiPopup.open || picker.open ? Theme.accent : !Networking.wifiEnabled ? Theme.urgent : root.wifiNetwork ? Theme.text : Theme.textDim
        action: () => picker.open = !picker.open

        HoverHandler {
            id: wifiHover
        }

        WifiPicker {
            id: picker
            owner: wifiIcon
            device: root.wifi
        }

        // Not while the picker is open: it already shows the network.
        WifiCard {
            id: wifiPopup
            owner: wifiIcon
            ownerHovered: wifiHover.hovered && !picker.open
            device: root.wifi
            network: root.wifiNetwork
        }
    }

    // Bluetooth: off, on, or with a device connected.
    // Hovering shows the paired devices with their battery (BluetoothCard).
    Icon {
        id: btIcon
        visible: root.bluetooth !== null
        readonly property bool connected: root.bluetooth?.devices.values.some(d => d.connected) ?? false
        text: String.fromCodePoint(!root.bluetooth?.enabled ? 0xf00b2 : connected ? 0xf00b1 : 0xf00af)
        color: btPopup.open ? Theme.accent : !root.bluetooth?.enabled ? Theme.textDim : connected ? Theme.accent : Theme.text
        action: button => {
            if (button === Qt.RightButton)
                root.bluetooth.enabled = !root.bluetooth.enabled;
            else
                Quickshell.execDetached(["blueman-manager"]);
        }

        HoverHandler {
            id: btHover
        }

        BluetoothCard {
            id: btPopup
            owner: btIcon
            ownerHovered: btHover.hovered
            adapter: root.bluetooth
        }
    }
}
