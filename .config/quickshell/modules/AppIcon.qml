import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

// A window's app icon, from its desktop entry. A coral dot marks an urgent window or Slack
// with unread messages (Slack puts "N new item(s)" in its title).
Item {
    id: app

    property var toplevel
    readonly property string appId: toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || ""
    readonly property bool alert: (toplevel?.urgent ?? false) || /\d+ new item/.test(toplevel?.title ?? "")

    implicitWidth: 18
    implicitHeight: 18

    IconImage {
        anchors.fill: parent
        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(app.appId)?.icon ?? app.appId, "application-x-executable")
    }
    Rectangle {
        visible: app.alert
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: -2
        width: 8
        height: 8
        radius: 4
        color: Theme.urgent
        border.color: Theme.background
        border.width: 1
    }
}
