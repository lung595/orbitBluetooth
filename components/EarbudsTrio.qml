import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "Charge.js" as Charge
import "Earbuds.js" as Earbuds

// Earbuds with a case: the case in the middle of a small orbit, the left
// and right buds on either end, all three floating gently, one battery bar
// each. A bud charging in its case glides toward it, then an energy beam
// appears between them.
// Motion runs on the render thread and only while `animate` is true
// (detail card open, Reduce motion off).
Item {
    id: trio

    property var parts: ({})              // { left, right, case: { level, charging } }
    property string name: ""
    property string caseImage: ""
    property string leftImage: ""
    property string rightImage: ""
    property string caption: ""           // e.g. "≈ 4 h 12 left"
    property bool animate: true

    readonly property var look: Earbuds.style(name)
    readonly property real caseSize: Math.round(width * 0.196)   // kept small so the card stays light
    readonly property real budSize: Math.round(width * 0.133)
    readonly property real spread: width * 0.39              // bud distance from the middle, at rest
    readonly property real stageH: caseSize + 16
    readonly property real cx: width / 2
    readonly property real cy: stageH / 2 + 2

    implicitHeight: stageH + 44 + (caption ? 18 : 0)

    // Small orbit through the three
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.09)
            strokeWidth: 1
            fillColor: "transparent"
            PathAngleArc {
                centerX: trio.cx
                centerY: trio.cy + trio.budSize * 0.12
                radiusX: trio.spread
                radiusY: trio.spread * 0.2
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // A bud charging in its case glides toward it, then a beam appears
    readonly property bool caseHere: !!parts.case
    // Close to the case, but its battery bar (which follows it) never meets
    // the case's label, even on a narrow card
    readonly property real dockSpread: Math.max(caseSize * 0.5 + budSize * 0.5 + 16, 78)
    readonly property bool leftDocked: caseHere && (parts.left?.charging ?? false)
    readonly property bool rightDocked: caseHere && (parts.right?.charging ?? false)
    property real leftSpread: leftDocked ? dockSpread : spread
    property real rightSpread: rightDocked ? dockSpread : spread
    Behavior on leftSpread {
        enabled: trio.animate
        NumberAnimation {
            duration: 900
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on rightSpread {
        enabled: trio.animate
        NumberAnimation {
            duration: 900
            easing.type: Easing.InOutCubic
        }
    }

    // Energy beam from the case edge to the bud, faded in once docked
    component Beam: Item {
        id: beam
        property real side: 1             // -1 left, 1 right
        property real spreadNow: 0
        property bool docked: false
        readonly property real from: trio.caseSize * 0.4
        readonly property real len: Math.max(0, spreadNow - from - trio.budSize * 0.18)
        x: trio.cx
        y: trio.cy
        rotation: side < 0 ? 180 : 0
        opacity: docked && Math.abs(spreadNow - trio.dockSpread) < 0.5 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation {
                duration: 450
            }
        }

        EnergyBeam {
            x: beam.from
            y: -height / 2
            width: beam.len
            height: 26
            amplitude: 1.4
            wavelength: 14
            running: trio.animate
        }
    }

    Beam {
        side: -1
        spreadNow: trio.leftSpread
        docked: trio.leftDocked
    }
    Beam {
        side: 1
        spreadNow: trio.rightSpread
        docked: trio.rightDocked
    }

    // One floating item with its soft shadow and battery bar
    component Piece: Item {
        id: piece
        property string part: "case"
        property real size: 40
        property real centerX: 0
        property string label: ""
        property string imageSource: ""
        property int period: 2800
        readonly property var info: trio.parts[part] ?? null

        x: centerX - width / 2
        y: 0
        width: Math.max(size, 72)
        height: trio.stageH + 44

        // Soft contact shadow on the orbit plane
        Shape {
            anchors.horizontalCenter: parent.horizontalCenter
            y: trio.cy + piece.size * 0.44
            width: piece.size * 0.9
            height: piece.size * 0.2
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: piece.size * 0.45
                    centerY: piece.size * 0.1
                    centerRadius: piece.size * 0.45
                    focalX: centerX
                    focalY: centerY
                    GradientStop {
                        position: 0
                        color: Qt.rgba(0, 0, 0, 0.32)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0)
                    }
                }
                PathAngleArc {
                    centerX: piece.size * 0.45
                    centerY: piece.size * 0.1
                    radiusX: piece.size * 0.45
                    radiusY: piece.size * 0.1
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        Item {
            id: floater
            anchors.horizontalCenter: parent.horizontalCenter
            y: trio.cy - piece.size / 2
            width: piece.size
            height: piece.size
            opacity: piece.info ? 1 : 0.35

            EarbudArt {
                anchors.fill: parent
                part: piece.part
                look: trio.look
                imageSource: piece.imageSource
                fallbackSource: piece.part === "right" ? trio.leftImage : ""
            }

            SequentialAnimation {
                running: trio.animate
                loops: Animation.Infinite
                YAnimator {
                    target: floater
                    from: trio.cy - piece.size / 2
                    to: trio.cy - piece.size / 2 - 4
                    duration: piece.period
                    easing.type: Easing.InOutSine
                }
                YAnimator {
                    target: floater
                    from: trio.cy - piece.size / 2 - 4
                    to: trio.cy - piece.size / 2
                    duration: piece.period
                    easing.type: Easing.InOutSine
                }
            }
        }

        // Battery bar + "L 80% ⚡"
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: trio.stageH + 6
            spacing: 5

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 62
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.07)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (piece.info?.level ?? 0) / 100))
                    height: parent.height
                    radius: 3
                    color: Charge.levelColor(piece.info?.level ?? 0)
                    visible: !!piece.info
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3
                StyledText {
                    text: piece.label + " " + (piece.info ? piece.info.level + "%" : "—")
                    color: piece.info ? "#F2F5EE" : Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.features: {
                        "tnum": 1
                    }
                }
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: piece.info?.charging ?? false
                    name: "bolt"
                    size: Theme.fontSizeSmall
                    color: Theme.primary
                }
            }
        }
    }

    Piece {
        part: "left"
        label: "L"
        size: trio.budSize
        centerX: trio.cx - trio.leftSpread
        imageSource: trio.leftImage
        period: 2600
    }
    Piece {
        part: "case"
        label: "Case"
        size: trio.caseSize
        centerX: trio.cx
        imageSource: trio.caseImage
        period: 3100
    }
    Piece {
        part: "right"
        label: "R"
        size: trio.budSize
        centerX: trio.cx + trio.rightSpread
        imageSource: trio.rightImage
        period: 2850
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: trio.stageH + 44
        visible: text !== ""
        text: trio.caption
        color: Qt.rgba(1, 1, 1, 0.42)
        font.pixelSize: Theme.fontSizeSmall - 1
    }
}
