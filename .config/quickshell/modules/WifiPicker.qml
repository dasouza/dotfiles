import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Wayland
import qs

// Wi-Fi picker: a panel at the top right, opened by clicking the Wi-Fi icon. Lists nearby
// networks (connected first, then by signal) while scanning; click one to connect, or to
// type its password if it's secured and not saved yet. The selected row also offers
// disconnect/forget. Clicking outside it or Escape closes it. A layer-shell panel rather
// than a popup for the same focus-grab reason as NotifCenter.
PanelWindow {
    id: panel

    required property Item owner
    required property var device
    property bool open: false

    // Name of the expanded row, the password typed for it and the last failure.
    property string selected: ""
    property string psk: ""
    property string failure: ""

    onOpenChanged: {
        selected = "";
        psk = "";
        failure = "";
        askPsk = "";
    }

    // Scan only while the picker is showing.
    Binding {
        target: panel.device
        property: "scannerEnabled"
        value: panel.open
        when: panel.device !== null
    }

    readonly property var networks: (device?.networks.values ?? [])
        .filter(n => n.name !== "")
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))

    function signalGlyph(strength) {
        return [0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928][Math.min(4, Math.floor(strength * 5))];
    }
    function secured(network) {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }
    // Saved and open networks connect straight away; the row stays expanded for disconnect/forget.
    function choose(network) {
        failure = "";
        psk = "";
        if (selected === network.name) {
            selected = "";
            return;
        }
        selected = network.name;
        if (!network.connected && (network.known || !secured(network)))
            network.connect();
    }
    function needsPsk(network) {
        return !network.connected && secured(network) && (!network.known || askPsk === network.name);
    }
    // Set when a saved network's password was rejected, so its row asks for a new one.
    property string askPsk: ""

    visible: open
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
    implicitWidth: 380
    implicitHeight: card.implicitHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wifi"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // The bar is included so clicking the Wi-Fi icon closes the panel instead of reopening it.
    HyprlandFocusGrab {
        active: panel.visible
        windows: [panel, panel.owner.QsWindow.window]
        onCleared: panel.open = false
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + 28
        radius: 14
        color: Theme.background
        border.color: Theme.accent
        border.width: 2
        focus: true
        Keys.onEscapePressed: panel.open = false

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Wi-Fi"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.barFontSize + 1
                    font.bold: true
                }
                Text {
                    text: panel.device?.name ?? ""
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                }
                Item {
                    Layout.fillWidth: true
                }
                PillButton {
                    glyph: Networking.wifiEnabled ? 0xf0928 : 0xf092e
                    label: Networking.wifiEnabled ? "On" : "Off"
                    active: Networking.wifiEnabled
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }
            }

            Text {
                visible: panel.failure !== ""
                Layout.fillWidth: true
                text: panel.failure
                color: Theme.urgent
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.Wrap
            }

            // Empty state: Wi-Fi off, or nothing found (yet).
            ColumnLayout {
                visible: !Networking.wifiEnabled || panel.networks.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.bottomMargin: 20
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: String.fromCodePoint(Networking.wifiEnabled ? 0xf0928 : 0xf092e)
                    color: Theme.track
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 48
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Networking.wifiEnabled ? "Searching for networks…" : "Wi-Fi is off"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: Theme.barFontSize
                }
            }

            Flickable {
                visible: Networking.wifiEnabled && panel.networks.length > 0
                Layout.fillWidth: true
                implicitHeight: Math.min(list.implicitHeight, 480)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 4

                    Repeater {
                        // ScriptModel keeps delegates for the same networks while the order changes.
                        model: ScriptModel {
                            values: panel.networks
                        }

                        Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool expanded: panel.selected === modelData.name
                            readonly property bool busy: modelData.stateChanging
                                || modelData.state === ConnectionState.Connecting

                            Layout.fillWidth: true
                            implicitHeight: rowContent.implicitHeight + 16
                            radius: Theme.radius
                            color: modelData.connected || expanded || rowHover.hovered ? Theme.surface : "transparent"
                            border.color: modelData.connected ? Theme.accent : Theme.track
                            border.width: modelData.connected || expanded ? 1 : 0

                            Connections {
                                target: row.modelData
                                function onConnectionFailed(reason) {
                                    panel.failure = `Couldn't connect to ${row.modelData.name}: ${ConnectionFailReason.toString(reason)}`;
                                    // Wrong or missing password: ask for it again.
                                    if (reason === ConnectionFailReason.NoSecrets && panel.secured(row.modelData)) {
                                        panel.selected = row.modelData.name;
                                        panel.askPsk = row.modelData.name;
                                        panel.psk = "";
                                    }
                                }
                            }

                            HoverHandler {
                                id: rowHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            ColumnLayout {
                                id: rowContent
                                anchors.fill: parent
                                anchors.margins: 8
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    TapHandler {
                                        onTapped: panel.choose(row.modelData)
                                    }

                                    Text {
                                        text: String.fromCodePoint(panel.signalGlyph(row.modelData.signalStrength))
                                        color: row.modelData.connected ? Theme.accent : Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.barFontSize
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.name
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        font.bold: row.modelData.connected
                                    }
                                    Text {
                                        text: row.busy ? (row.modelData.connected ? "Disconnecting…" : "Connecting…")
                                            : row.modelData.connected ? "Connected"
                                            : row.modelData.known ? "Saved" : ""
                                        visible: text !== ""
                                        color: row.modelData.connected ? Theme.accent : Theme.textDim
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 2
                                    }
                                    Text {
                                        visible: panel.secured(row.modelData)
                                        text: String.fromCodePoint(0xf033e)
                                        color: Theme.textDim
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                    }
                                }

                                // Password for a secured network that isn't saved yet (or was rejected).
                                RowLayout {
                                    visible: row.expanded && panel.needsPsk(row.modelData)
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        radius: 15
                                        color: Theme.background
                                        border.color: pskInput.activeFocus ? Theme.accent : Theme.track
                                        border.width: 1

                                        TextInput {
                                            id: pskInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: panel.psk
                                            onTextEdited: panel.psk = text
                                            echoMode: TextInput.Password
                                            color: Theme.text
                                            selectionColor: Theme.accent
                                            selectedTextColor: Theme.accentText
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize
                                            clip: true
                                            onAccepted: connectButton.clicked()

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: pskInput.text === ""
                                                text: "Password"
                                                color: Theme.textDim
                                                font: pskInput.font
                                            }
                                        }
                                    }
                                    PillButton {
                                        id: connectButton
                                        label: "Connect"
                                        onClicked: {
                                            if (panel.psk === "")
                                                return;
                                            panel.failure = "";
                                            panel.askPsk = "";
                                            row.modelData.connectWithPsk(panel.psk);
                                            panel.psk = "";
                                        }
                                    }
                                }

                                // Actions for the connected or a saved network.
                                RowLayout {
                                    visible: row.expanded && (row.modelData.connected || row.modelData.known)
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    PillButton {
                                        visible: row.modelData.connected
                                        glyph: 0xf0319
                                        label: "Disconnect"
                                        onClicked: {
                                            row.modelData.disconnect();
                                            panel.selected = "";
                                        }
                                    }
                                    PillButton {
                                        visible: row.modelData.known
                                        glyph: 0xf0a7a
                                        label: "Forget"
                                        onClicked: {
                                            row.modelData.forget();
                                            panel.selected = "";
                                        }
                                    }
                                }
                            }

                            onExpandedChanged: {
                                if (expanded && panel.needsPsk(modelData))
                                    pskInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }
                PillButton {
                    glyph: 0xf0493
                    label: "Network settings"
                    onClicked: {
                        panel.open = false;
                        Quickshell.execDetached(["nm-connection-editor"]);
                    }
                }
            }
        }
    }
}
