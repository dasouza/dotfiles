import QtQuick
import Quickshell
import qs

// Card that opens just below the bar while `owner` (or the card itself) is hovered.
// The owner feeds its hover state into `ownerHovered`; the content goes inside as children.
PopupWindow {
    id: popup

    required property Item owner
    property bool ownerHovered: false
    // Which side of the owner the card lines up with: Edges.Left, Edges.Right, or 0 for centred.
    property int edge: 0
    property bool open: false
    default property alias content: holder.data

    // Emitted just before the card shows, to reset its state (month, etc.).
    signal opening

    // Short delays so the card doesn't flash when the pointer just passes by, and stays open
    // while the pointer crosses the gap between the bar and the card.
    readonly property bool hovered: ownerHovered || cardHover.hovered
    onHoveredChanged: {
        if (hovered) {
            closeTimer.stop();
            openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }
    Timer {
        id: openTimer
        interval: 200
        onTriggered: {
            popup.opening();
            popup.open = true;
        }
    }
    Timer {
        id: closeTimer
        interval: 300
        onTriggered: popup.open = false
    }

    visible: open
    color: "transparent"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // 6px below the bar, whatever the owner's height.
    anchor.item: owner
    anchor.rect.width: owner.width
    anchor.rect.height: owner.height + (Theme.barHeight - owner.height) / 2 + 6
    anchor.edges: Edges.Bottom | edge
    anchor.gravity: Edges.Bottom | (edge === Edges.Right ? Edges.Left : edge === Edges.Left ? Edges.Right : 0)

    Rectangle {
        id: card
        anchors.fill: parent
        implicitWidth: holder.implicitWidth + 28
        implicitHeight: holder.implicitHeight + 28
        radius: 14
        color: Theme.background
        border.color: Theme.accent
        border.width: 2

        HoverHandler {
            id: cardHover
        }

        Item {
            id: holder
            anchors.centerIn: parent
            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        }
    }
}
