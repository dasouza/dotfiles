import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs

// Workspaces 1–5 always, plus any higher one in use (10 = games). Each slot shows its number and
// the app icons of its windows; an amber pill slides to the focused one, stretching as it goes.
// Scratchpads with windows follow after a divider, outlined while shown.
// Click a workspace to go there, a scratchpad to toggle it; scroll to step through workspaces.
Item {
    id: root

    readonly property var workspaces: Hyprland.workspaces.values
    // The monitor's regular workspace, so an open scratchpad doesn't move the pill.
    readonly property int focusedId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
    readonly property var slots: {
        const ids = new Set([1, 2, 3, 4, 5]);
        for (const ws of workspaces)
            if (ws.id > 0)
                ids.add(ws.id);
        return [...ids].sort((a, b) => a - b);
    }
    readonly property var scratchpads: workspaces.filter(ws => ws.id < 0 && ws.toplevels.values.length > 0)

    function workspace(id) {
        return workspaces.find(ws => ws.id === id) ?? null;
    }
    // Same dispatcher form Quickshell itself sends to a Lua-config Hyprland.
    function goTo(id) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`);
    }

    // Which scratchpad is shown: Hyprland announces it with "activespecial>>special:name,monitor"
    // (empty name when hidden). The monitor query covers one already open at startup.
    property string openSpecial: ""
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial")
                root.openSpecial = event.data.split(",")[0];
        }
    }
    Connections {
        target: Hyprland.focusedMonitor
        function onLastIpcObjectChanged() {
            root.openSpecial = Hyprland.focusedMonitor.lastIpcObject?.specialWorkspace?.name ?? "";
        }
    }
    Component.onCompleted: Hyprland.refreshMonitors()

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    // Scroll steps one workspace per wheel notch (touchpad deltas add up to a notch first).
    property real scrolled: 0
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.scrolled += event.angleDelta.y;
            if (Math.abs(root.scrolled) < 120)
                return;
            const next = root.focusedId + (root.scrolled > 0 ? -1 : 1);
            root.scrolled = 0;
            if (next >= 1 && next <= 10)
                root.goTo(next);
        }
    }

    // Sliding pill. Each edge animates on its own and the trailing one is slower, so the pill
    // stretches towards the new workspace and then catches up.
    readonly property Item focusedItem: {
        slotRepeater.count; // re-evaluate when slots are added or removed
        const i = slots.indexOf(focusedId);
        return i >= 0 ? slotRepeater.itemAt(i) : null;
    }
    readonly property real targetLeft: focusedItem?.x ?? 0
    readonly property real targetRight: focusedItem ? focusedItem.x + focusedItem.width : 0
    property real pillLeft: 0
    property real pillRight: 0
    function movePill() {
        const goingRight = targetLeft >= pillLeft;
        leftAnim.duration = goingRight ? 340 : 180;
        rightAnim.duration = goingRight ? 180 : 340;
        pillLeft = targetLeft;
        pillRight = targetRight;
    }
    onTargetLeftChanged: movePill()
    onTargetRightChanged: movePill()
    Behavior on pillLeft {
        NumberAnimation { id: leftAnim; easing.type: Easing.OutCubic }
    }
    Behavior on pillRight {
        NumberAnimation { id: rightAnim; easing.type: Easing.OutCubic }
    }

    Rectangle {
        visible: root.focusedItem !== null
        x: row.x + root.pillLeft
        width: root.pillRight - root.pillLeft
        height: 26
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.radius
        color: Theme.accent
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            id: slotRepeater
            model: root.slots

            Item {
                id: slot
                required property int modelData
                readonly property var ws: root.workspace(modelData)
                readonly property var windows: ws?.toplevels.values ?? []
                readonly property bool focused: modelData === root.focusedId
                readonly property bool urgent: (ws?.urgent ?? false) && !focused

                implicitWidth: Math.max(content.implicitWidth + 16, 30)
                implicitHeight: 26

                Rectangle {
                    anchors.fill: parent
                    visible: slot.urgent
                    radius: Theme.radius
                    color: Theme.urgent
                }

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: slot.modelData
                        color: slot.focused || slot.urgent ? Theme.accentText
                             : slot.windows.length > 0 ? Theme.text : Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize
                        font.bold: slot.focused
                    }
                    Repeater {
                        model: slot.windows.slice(0, 4)
                        AppIcon {
                            required property var modelData
                            toplevel: modelData
                        }
                    }
                    Text {
                        visible: slot.windows.length > 4
                        text: `+${slot.windows.length - 4}`
                        color: slot.focused ? Theme.accentText : Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize - 3
                    }
                }

                TapHandler {
                    onTapped: root.goTo(slot.modelData)
                }
            }
        }

        Rectangle {
            visible: root.scratchpads.length > 0
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitWidth: 1
            implicitHeight: 16
            color: Theme.track
        }

        Repeater {
            model: root.scratchpads

            Rectangle {
                id: pad
                required property var modelData
                readonly property bool shown: root.openSpecial === modelData.name

                implicitWidth: icons.implicitWidth + 14
                implicitHeight: 26
                radius: Theme.radius
                color: "transparent"
                border.color: Theme.accent
                border.width: shown ? 2 : 0
                opacity: shown ? 1 : 0.55

                RowLayout {
                    id: icons
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: pad.modelData.toplevels.values.slice(0, 3)
                        AppIcon {
                            required property var modelData
                            toplevel: modelData
                        }
                    }
                }

                TapHandler {
                    onTapped: Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${pad.modelData.name.replace(/^special:/, "")}")`)
                }
            }
        }
    }
}
