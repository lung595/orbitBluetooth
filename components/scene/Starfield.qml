import QtQuick
import qs.Common

// Deep-space backdrop. The nebula and static stars are painted once into a
// Canvas (re-painted only on resize/theme change); twinkles and shooting
// stars are a few cheap items driven by the scene clock and a timer.
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

    // Shooting star: a head and a tail of short segments laid along its last
    // positions, so the trail really follows the path when it bends
    Item {
        id: meteor
        anchors.fill: parent
        visible: meteorAnim.running

        Repeater {
            id: trail
            model: meteorAnim.segments
            Rectangle {
                transformOrigin: Item.Left
                height: 1.5
                radius: 0.75
                color: "white"
                opacity: 0
            }
        }

        Rectangle {
            id: meteorHead
            width: 3
            height: 3
            radius: 1.5
            color: "white"
            opacity: 0
        }
    }

    // Where the black hole sits in this item's coordinates (radius 0 = none):
    // passing stars are pulled in, and swallowed inside the horizon
    property real holeX: 0
    property real holeY: 0
    property real holeR: 0
    signal swallowed

    // Shooting star flight, driven by a plain 60 Hz timer rather than a QML
    // animation: a running animation makes every shell window (bars,
    // wallpaper) redraw at the display rate, a timer only repaints this one.
    // Always from the top left toward the bottom right (15° to 60° below the
    // horizontal), with a random start, angle, length and speed; it speeds up along the way
    // (like the old InQuad), and near the black hole its path bends toward it
    // (thin-lens gravity, a ∝ 1/r²) or ends inside the horizon.
    Timer {
        id: meteorAnim
        readonly property int segments: 16
        property real hx: 0
        property real hy: 0
        property real dx: 1        // unit direction of travel
        property real dy: 0
        property real base: 0      // px/s, mean speed
        property real life: 0.64   // s, flight time
        property real t: 0
        property double last: 0
        property bool captured: false
        property real fade: 1      // envelope once captured or out of view
        property var pts: []       // head positions, newest first
        interval: 16
        repeat: true

        function launch() {
            const w = root.width, h = root.height;
            const ang = (15 + Math.random() * 45) * Math.PI / 180;
            dx = Math.cos(ang);
            dy = Math.sin(ang);
            const len = w * (root.vignette ? 0.22 + Math.random() * 0.14 : 0.3 + Math.random() * 0.25);
            life = 0.5 + Math.random() * 0.3;
            base = len / life;
            // About one star in four is aimed past the black hole, at a random
            // distance from it: some just bend, some are swallowed. The others
            // start anywhere in the top-left part of the sky.
            if (root.holeR > 0 && Math.random() < 0.25) {
                const b = root.holeR * (0.6 + Math.random() * 3) * (Math.random() < 0.5 ? -1 : 1);
                hx = root.holeX - dy * b - dx * len / 2;
                hy = root.holeY + dx * b - dy * len / 2;
            } else {
                const m = root.vignette ? 0.2 : 0.05;   // desktop: keep to the middle
                hx = w * (m + Math.random() * (0.55 - m));
                hy = h * (m + Math.random() * (0.45 - m));
            }
            t = 0;
            captured = false;
            fade = 1;
            pts = [];
            last = Date.now();
            draw(0);
            restart();
        }

        function tick() {
            const now = Date.now();
            const dt = Math.min(0.05, (now - last) / 1000);
            last = now;
            t += dt;
            const p = Math.min(1, t / life);
            if (!captured) {
                const v = base * (0.5 + p);   // accelerates: 0.5 → 1.5 × mean
                let vx = dx * v, vy = dy * v;
                if (root.holeR > 0) {
                    const rx = root.holeX - hx, ry = root.holeY - hy;
                    const r2 = rx * rx + ry * ry;
                    const r = Math.sqrt(r2);
                    if (r < root.holeR * 1.05) {
                        captured = true;
                        root.swallowed();
                    } else {
                        // Deflection ≈ 1 rad at one horizon radius, fading as 1/r²
                        const g = 0.5 * base * base * root.holeR / (r2 + root.holeR * root.holeR * 0.1);
                        vx += rx / r * g * dt;
                        vy += ry / r * g * dt;
                        const n = Math.hypot(vx, vy);
                        dx = vx / n;
                        dy = vy / n;
                    }
                }
                if (!captured) {
                    hx += dx * v * dt;
                    hy += dy * v * dt;
                }
            }
            if (captured || p >= 1)
                fade = Math.max(0, fade - dt / (captured ? 0.15 : 0.25));
            draw(p);
            if (fade <= 0)
                stop();
        }

        function draw(p) {
            if (!captured)
                pts = [Qt.point(hx, hy)].concat(pts).slice(0, segments + 1);
            // Fade in over the first 18 %, then held; out at the end
            const env = (p < 0.18 ? p / 0.18 : 1) * fade;
            // A little brighter close to the hole: the light is focused
            let boost = 1;
            if (root.holeR > 0) {
                const d = Math.hypot(hx - root.holeX, hy - root.holeY) / (root.holeR * 3);
                boost = 1 + 0.5 * Math.exp(-d * d);
            }
            meteorHead.x = hx - 1.5;
            meteorHead.y = hy - 1.5;
            meteorHead.opacity = captured ? 0 : Math.min(1, 0.95 * env * boost);
            for (let i = 0; i < segments; i++) {
                const seg = trail.itemAt(i);
                if (!seg)
                    continue;
                const a = pts[i], b = pts[i + 1];
                if (!a || !b) {
                    seg.opacity = 0;
                    continue;
                }
                seg.x = a.x;
                seg.y = a.y - seg.height / 2;
                seg.width = Math.hypot(b.x - a.x, b.y - a.y) + 0.5;
                seg.rotation = Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI;
                seg.opacity = Math.min(1, 0.85 * (1 - i / segments) * env * boost);
            }
        }

        onTriggered: tick()
    }

    // Rare: one every 12 to 32 s, only while the scene is awake
    Timer {
        running: root.animate && root.shootingStars && root.visible
        repeat: true
        interval: 10000
        onTriggered: {
            interval = 12000 + Math.random() * 20000;
            meteorAnim.launch();
        }
    }
}
