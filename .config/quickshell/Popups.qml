import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Notification popups, top-right below the bar (cards are NotifCard.qml). New ones slide in from
// the right, dismissed ones slide out and the rest move up. Hovering or dragging a card pauses its
// timeout. ScriptModel keeps each card's identity, so only the card that changed animates.
PanelWindow {
    id: window

    readonly property int limit: 5

    visible: list.count > 0
    anchors {
        top: true
        right: true
    }
    margins {
        top: 12
        right: 12
    }
    exclusiveZone: 0
    implicitWidth: 400
    implicitHeight: Math.max(1, list.contentHeight)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    ListView {
        id: list
        anchors.fill: parent
        interactive: false
        spacing: 8

        model: ScriptModel {
            values: Notifs.popups.slice(0, window.limit)
        }

        add: Transition {
            NumberAnimation { property: "x"; from: window.width; to: 0; duration: 300; easing.type: Easing.OutCubic }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; to: window.width; duration: 250; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: 250 }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutCubic }
        }

        delegate: NotifCard {
            id: popup
            required property var modelData
            entry: modelData
            width: list.width

            Timer {
                id: timeout
                interval: Notifs.timeoutFor(popup.entry)
                running: interval > 0 && !popup.hovered && !popup.dragging
                onTriggered: Notifs.hidePopup(popup.entry)
            }
            // Updated in place (new progress, edited text): start the timeout over.
            Connections {
                target: popup.entry
                function onTimeChanged() { timeout.restart(); }
            }
            onSwipedAway: Notifs.hidePopup(entry)
        }

        footer: Text {
            visible: Notifs.popups.length > window.limit
            height: visible ? implicitHeight + 8 : 0
            width: list.width
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignBottom
            text: `+${Notifs.popups.length - window.limit} more`
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
