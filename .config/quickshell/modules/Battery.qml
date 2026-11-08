import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

// Laptop battery: icon + percentage, hidden on machines without one. Hover shows the time left.
// (UPower's displayDevice combines all laptop batteries; mice and headsets are separate devices.)
Text {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property real pct: Math.round((dev?.percentage ?? 0) * 100)
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
                                     || dev?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: dev?.state === UPowerDeviceState.FullyCharged

    function duration(seconds) {
        const h = Math.floor(seconds / 3600), m = Math.round(seconds % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    visible: dev?.isLaptopBattery ?? false
    // battery-10 … battery-90 are consecutive code points; battery (full) and battery-charging aren't
    text: String.fromCodePoint(charging ? 0xf0084 : pct >= 95 ? 0xf0079 : 0xf007a + Math.max(0, Math.floor(pct / 10) - 1))
          + ` ${pct}%`
    color: charging || full ? Theme.good : pct <= 15 ? Theme.urgent : pct <= 30 ? Theme.warning : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.barFontSize

    HoverHandler {
        id: hover
    }

    HoverPopup {
        owner: root
        ownerHovered: hover.hovered
        edge: Edges.Right

        Text {
            text: root.full ? "Fully charged"
                : root.charging ? (root.dev.timeToFull > 0 ? `Full in ${root.duration(root.dev.timeToFull)}` : "Charging")
                : root.dev?.timeToEmpty > 0 ? `${root.duration(root.dev.timeToEmpty)} left` : "On battery"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
