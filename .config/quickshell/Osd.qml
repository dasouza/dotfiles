import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Volume / mic / brightness popup. The volume keys call wpctl directly; this reacts to PipeWire, so
// it also shows for changes made elsewhere (pavucontrol, per-app volume keys...). The brightness keys
// run brightnessctl and then `qs ipc call osd brightness`, which reads the new level back.
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    property string kind: "volume" // "volume", "mic" or "brightness"
    readonly property bool mic: kind === "mic"
    property real backlight: 0
    property bool shown: false

    IpcHandler {
        target: "osd"
        function brightness(): void {
            brightnessctl.running = true;
        }
    }
    Process {
        id: brightnessctl
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "intel_backlight,backlight,12000,50%,24000": device,class,current,percent,max
                const f = text.trim().split("\n")[0].split(",");
                if (f.length < 5 || !(Number(f[4]) > 0))
                    return;
                root.backlight = Number(f[2]) / Number(f[4]);
                root.show("brightness");
            }
        }
    }

    // Volume and mute are only populated for tracked nodes.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Values get filled in on startup and when the default device switches; don't pop up for that.
    property bool settled: false
    onSinkChanged: unsettle()
    onSourceChanged: unsettle()
    function unsettle() {
        settled = false;
        settle.restart();
    }
    Timer {
        id: settle
        interval: 500
        running: true
        onTriggered: root.settled = true
    }

    function show(what) {
        if (!settled)
            return;
        kind = what;
        shown = true;
        hide.restart();
    }
    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() { root.show("mic"); }
    }

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: kind === "brightness" ? false
                                : mic ? source?.audio?.muted ?? false : sink?.audio?.muted ?? false
    // Fill of the progress bar (none for the mic, which is just on/off)
    readonly property real level: kind === "brightness" ? backlight : volume

    readonly property string icon: String.fromCodePoint(
        kind === "brightness" ? (backlight >= 0.66 ? 0xf00e0 : backlight >= 0.33 ? 0xf00df : 0xf00de)
        : mic ? (muted ? 0xf036d : 0xf036c)
        : muted ? 0xf075f : volume >= 0.66 ? 0xf057e : volume >= 0.33 ? 0xf0580 : 0xf057f)
    readonly property string label: mic ? (muted ? "Microphone muted" : "Microphone on")
                                        : muted ? "Muted" : `${Math.round(level * 100)}%`

    LazyLoader {
        active: root.shown

        PanelWindow {
            // Only the bottom anchor: centred horizontally, above windows, click-through.
            anchors.bottom: true
            margins.bottom: 120
            exclusiveZone: 0
            implicitWidth: 320
            implicitHeight: 56
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-osd"

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Theme.background
                border.color: root.muted ? Theme.textDim : Theme.accent
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 14

                    Text {
                        text: root.icon
                        color: root.muted ? Theme.textDim : Theme.accent
                        font.family: Theme.font
                        font.pixelSize: 22
                    }

                    // Progress bar for the output only; the mic just shows on/off.
                    Rectangle {
                        visible: !root.mic
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Theme.surface

                        Rectangle {
                            width: parent.width * Math.min(root.level, 1)
                            height: parent.height
                            radius: parent.radius
                            color: root.muted ? Theme.textDim : Theme.accent
                        }
                    }

                    Text {
                        Layout.fillWidth: root.mic
                        Layout.minimumWidth: 44
                        horizontalAlignment: root.mic ? Text.AlignLeft : Text.AlignRight
                        text: root.label
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }
}
