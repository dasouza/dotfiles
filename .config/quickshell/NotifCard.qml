import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.modules
import qs.services

// One notification, shared by Popups.qml and the notification centre: a round icon (the image with
// the app icon as a badge, or just the app icon; a ring shows progress), summary • age and a
// one-line body. The chevron expands it: app name, full body with links, action buttons.
// Swipe sideways to dismiss. Clicks: popup — left closes, middle runs the default action, right
// closes all popups; centre — left runs the default action, middle removes it.
Item {
    id: card

    required property var entry
    property bool inCenter: false
    // Popups with buttons start expanded so the buttons are one click away.
    property bool expanded: !inCenter && buttons.length > 0
    readonly property alias hovered: hover.hovered
    readonly property alias dragging: drag.active

    signal swipedAway

    readonly property bool critical: entry.urgency === NotificationUrgency.Critical
    readonly property var buttons: entry.actions.filter(a => a.identifier !== "default")
    readonly property bool canExpand: buttons.length > 0 || entry.body.length > 45 || entry.body.includes("\n")
    readonly property string iconSource: {
        const icon = entry.appIcon || DesktopEntries.heuristicLookup(entry.desktopEntry || entry.appName)?.icon || "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.includes("://"))
            return icon;
        return icon ? Quickshell.iconPath(icon, true) : "";
    }

    function close() {
        if (inCenter)
            Notifs.remove(entry);
        else
            Notifs.hidePopup(entry);
    }

    implicitWidth: 400
    implicitHeight: content.implicitHeight + 24

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: bg
        width: card.width
        height: card.height
        radius: 14
        color: card.inCenter ? Theme.surface : Theme.background
        border.width: card.critical || !card.inCenter ? 2 : 1
        border.color: card.critical ? Theme.urgent : card.inCenter ? Theme.track : Theme.accent
        opacity: 1 - Math.min(0.7, Math.abs(x) / card.width)

        // Past 35% of the width it flies off and is dismissed; otherwise it springs back.
        Behavior on x {
            enabled: !drag.active
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        DragHandler {
            id: drag
            yAxis.enabled: false
            onActiveChanged: {
                if (active)
                    return;
                if (Math.abs(bg.x) > card.width * 0.35) {
                    bg.x = Math.sign(bg.x) * card.width;
                    swipeTimer.start();
                } else {
                    bg.x = 0;
                }
            }
        }
        Timer {
            id: swipeTimer
            interval: 200
            onTriggered: card.swipedAway()
        }

        // Clicks on the card itself. A MouseArea declared before the content sits underneath it, so
        // the buttons on top get their clicks first (a TapHandler here saw every click, buttons included).
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: mouse => {
                const button = mouse.button;
                if (card.inCenter) {
                    if (button === Qt.LeftButton) {
                        Notifs.invokeDefault(card.entry);
                        Notifs.remove(card.entry);
                    } else if (button === Qt.MiddleButton) {
                        Notifs.remove(card.entry);
                    }
                } else if (button === Qt.RightButton) {
                    Notifs.hideAllPopups();
                } else {
                    if (button === Qt.MiddleButton)
                        Notifs.invokeDefault(card.entry);
                    Notifs.hidePopup(card.entry);
                }
            }
        }

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Icon: progress ring around a round image / app icon, app icon badge on images.
            Item {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 48
                implicitHeight: 48

                Gauge {
                    anchors.fill: parent
                    visible: card.entry.progress >= 0
                    sweep: 360
                    thickness: 3
                    value: card.entry.progress / 100
                }

                ClippingRectangle {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    radius: 20
                    color: card.critical ? Theme.urgent : Theme.track

                    Image {
                        anchors.fill: parent
                        visible: card.entry.image !== ""
                        source: card.entry.image
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 80
                        sourceSize.height: 80
                    }
                    IconImage {
                        anchors.centerIn: parent
                        visible: card.entry.image === "" && card.iconSource !== ""
                        source: card.entry.image === "" ? card.iconSource : ""
                        implicitSize: 24
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: card.entry.image === "" && card.iconSource === ""
                        text: String.fromCodePoint(card.critical ? 0xf0028 : 0xf009a)
                        color: card.critical ? Theme.accentText : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 20
                    }
                }

                Rectangle {
                    visible: card.entry.image !== "" && card.iconSource !== ""
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 20
                    height: 20
                    radius: 10
                    color: Theme.background

                    IconImage {
                        anchors.centerIn: parent
                        source: card.entry.image !== "" ? card.iconSource : ""
                        implicitSize: 15
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: card.entry.summary || card.entry.appName
                        elide: Text.ElideRight
                        color: card.critical ? Theme.urgent : Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }
                    Text {
                        text: `• ${Notifs.age(card.entry.time)}`
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                    IconButton {
                        visible: card.canExpand
                        glyph: card.expanded ? 0xf0143 : 0xf0140
                        onClicked: card.expanded = !card.expanded
                    }
                    IconButton {
                        glyph: 0xf0156
                        onClicked: card.close()
                    }
                }

                Text {
                    visible: card.expanded && card.entry.appName !== ""
                    text: card.entry.appName
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                }

                // Compact: one plain line. Expanded: markup, links, up to 10 lines.
                Text {
                    Layout.fillWidth: true
                    visible: card.entry.body !== ""
                    text: card.expanded ? card.entry.body
                                        : card.entry.body.replace(/<[^>]*>/g, "").replace(/\s*\n\s*/g, " ")
                    textFormat: card.expanded ? Text.StyledText : Text.PlainText
                    wrapMode: card.expanded ? Text.Wrap : Text.NoWrap
                    maximumLineCount: card.expanded ? 10 : 1
                    elide: Text.ElideRight
                    color: card.entry.urgency === NotificationUrgency.Low ? Theme.textDim : Theme.text
                    linkColor: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: card.expanded && card.buttons.length > 0
                    spacing: 6

                    Repeater {
                        model: card.buttons

                        Rectangle {
                            id: action
                            required property var modelData
                            implicitWidth: actionLabel.implicitWidth + 20
                            implicitHeight: 26
                            radius: 8
                            color: actionMouse.containsMouse ? Theme.accent : Theme.track

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: action.modelData.text
                                color: actionMouse.containsMouse ? Theme.accentText : Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                            }
                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: action.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }

    // Small glyph button. A MouseArea (not a TapHandler) so it takes the click outright and the
    // card's own tap/swipe handlers don't compete for it; the hit area is a bit bigger than the glyph.
    component IconButton: Text {
        id: button
        property int glyph
        signal clicked

        text: String.fromCodePoint(glyph)
        color: buttonMouse.containsMouse ? Theme.accent : Theme.textDim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 2

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
