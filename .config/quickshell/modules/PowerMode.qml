import QtQuick
import Quickshell.Services.UPower
import qs

// power-profiles-daemon profile; click cycles it.
Text {
    readonly property var cycle: PowerProfiles.hasPerformanceProfile
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    text: String.fromCodePoint(PowerProfiles.profile === PowerProfile.PowerSaver ? 0xf06c
                             : PowerProfiles.profile === PowerProfile.Performance ? 0xf427 : 0xf0d98)
    color: PowerProfiles.profile === PowerProfile.PowerSaver ? Theme.good
         : PowerProfiles.profile === PowerProfile.Performance ? Theme.urgent : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.barFontSize

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: PowerProfiles.profile = cycle[(cycle.indexOf(PowerProfiles.profile) + 1) % cycle.length]
    }
}
