import QtQuick
import qs.Common

// Deep-space backdrop. The nebula and static stars are painted once into a
// Canvas (re-painted only on resize/theme change); twinkles and shooting
// stars are a few cheap items driven by the scene clock.
Item {
    id: root
    readonly property NightColors night: NightColors {}

    property real clock: 0
    property bool animate: true
    property bool shootingStars: true
    property string density: "normal"
    property color tint: root.night.primary
    property color tint2: root.night.tertiary
    // Desktop glass: no opaque fill, everything fades out toward the edges
    property bool vignette: false
    // Rounded frame: the visible area sits `inset` px inside (parallax margin)
    property real radius: 0
    property real inset: 0

    readonly property real _densityFactor: density === "low" ? 0.55 : density === "high" ? 1.6 : 1

    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.radius > 0 ? root.inset : 0
        radius: root.radius
        visible: !root.vignette
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.tint("#07080c", Theme.withAlpha(root.tint2, 0.06))
            }
            GradientStop {
                position: 1
                color: Qt.tint("#040407", Theme.withAlpha(root.tint, 0.05))
            }
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root
            function onTintChanged() {
                canvas.requestPaint();
            }
            function onDensityChanged() {
                canvas.requestPaint();
            }
            function onVignetteChanged() {
                canvas.requestPaint();
            }
            function onRadiusChanged() {
                canvas.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            if (w <= 0 || h <= 0)
                return;
            // Keep stars and nebulae inside the rounded frame
            if (root.radius > 0 && !root.vignette) {
                const i = root.inset;
                ctx.beginPath();
                ctx.roundedRect(i, i, w - 2 * i, h - 2 * i, root.radius, root.radius);
                ctx.clip();
            }

            // 1 in the middle, easing to 0 at the edges (vignette mode only)
            const fade = (x, y) => {
                if (!root.vignette)
                    return 1;
                const n = Math.hypot((x - w / 2) / (w / 2), (y - h / 2) / (h / 2));
                const t = Math.min(1, Math.max(0, (0.95 - n) / 0.45));
                return t * t * (3 - 2 * t);
            };

            // Soft nebulae (pulled inward on the desktop so they never hit an edge)
            const blobs = root.vignette ? [[0.32, 0.36, 0.34, root.tint, 0.09], [0.68, 0.64, 0.36, root.tint2, 0.07]] : [[0.18, 0.25, 0.55, root.tint, 0.10], [0.85, 0.78, 0.6, root.tint2, 0.08], [0.6, 0.1, 0.35, root.tint, 0.05]];
            for (const b of blobs) {
                const g = ctx.createRadialGradient(b[0] * w, b[1] * h, 0, b[0] * w, b[1] * h, b[2] * Math.max(w, h));
                g.addColorStop(0, Qt.rgba(b[3].r, b[3].g, b[3].b, b[4]));
                g.addColorStop(1, Qt.rgba(b[3].r, b[3].g, b[3].b, 0));
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, w, h);
            }

            // Deterministic star field
            let seed = 1337;
            const rnd = () => {
                seed = (seed * 16807) % 2147483647;
                return seed / 2147483647;
            };
            const count = Math.round(w * h / 1400 * root._densityFactor);
            for (let i = 0; i < count; i++) {
                const x = rnd() * w, y = rnd() * h;
                const big = rnd() > 0.93;
                const r = big ? 0.9 + rnd() * 0.6 : 0.35 + rnd() * 0.5;
                const a = (big ? 0.55 + rnd() * 0.35 : 0.15 + rnd() * 0.4) * fade(x, y);
                const tinted = rnd() > 0.8;
                if (a < 0.03)
                    continue;
                ctx.fillStyle = tinted ? Qt.rgba(root.tint.r, root.tint.g, root.tint.b, a) : Qt.rgba(1, 1, 1, a);
                ctx.beginPath();
                ctx.arc(x, y, r, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    // Twinkling stars (positions are stable per size)
    Repeater {
        model: 7
        Rectangle {
            // Kept to the middle of the frame in vignette mode
            readonly property real inset: root.vignette ? 0.24 : 0
            readonly property real fx: inset + ((index * 0.6180339) % 1) * (1 - 2 * inset)
            readonly property real fy: inset + ((index * 0.3819660 + 0.17) % 1) * (1 - 2 * inset)
            readonly property real speed: 0.6 + (index % 3) * 0.35
            x: fx * root.width
            y: fy * root.height
            width: 2
            height: 2
            radius: 1
            color: "white"
            opacity: root.animate ? 0.15 + 0.75 * Math.pow(Math.abs(Math.sin(root.clock * speed + index * 1.7)), 3) : 0.4
        }
    }

    // Shooting star
    Item {
        id: meteor
        width: 90
        height: 1.5
        opacity: 0
        rotation: 24
        transformOrigin: Item.Right

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(1, 1, 1, 0.9)
                }
            }
        }
        Rectangle {
            width: 3
            height: 3
            radius: 1.5
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
        }
    }

    ParallelAnimation {
        id: meteorAnim
        property real sx: 0
        property real sy: 0
        readonly property real travel: root.vignette ? 0.28 : 0.45
        NumberAnimation {
            target: meteor
            property: "x"
            from: meteorAnim.sx
            to: meteorAnim.sx + root.width * meteorAnim.travel
            duration: 900
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: meteor
            property: "y"
            from: meteorAnim.sy
            to: meteorAnim.sy + root.width * meteorAnim.travel * Math.tan(24 * Math.PI / 180)
            duration: 900
            easing.type: Easing.InQuad
        }
        SequentialAnimation {
            NumberAnimation {
                target: meteor
                property: "opacity"
                to: 0.9
                duration: 160
            }
            PauseAnimation {
                duration: 420
            }
            NumberAnimation {
                target: meteor
                property: "opacity"
                to: 0
                duration: 320
            }
        }
    }

    Timer {
        running: root.animate && root.shootingStars && root.visible
        repeat: true
        interval: 7000
        onTriggered: {
            interval = 5000 + Math.random() * 9000;
            if (root.vignette) {
                meteorAnim.sx = root.width * (0.2 + Math.random() * 0.25);
                meteorAnim.sy = root.height * (0.24 + Math.random() * 0.18);
            } else {
                meteorAnim.sx = Math.random() * root.width * 0.6 - meteor.width;
                meteorAnim.sy = Math.random() * root.height * 0.45 - 10;
            }
            meteorAnim.restart();
        }
    }
}
