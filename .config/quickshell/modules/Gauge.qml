import QtQuick
import QtQuick.Shapes
import qs

// Ring gauge: an arc (270° by default, open at the bottom) filled to `value` (0–1), animated on change.
Item {
    id: gauge

    property real value: 0
    property real thickness: 3
    property color color: Theme.accent
    property color trackColor: Theme.track

    property real sweep: 270 // 360 for a full ring
    readonly property real shown: Math.max(0, Math.min(1, value))
    property real animated: shown
    Behavior on animated {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    implicitWidth: 24
    implicitHeight: 24

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: gauge.trackColor
            strokeWidth: gauge.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: gauge.width / 2
                centerY: gauge.height / 2
                radiusX: (Math.min(gauge.width, gauge.height) - gauge.thickness) / 2
                radiusY: radiusX
                startAngle: 90 + (360 - gauge.sweep) / 2
                sweepAngle: gauge.sweep
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: gauge.animated > 0.005 ? gauge.color : "transparent"
            strokeWidth: gauge.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: gauge.width / 2
                centerY: gauge.height / 2
                radiusX: (Math.min(gauge.width, gauge.height) - gauge.thickness) / 2
                radiusY: radiusX
                startAngle: 90 + (360 - gauge.sweep) / 2
                sweepAngle: gauge.sweep * gauge.animated
            }
        }
    }
}
