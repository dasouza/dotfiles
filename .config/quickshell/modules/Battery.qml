import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs

// Laptop battery: icon + percentage, hidden on machines without one. Hovering opens a card in the
// style of the performance card: charge ring and bar (with the charge limit marked), time left,
// power draw, health, and, where the firmware supports it, 80% / 100% buttons for the charge limit.
// (UPower's displayDevice combines all laptop batteries; mice and headsets are separate devices.)
Text {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property real pct: Math.round((dev?.percentage ?? 0) * 100)
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
                                     || dev?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: dev?.state === UPowerDeviceState.FullyCharged
    // Plugged in but not charging because the charge limit was reached.
    readonly property bool held: !UPower.onBattery && !full && dev?.state !== UPowerDeviceState.Charging
                                 && limit > 0 && pct >= limit - 1
    readonly property color levelColor: charging && !held || full ? Theme.good
                                      : pct <= 15 ? Theme.urgent : pct <= 30 ? Theme.warning : Theme.accent

    // Charge limit (stop threshold) of BAT0; 0 when the battery has no threshold control.
    // 80% matches /etc/udev/rules.d/90-battery-charge-threshold.rules, which sets it again at boot.
    readonly property string sysfs: "/sys/class/power_supply/BAT0"
    property int limit: 0
    property bool limitFailed: false
    property real health: 0
    property int cycles: 0

    // sysfs sends no change events, so these are re-read each time the card opens.
    FileView {
        id: limitFile
        path: `${root.sysfs}/charge_control_end_threshold`
        onLoaded: root.limit = Number(text().trim()) || 0
        onLoadFailed: root.limit = 0
    }
    FileView {
        id: fullFile
        path: `${root.sysfs}/energy_full`
        onLoaded: root.updateHealth()
    }
    FileView {
        id: designFile
        path: `${root.sysfs}/energy_full_design`
        onLoaded: root.updateHealth()
    }
    FileView {
        id: cyclesFile
        path: `${root.sysfs}/cycle_count`
        onLoaded: root.cycles = Number(text().trim()) || 0
    }
    function updateHealth() {
        const design = Number(designFile.text().trim());
        health = design > 0 ? 100 * Number(fullFile.text().trim()) / design : 0;
    }
    function refresh() {
        for (const f of [limitFile, fullFile, designFile, cyclesFile])
            f.reload();
    }

    // The start threshold must stay below the stop one, so the order of the writes depends on
    // the direction. For 100% it goes to 99 so charging resumes at once instead of waiting
    // for the battery to drop below 75%.
    Process {
        id: setLimit
        property int target: 0
        command: ["sh", "-c", `b=${root.sysfs}
            if [ "$1" = 100 ]; then
                echo 100 | sudo -n tee $b/charge_control_end_threshold &&
                echo 99 | sudo -n tee $b/charge_control_start_threshold
            else
                echo 75 | sudo -n tee $b/charge_control_start_threshold &&
                echo 80 | sudo -n tee $b/charge_control_end_threshold
            fi >/dev/null`, "sh", String(target)]
        onExited: code => {
            root.limitFailed = code !== 0;
            limitFile.reload();
        }
    }

    function chargeTo(pct) {
        if (setLimit.running || pct === limit)
            return;
        setLimit.target = pct;
        setLimit.running = true;
    }

    function duration(seconds) {
        const h = Math.floor(seconds / 3600), m = Math.round(seconds % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    readonly property string statusText: full ? "Fully charged"
        : held ? `Held at ${limit}% by the charge limit`
        : charging ? "Charging"
        : UPower.onBattery ? "On battery" : "Plugged in"
    readonly property string timeText: charging && !held && dev?.timeToFull > 0 ? root.duration(dev.timeToFull)
        : UPower.onBattery && dev?.timeToEmpty > 0 ? root.duration(dev.timeToEmpty) : "—"
    readonly property string timeLabel: charging && !held ? "Until full" : "Time left"

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
        id: popup
        owner: root
        ownerHovered: hover.hovered
        edge: Edges.Right
        onOpening: {
            root.limitFailed = false;
            root.refresh();
        }

        Rectangle {
            implicitWidth: 320
            implicitHeight: body.implicitHeight + 28
            radius: 12
            color: Theme.surface
            border.color: Theme.track
            border.width: 1

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Ring with the battery icon, name and status, big percentage.
                RowLayout {
                    spacing: 10

                    Gauge {
                        implicitWidth: 38
                        implicitHeight: 38
                        thickness: 3
                        value: root.pct / 100
                        color: root.levelColor

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(root.charging && !root.held ? 0xf0084 : 0xf0079)
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 17
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: Theme.font
                            text: "Battery"
                            color: Theme.accent
                            font.bold: true
                            font.pixelSize: Theme.barFontSize + 1
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: Theme.font
                            text: root.statusText
                            color: Theme.textDim
                            font.pixelSize: Theme.barFontSize - 3
                        }
                    }
                    Text {
                        text: `${root.pct}%`
                        color: root.levelColor
                        font.family: Theme.font
                        font.pixelSize: Theme.barFontSize + 9
                        font.bold: true
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                // Charge bar; the tick marks where charging stops when the limit is below 100%.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 14

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 8
                            radius: 4
                            color: Theme.track

                            Rectangle {
                                id: fill
                                width: Math.max(height, parent.width * Math.min(1, root.pct / 100))
                                height: parent.height
                                radius: parent.radius
                                color: root.levelColor
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 300 } }

                                // Slow pulse while charging.
                                SequentialAnimation on opacity {
                                    running: popup.open && root.charging && !root.held
                                    loops: Animation.Infinite
                                    onStopped: fill.opacity = 1
                                    NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                        Rectangle {
                            visible: root.limit > 0 && root.limit < 100
                            x: track.width * root.limit / 100 - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height
                            radius: 1.5
                            color: Theme.text
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: Theme.font
                            text: root.dev?.energyCapacity > 0
                                ? `${root.dev.energy.toFixed(1)} / ${root.dev.energyCapacity.toFixed(1)} Wh` : ""
                            color: Theme.textDim
                            font.pixelSize: Theme.barFontSize - 3
                        }
                        Text {
                            visible: root.limit > 0 && root.limit < 100
                            text: `Limit ${root.limit}%`
                            color: Theme.textDim
                            font.family: Theme.font
                            font.pixelSize: Theme.barFontSize - 3
                        }
                    }
                }

                // Time, power and health tiles.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StatTile {
                        glyph: 0xf0150
                        label: root.timeLabel
                        value: root.timeText
                    }
                    StatTile {
                        glyph: 0xf140b
                        label: root.charging && !root.held ? "Charging" : "Draw"
                        value: Math.abs(root.dev?.changeRate ?? 0) > 0.05 ? `${Math.abs(root.dev.changeRate).toFixed(1)} W` : "—"
                    }
                    StatTile {
                        glyph: 0xf02d1
                        label: root.cycles > 0 ? `Health · ${root.cycles} cyc` : "Health"
                        value: root.health > 0 ? `${Math.min(100, root.health).toFixed(0)}%` : "—"
                    }
                }

                // Charge limit buttons.
                Rectangle {
                    visible: root.limit > 0
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.track
                }
                RowLayout {
                    visible: root.limit > 0
                    Layout.fillWidth: true
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            text: "Charge limit"
                            font.bold: true
                            font.pixelSize: Theme.barFontSize - 2
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: Theme.font
                            text: root.limit >= 100 ? "Back to 80% at reboot" : "Slows battery wear"
                            color: Theme.textDim
                            font.pixelSize: Theme.barFontSize - 4
                        }
                    }
                    PillButton {
                        label: "80%"
                        active: root.limit === 80
                        onClicked: root.chargeTo(80)
                    }
                    PillButton {
                        label: "100%"
                        active: root.limit === 100
                        onClicked: root.chargeTo(100)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: Theme.font
                    visible: root.limitFailed
                    text: "Couldn't change it (needs passwordless sudo)"
                    color: Theme.urgent
                    font.pixelSize: Theme.barFontSize - 3
                }
            }
        }
    }
}
