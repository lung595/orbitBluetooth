import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets

// A small moving drawing of one place where Orbit's widget can go: the
// Control Center ("cc"), the bar ("bar") or the desktop ("desktop"). A pointer
// adds the widget, then opens it, and the orbit turns inside; then the drawing
// clears and starts over. Theme colours only, so it follows light and dark.
// Everything is a function of one clock `t` (0 → 1 in 5 s): with Reduce
// motion, or while the page is hidden, the clock stops on the finished
// picture and nothing runs.
Item {
    id: sketch

    required property string kind
    // Runs only while it can be seen
    property bool running: true

    readonly property bool reduceMotion: SettingsData.reduceMotion
    // The finished picture, for Reduce motion and a stopped clock
    readonly property real still: 0.84
    property real t: still

    width: 128
    height: 80

    NumberAnimation on t {
        running: sketch.running && !sketch.reduceMotion
        from: 0
        to: 1
        duration: 5000
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            sketch.t = sketch.still
    }

    // 0 before a, 1 after b, smooth in between
    function ramp(a, b) {
        const x = Math.max(0, Math.min(1, (t - a) / (b - a)));
        return x * x * (3 - 2 * x);
    }
    function lerp(p, q, k) {
        return p + (q - p) * k;
    }

    // The story, in clock time: the pointer comes in and clicks (add), the
    // widget appears, the pointer clicks it (open), the orbit opens, a hold,
    // then what was added fades away
    readonly property real arrive: ramp(0.12, 0.30)
    readonly property real added: ramp(0.36, 0.48)
    readonly property real move: ramp(0.50, 0.58)
    readonly property real opened: ramp(0.62, 0.76)
    readonly property real clear: 1 - ramp(0.92, 1.0)

    // Where the pointer starts, clicks first (to add) and second (to open);
    // on the desktop the second is a drag that carries the widget along
    readonly property point from: Qt.point(40, 74)
    readonly property point first: kind === "cc" ? Qt.point(90, 28) : kind === "bar" ? Qt.point(92, 9) : Qt.point(64, 42)
    readonly property point second: kind === "cc" ? Qt.point(111, 28) : kind === "bar" ? Qt.point(92, 9) : Qt.point(64, 24)
    readonly property real drag: kind === "desktop" ? 26 * opened : 0

    // The screen
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.surface
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.35)
        clip: true
        // A faint wallpaper
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.withAlpha(Theme.primary, 0.10)
            }
            GradientStop {
                position: 1
                color: Theme.surface
            }
        }
    }

    // --- Control Center: a panel of tiles, Edit, then Orbit's tile and its detail
    Rectangle {
        visible: sketch.kind === "cc"
        x: 56
        y: 6
        width: 66
        height: 68
        radius: 6
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.25)
    }
    Repeater {
        model: sketch.kind === "cc" ? 5 : 0
        Rectangle {
            x: 60 + (index % 3) * 21
            y: 10 + Math.floor(index / 3) * 13
            width: 18
            height: 10
            radius: 3
            color: Theme.surfaceContainerHighest
            // The fifth tile is Edit: lit while the pointer presses it
            border.width: index === 4 ? 1 : 0
            border.color: Theme.withAlpha(Theme.primary, 0.3 + 0.7 * sketch.ramp(0.28, 0.34) * (1 - sketch.ramp(0.40, 0.48)))
            DankIcon {
                visible: index === 4
                anchors.centerIn: parent
                name: "edit"
                size: 8
                color: Theme.surfaceVariantText
            }
        }
    }
    Rectangle {
        id: ccTile
        visible: sketch.kind === "cc"
        x: 102
        y: 23
        width: 18
        height: 10
        radius: 3
        scale: 0.4 + 0.6 * sketch.added
        opacity: sketch.added * sketch.clear
        color: Theme.withAlpha(Theme.primary, 0.35)
        border.width: 1
        border.color: Theme.primary
        DankIcon {
            anchors.centerIn: parent
            name: "bluetooth"
            size: 8
            color: Theme.primary
        }
    }
    Rectangle {
        visible: sketch.kind === "cc"
        x: 60
        y: 37
        width: 58
        height: 33 * sketch.opened
        radius: 4
        opacity: sketch.clear
        clip: true
        color: Theme.surfaceContainerHighest
        MiniOrbit {
            anchors.centerIn: parent
            size: 28
            angle: sketch.t * 720
        }
    }

    // --- Bar: a strip of widgets, Orbit's pill joins them, its pop-out drops
    Rectangle {
        visible: sketch.kind === "bar"
        x: 4
        y: 4
        width: 120
        height: 10
        radius: 5
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.25)
    }
    Repeater {
        model: sketch.kind === "bar" ? [8, 20, 58, 102, 113] : []
        Rectangle {
            x: modelData
            y: 6
            width: 9
            height: 6
            radius: 3
            color: Theme.surfaceContainerHighest
        }
    }
    Rectangle {
        visible: sketch.kind === "bar"
        x: 88
        y: 5
        width: 9
        height: 8
        radius: 4
        scale: 0.4 + 0.6 * sketch.added
        opacity: sketch.added * sketch.clear
        color: Theme.withAlpha(Theme.primary, 0.45)
        border.width: 1
        border.color: Theme.primary
    }
    Rectangle {
        visible: sketch.kind === "bar"
        x: 64
        y: 18
        width: 56
        height: 54 * sketch.opened
        radius: 6
        opacity: sketch.clear
        clip: true
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.25)
        MiniOrbit {
            anchors.centerIn: parent
            size: 40
            angle: sketch.t * 720
        }
    }

    // --- Desktop: the widget appears on the wallpaper, then is dragged into place
    Rectangle {
        visible: sketch.kind === "desktop"
        x: 36 + sketch.drag
        y: 18
        width: 56
        height: 48
        radius: 6
        scale: 0.6 + 0.4 * sketch.added
        opacity: sketch.added * sketch.clear
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.85)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.3 + 0.5 * sketch.ramp(0.56, 0.62) * (1 - sketch.ramp(0.76, 0.82)))
        MiniOrbit {
            anchors.centerIn: parent
            size: 38
            angle: sketch.t * 720
        }
    }

    // --- The pointer, and a ring where it clicks
    Rectangle {
        readonly property real press: Math.max(sketch.ramp(0.30, 0.33) * (1 - sketch.ramp(0.33, 0.40)), sketch.ramp(0.58, 0.61) * (1 - sketch.ramp(0.61, 0.68)))
        x: pointer.x - width / 2
        y: pointer.y - height / 2
        width: 6 + 10 * press
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: Theme.primary
        opacity: press * sketch.clear
    }
    Shape {
        id: pointer
        readonly property real k: sketch.arrive
        x: sketch.move > 0 ? sketch.lerp(sketch.first.x, sketch.second.x, sketch.move) + sketch.drag : sketch.lerp(sketch.from.x, sketch.first.x, k)
        y: sketch.move > 0 ? sketch.lerp(sketch.first.y, sketch.second.y, sketch.move) : sketch.lerp(sketch.from.y, sketch.first.y, k)
        width: 10
        height: 14
        // Pressed: a touch smaller
        scale: 1 - 0.15 * Math.max(sketch.ramp(0.30, 0.33) * (1 - sketch.ramp(0.33, 0.36)), sketch.ramp(0.58, 0.61) * (1 - sketch.ramp(0.61, 0.64)))
        transformOrigin: Item.TopLeft
        opacity: sketch.ramp(0.04, 0.12) * sketch.clear
        preferredRendererType: Shape.CurveRenderer
        // The tip of the arrow is the item's origin, so x, y is where it points
        ShapePath {
            fillColor: Theme.surfaceText
            strokeColor: Theme.surface
            strokeWidth: 1
            joinStyle: ShapePath.RoundJoin
            startX: 0
            startY: 0
            PathLine {
                x: 0
                y: 11
            }
            PathLine {
                x: 3
                y: 8.5
            }
            PathLine {
                x: 5.5
                y: 13
            }
            PathLine {
                x: 7.5
                y: 12
            }
            PathLine {
                x: 5
                y: 7.5
            }
            PathLine {
                x: 8.5
                y: 7.5
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    // A tiny orbit: the computer in the middle, two devices going round
    component MiniOrbit: Item {
        id: mini
        property real size: 30
        property real angle: 0
        width: size
        height: size
        Rectangle {
            anchors.centerIn: parent
            width: mini.size * 0.8
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.withAlpha(Theme.primary, 0.45)
        }
        Rectangle {
            anchors.centerIn: parent
            width: mini.size * 0.22
            height: width
            radius: width / 2
            color: Theme.primary
        }
        Repeater {
            model: [0, 150]
            Rectangle {
                readonly property real a: (mini.angle + modelData) * Math.PI / 180
                readonly property real r: mini.size * 0.4
                width: index === 0 ? 5 : 4
                height: width
                radius: width / 2
                x: mini.width / 2 + r * Math.cos(a) - width / 2
                y: mini.height / 2 + r * Math.sin(a) - height / 2
                color: index === 0 ? Theme.primary : Theme.surfaceText
            }
        }
    }
}
