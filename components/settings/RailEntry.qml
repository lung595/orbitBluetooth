import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets

// One category of the rail: a body on the plotted orbit. The open category is
// the planet in focus (halos, a tilted ring), the others are moons. While a
// search filters, the open one steps back, the categories with a match carry
// their count as a small satellite and the others fade. Drawn once, still:
// only the opacity changes, and only for a moment.
Item {
    id: entry

    required property var view
    required property var modelData
    // Where the bodies sit, from the rail's left edge
    required property real bodyX

    readonly property bool on: !view.filtering && view.current === modelData.id
    readonly property int badge: view.counts[modelData.id] || 0
    readonly property bool dim: view.filtering && badge === 0
    readonly property bool reduceMotion: SettingsData.reduceMotion

    // Rows of 44 px with no gap: a 44 px pitch on the 4 px grid, and the touch target
    height: 44
    opacity: dim ? 0.38 : 1
    activeFocusOnTab: true

    Accessible.role: Accessible.PageTab
    Accessible.name: dim ? modelData.name + ", no match" : modelData.name
    Accessible.selected: on
    Accessible.onPressAction: entry.choose()

    function choose() {
        entry.view.pick(modelData.id);
    }

    // 100 ms, then nothing runs; with Reduce motion it just cuts
    Behavior on opacity {
        enabled: !entry.reduceMotion
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    Keys.onReturnPressed: choose()
    Keys.onEnterPressed: choose()
    Keys.onSpacePressed: choose()

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        onTapped: entry.choose()
    }

    // Focus-visible: a ring inset 2 px in the row
    Rectangle {
        visible: entry.activeFocus
        anchors.fill: parent
        anchors.margins: 2
        radius: 10
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
    }

    // The planet eclipses its own track: a disc of the page colour, then two halos like the host core's
    Rectangle {
        visible: entry.on
        anchors.centerIn: body
        width: 38
        height: 38
        radius: 19
        color: Theme.surface
    }
    Rectangle {
        visible: entry.on
        anchors.centerIn: body
        width: 48
        height: 48
        radius: 24
        color: Theme.withAlpha(Theme.primary, 0.05)
    }
    Rectangle {
        visible: entry.on
        anchors.centerIn: body
        width: 40
        height: 40
        radius: 20
        color: Theme.withAlpha(Theme.primary, 0.09)
    }

    // The body: planet (30 px) or moon (22 px, lit from above, a thin ring)
    Rectangle {
        id: body
        x: entry.bodyX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: entry.on ? 30 : 22
        height: width
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: entry.on ? Theme.withAlpha(Theme.primary, 0.30) : Theme.surfaceContainerHighest
            }
            GradientStop {
                position: 1
                color: entry.on ? Theme.withAlpha(Theme.primary, 0.12) : Theme.surfaceContainer
            }
        }
        border.width: entry.on ? 2 : 1
        border.color: entry.on ? Theme.primary : Theme.withAlpha(Theme.surfaceText, hover.hovered ? 0.5 : 0.18)

        // Pressed: a faint veil on the body
        Rectangle {
            visible: tap.pressed
            anchors.fill: parent
            radius: width / 2
            color: Theme.withAlpha(Theme.surfaceText, 0.08)
        }
    }

    // The planet's ring: a true ellipse tilted 22°, stroked once and left alone
    Shape {
        visible: entry.on
        anchors.centerIn: body
        width: 42
        height: 42
        preferredRendererType: Shape.CurveRenderer
        rotation: -22
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.primary, 0.75)
            strokeWidth: 1
            PathAngleArc {
                centerX: 21
                centerY: 21
                radiusX: 21
                radiusY: 6.3
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    DankIcon {
        x: entry.bodyX - size / 2
        anchors.verticalCenter: parent.verticalCenter
        name: entry.modelData.icon
        size: 18
        color: entry.on ? Theme.primary : Theme.surfaceText
    }

    // Clear of the ring's reach (50 px), elided before the rail's edge
    StyledText {
        visible: !entry.view.compact
        x: 56
        width: parent.width - x - 8
        anchors.verticalCenter: parent.verticalCenter
        text: entry.modelData.name
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        font.pixelSize: Theme.fontSizeMedium
        font.weight: entry.on ? Font.DemiBold : Font.Normal
        color: entry.on ? Theme.primary : Theme.surfaceText
    }

    // Matches in this category, on the body's upper-right limb
    Rectangle {
        visible: entry.view.filtering && entry.badge > 0
        x: entry.bodyX
        y: 4
        width: 18
        height: 18
        radius: 9
        color: Theme.primary
        border.width: 2
        border.color: Theme.surface
        StyledText {
            anchors.centerIn: parent
            text: entry.badge
            font.pixelSize: Theme.fontSizeSmall
            font.features: {
                "tnum": 1
            }
            font.weight: Font.DemiBold
            color: Theme.primaryText
        }
    }

    // A narrow rail shows icons only: the name appears beside the body on hover or focus
    Rectangle {
        visible: entry.view.compact && (hover.hovered || entry.activeFocus)
        z: 10
        x: entry.width + Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        width: tipText.implicitWidth + Theme.spacingS * 2
        height: 28
        radius: 8
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outline
        StyledText {
            id: tipText
            anchors.centerIn: parent
            text: entry.modelData.name
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }
}
