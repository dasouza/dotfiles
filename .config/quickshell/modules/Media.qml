import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs

// Now playing. Spotify only (browser tabs also register as players).
// Bar: cover + artist — title, click to play/pause. Hovering opens a card with a bigger cover,
// a clickable seek bar and shuffle / previous / play / next / repeat.
RowLayout {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.dbusName.includes("spotify")) ?? null

    visible: player !== null
    spacing: 8

    HoverHandler {
        id: hover
    }
    TapHandler {
        onTapped: if (root.player?.canTogglePlaying) root.player.togglePlaying()
    }

    Cover {
        size: 22
        radius: 5
        url: root.player?.trackArtUrl ?? ""
    }

    Text {
        Layout.maximumWidth: 500
        text: root.player ? `${root.player.trackArtist} — ${root.player.trackTitle}` : ""
        elide: Text.ElideRight
        color: root.player?.isPlaying ? Theme.accent : Theme.textDim
        font.family: Theme.font
        font.pixelSize: Theme.barFontSize
    }

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    HoverPopup {
        id: popup
        owner: root
        ownerHovered: hover.hovered

        // MPRIS doesn't push position updates; poll it while the card is showing.
        Timer {
            running: popup.open && (root.player?.isPlaying ?? false)
            interval: 1000
            repeat: true
            onTriggered: root.player.positionChanged()
        }

        ColumnLayout {
            spacing: 12

            RowLayout {
                spacing: 14

                // Click the cover to bring Spotify's window up.
                Cover {
                    size: 96
                    radius: 10
                    url: root.player?.trackArtUrl ?? ""
                    TapHandler {
                        onTapped: if (root.player?.canRaise) root.player.raise()
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 230
                    spacing: 4

                    PopupText {
                        text: root.player?.trackTitle ?? ""
                        color: Theme.accent
                        font.bold: true
                        font.pixelSize: Theme.barFontSize + 1
                        maximumLineCount: 2
                    }
                    PopupText {
                        text: root.player?.trackArtist ?? ""
                    }
                    PopupText {
                        visible: text !== ""
                        text: root.player?.trackAlbum ?? ""
                        color: Theme.textDim
                        font.pixelSize: Theme.barFontSize - 2
                    }
                }
            }

            // Seek bar; click anywhere on it to jump there.
            ColumnLayout {
                Layout.fillWidth: true
                visible: (root.player?.lengthSupported ?? false) && root.player.length > 0
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Theme.surface

                    Rectangle {
                        width: parent.width * Math.min(1, (root.player?.position ?? 0) / (root.player?.length || 1))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.player?.canSeek ?? false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => root.player.position = Math.max(0, Math.min(1, (mouse.x - 6) / parent.width)) * root.player.length
                    }
                }

                RowLayout {
                    PopupText {
                        text: root.time(root.player?.position ?? 0)
                        color: Theme.textDim
                        font.pixelSize: Theme.barFontSize - 3
                    }
                    PopupText {
                        text: root.time(root.player?.length ?? 0)
                        color: Theme.textDim
                        font.pixelSize: Theme.barFontSize - 3
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 22

                MediaButton {
                    visible: root.player?.shuffleSupported ?? false
                    glyph: root.player?.shuffle ? 0xf049d : 0xf049e
                    color: root.player?.shuffle ? Theme.accent : Theme.textDim
                    action: () => root.player.shuffle = !root.player.shuffle
                }
                MediaButton {
                    enabled: root.player?.canGoPrevious ?? false
                    glyph: 0xf04ae
                    action: () => root.player.previous()
                }
                MediaButton {
                    enabled: root.player?.canTogglePlaying ?? false
                    glyph: root.player?.isPlaying ? 0xf03e4 : 0xf040a
                    color: Theme.accent
                    font.pixelSize: Theme.barFontSize + 14
                    action: () => root.player.togglePlaying()
                }
                MediaButton {
                    enabled: root.player?.canGoNext ?? false
                    glyph: 0xf04ad
                    action: () => root.player.next()
                }
                // Repeat cycles off → playlist → track.
                MediaButton {
                    visible: root.player?.loopSupported ?? false
                    glyph: root.player?.loopState === MprisLoopState.Track ? 0xf0458
                         : root.player?.loopState === MprisLoopState.Playlist ? 0xf0456 : 0xf0457
                    color: root.player?.loopState === MprisLoopState.None ? Theme.textDim : Theme.accent
                    action: () => root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                                      : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                                      : MprisLoopState.None
                }
            }
        }
    }

    // Album art, or a music note while there's none (or it's still loading).
    // (Inline components can't see `root`, so the URL is passed in.)
    component Cover: ClippingRectangle {
        id: cover
        property int size
        property string url
        implicitWidth: size
        implicitHeight: size
        color: Theme.surface

        Text {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: String.fromCodePoint(0xf075a)
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: cover.size / 2
        }
        Image {
            id: art
            anchors.fill: parent
            source: cover.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: cover.size * 2
            sourceSize.height: cover.size * 2
        }
    }

    component PopupText: Text {
        Layout.fillWidth: true
        color: Theme.text
        elide: Text.ElideRight
        wrapMode: Text.Wrap
        maximumLineCount: 1
        font.family: Theme.font
        font.pixelSize: Theme.barFontSize - 1
    }

    component MediaButton: Text {
        property int glyph
        property var action: null
        text: String.fromCodePoint(glyph)
        color: Theme.text
        opacity: enabled ? 1 : 0.35
        font.family: Theme.font
        font.pixelSize: Theme.barFontSize + 6
        Layout.alignment: Qt.AlignVCenter

        TapHandler {
            onTapped: parent.action?.()
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }
}
