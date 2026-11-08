import QtQuick
import qs
import qs.services

// Notification count. Left = open the notification centre, right = do-not-disturb,
// middle = clear all.
Text {
    id: bell
    readonly property int count: Notifs.history.length

    text: String.fromCodePoint(Notifs.paused ? 0xf009b : count > 0 ? 0xf117b : 0xf009a)
          + (count > 0 ? ` ${count}` : "")
    color: Notifs.centerOpen || (count > 0 && !Notifs.paused) ? Theme.accent : Notifs.paused ? Theme.textDim : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.barFontSize

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                Notifs.dnd = !Notifs.dnd;
            else if (event.button === Qt.MiddleButton)
                Notifs.clearAll();
            else
                Notifs.centerOpen = !Notifs.centerOpen;
        }
    }

    NotifCenter {
        owner: bell
    }
}
