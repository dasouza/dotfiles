import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules

// One bar per screen.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Theme.barHeight
        color: Theme.background

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing
            anchors.rightMargin: Theme.spacing
            spacing: Theme.spacing

            Workspaces {}
            Performance {
                Layout.leftMargin: Theme.spacing
            }
            Submap {
                Layout.leftMargin: Theme.spacing
            }
            Item { Layout.fillWidth: true }
            Tray {}
            NetStatus {}
            Battery {}
            PowerMode {}
            Caffeine {}
            Bell {}
            Clock {}
        }

        // Centred independently of the side sections' widths.
        Media {
            anchors.centerIn: parent
        }
    }
}
