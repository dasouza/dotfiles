import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs

// Clock; hovering it opens a month calendar below the bar. Scroll or the arrows change month,
// clicking the month name jumps back to today. Week starts and names follow the system locale.
Text {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Qt.formatDateTime always uses English names; the locale gives the system language's.
    text: Qt.locale().toString(clock.date, "ddd dd MMM  HH:mm")
    color: popup.open ? Theme.accent : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.barFontSize

    HoverHandler {
        id: hover
    }

    property int month: 0
    property int year: 0
    function showToday() {
        month = clock.date.getMonth();
        year = clock.date.getFullYear();
    }
    function shiftMonth(n) {
        const m = month + n;
        year += Math.floor(m / 12);
        month = ((m % 12) + 12) % 12;
    }

    HoverPopup {
        id: popup
        owner: root
        ownerHovered: hover.hovered
        edge: Edges.Right
        onOpening: root.showToday()

        ColumnLayout {
            spacing: 10

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => root.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
            }

            RowLayout {
                Layout.fillWidth: true

                CalText {
                    text: "‹"
                    font.pixelSize: Theme.barFontSize + 4
                    Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignHCenter
                    TapHandler { onTapped: root.shiftMonth(-1) }
                }
                CalText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        const name = grid.locale.standaloneMonthName(root.month, Locale.LongFormat);
                        return `${name.charAt(0).toUpperCase()}${name.slice(1)} ${root.year}`;
                    }
                    color: Theme.accent
                    font.bold: true
                    TapHandler { onTapped: root.showToday() }
                }
                CalText {
                    text: "›"
                    font.pixelSize: Theme.barFontSize + 4
                    Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignHCenter
                    TapHandler { onTapped: root.shiftMonth(1) }
                }
            }

            GridLayout {
                columns: 2
                columnSpacing: 6
                rowSpacing: 4

                Item { implicitWidth: 1 }

                DayOfWeekRow {
                    locale: grid.locale
                    Layout.fillWidth: true
                    spacing: grid.spacing
                    delegate: CalText {
                        required property string shortName
                        text: shortName.slice(0, 2)
                        color: Theme.textDim
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                WeekNumberColumn {
                    month: root.month
                    year: root.year
                    locale: grid.locale
                    Layout.fillHeight: true
                    spacing: grid.spacing
                    delegate: CalText {
                        required property int weekNumber
                        text: weekNumber
                        color: Theme.surface.lighter(1.8)
                        font.pixelSize: Theme.barFontSize - 3
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MonthGrid {
                    id: grid
                    month: root.month
                    year: root.year
                    locale: Qt.locale()
                    spacing: 2

                    delegate: Rectangle {
                        required property int day
                        required property int month
                        required property bool today

                        implicitWidth: 34
                        implicitHeight: 30
                        radius: 8
                        color: today ? Theme.accent : "transparent"

                        CalText {
                            anchors.centerIn: parent
                            text: parent.day
                            color: parent.today ? Theme.accentText
                                 : parent.month === grid.month ? Theme.text : Theme.surface.lighter(1.8)
                            font.bold: parent.today
                        }
                    }
                }
            }
        }
    }

    component CalText: Text {
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.barFontSize - 1
    }
}
