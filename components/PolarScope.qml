import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "Polar.js" as Polar

// The two volumes as a polar vectorscope (D250): the outer half circle is
// the device's own level (Theme.primary), the inner one this PC's level
// (Theme.tertiary). Each lights up from the left to its level, with a moon
// to drag; an icon sits at the foot of each, the number only shows while
// the level moves. A cloud of points shows where the sound is going: its
// angle is left/right, its distance how loud.
// The sound is drawn by PolarVisual in the chosen style (points, rays,
// waves or none), over an optional Ozone-like grid. It moves on one Timer
// (60 Hz, or 30 with "Light"), only while `live` and sound is playing or
// light is still fading; it stops by itself. A QML animation would redraw
// the whole shell (rule 23). Reduce motion: no picture, levels jump.
Item {
    id: scope

    // -1: the device has no level of its own, the outer half is not drawn
    property real deviceLevel: -1
    property real pcLevel: 0
    property bool deviceMuted: false
    property bool pcMuted: false
    property string deviceIcon: "headphones"
    property string pcIcon: "computer"
    // On screen and wanted to move (the caller knows: popup shown, card open)
    property bool live: false
    property bool motion: true
    property int fps: 60
    property bool interactive: true
    // "points", "rays", "waves" or "none" (Polar.styleOf)
    property string style: "points"
    // The scope's own screen behind it: guide rings and L / R lines
    property bool grid: false
    // Light added on a dark screen; plain paint on a light one
    property bool additive: true

    // A level was dragged or scrolled: "device" or "pc", 0..1
    signal moved(string part, real level)
    // Its icon was clicked: "device" or "pc"
    signal muteClicked(string part)
    // With smartWheel, a wheel notch asks the caller for a step instead
    // (the caller's smart steps, D264): +1 up, -1 down
    property bool smartWheel: false
    signal stepped(string part, int dir)
    // The percentages always show (D264): beside the half circles when
    // there is room, else next to the moons
    property bool numbers: false
    property string deviceLabel: "Device"
    property string pcLabel: "This PC"
    readonly property real sideRoom: width / 2 - outer - 12
    readonly property bool sideNumbers: numbers && sideRoom >= 64
    readonly property bool hovered: pointer.containsMouse || dragging !== ""

    readonly property bool hasDevice: deviceLevel >= 0
    // Geometry: the center sits on the bottom edge, above the icons
    readonly property real iconSize: Math.max(14, Math.round(outer * 0.12))
    readonly property real cx: width / 2
    readonly property real cy: height - iconSize - 10
    readonly property real outer: Math.max(10, Math.min(width / 2 - 14, height - 34))
    // Alone (an output with no level of its own), this PC's half takes the room
    readonly property real inner: hasDevice ? outer * 0.44 : outer * 0.82
    // Thin and quiet (D263): a hairline track, a fine lit arc
    readonly property real stroke: Math.max(1.75, outer * 0.016)

    // The caller may pass night colors when the scope sits on a dark screen
    property color deviceColor: Theme.primary
    property color pcColor: Theme.tertiary
    property color trackColor: Theme.withAlpha(Theme.outline, 0.22)
    property color inkColor: Theme.surfaceText
    property color mutedColor: Theme.outline
    // Inside a muted moon
    property color hollowColor: Theme.surfaceContainer

    // Which number shows, and for how long
    property string talking: ""
    function talk(part) {
        talking = part;
        quiet.restart();
    }
    Timer {
        id: quiet
        interval: 1400
        onTriggered: scope.talking = ""
    }

    // --- Arcs -------------------------------------------------------------------
    component Arc: ShapePath {
        id: arcPath
        property real radius: 0
        property real start: 180
        property real sweep: 180
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: scope.cx + Math.cos(start * Math.PI / 180) * radius
        startY: scope.cy + Math.sin(start * Math.PI / 180) * radius
        PathAngleArc {
            centerX: scope.cx
            centerY: scope.cy
            radiusX: arcPath.radius
            radiusY: arcPath.radius
            startAngle: arcPath.start
            sweepAngle: arcPath.sweep
        }
    }

    // --- Grid and picture ---------------------------------------------------------
    // Painted once per size or color change, never per frame
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: scope.grid
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        Connections {
            target: scope
            function onInkColorChanged() {
                gridCanvas.requestPaint();
            }
            function onOuterChanged() {
                gridCanvas.requestPaint();
            }
            function onDeviceColorChanged() {
                gridCanvas.requestPaint();
            }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!scope.grid)
                return;
            const c = scope.inkColor;
            const ink = a => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
            const R = scope.outer - scope.stroke * 2;
            // A faint glow where the sound rises from, like a lit phosphor screen
            const d = scope.deviceColor;
            const glow = ctx.createRadialGradient(scope.cx, scope.cy, 0, scope.cx, scope.cy, scope.outer * 1.15);
            glow.addColorStop(0, "rgba(" + Math.round(d.r * 255) + "," + Math.round(d.g * 255) + "," + Math.round(d.b * 255) + ",0.13)");
            glow.addColorStop(1, "rgba(0,0,0,0)");
            ctx.fillStyle = glow;
            ctx.fillRect(0, 0, width, height);
            ctx.lineWidth = 1;
            // Rings at a quarter, half and three quarters, dashed
            ctx.setLineDash([2, 4]);
            ctx.strokeStyle = ink(0.09);
            for (const f of [0.25, 0.5, 0.75]) {
                ctx.beginPath();
                ctx.arc(scope.cx, scope.cy, R * f, Math.PI, Math.PI * 2);
                ctx.stroke();
            }
            // Mono up the middle, hard left and right at ±45° (as on a goniometer)
            ctx.setLineDash([]);
            for (const deg of [225, 270, 315]) {
                const a = deg * Math.PI / 180;
                ctx.beginPath();
                ctx.moveTo(scope.cx, scope.cy);
                ctx.lineTo(scope.cx + Math.cos(a) * R, scope.cy + Math.sin(a) * R);
                ctx.strokeStyle = ink(deg === 270 ? 0.12 : 0.08);
                ctx.stroke();
            }
            ctx.fillStyle = ink(0.32);
            ctx.font = "600 " + Math.max(9, Math.round(scope.outer * 0.075)) + "px sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            for (const [deg, t] of [[225, "L"], [315, "R"]]) {
                const a = deg * Math.PI / 180;
                ctx.fillText(t, scope.cx + Math.cos(a) * (R * 0.62), scope.cy + Math.sin(a) * (R * 0.62) - 9);
            }
        }
    }

    PolarVisual {
        id: cloud
        anchors.fill: parent
        style: Polar.styleOf(scope.style)
        centerX: scope.cx
        centerY: scope.cy
        radius: scope.outer - scope.stroke
        color: scope.hasDevice ? scope.deviceColor : scope.pcColor
        color2: scope.pcColor
        quiet: scope.hasDevice ? scope.deviceMuted || scope.pcMuted : scope.pcMuted
        additive: scope.additive
        // As loud as it is heard: the device's level times this PC's
        gain: scope.hasDevice ? (scope.deviceMuted || scope.pcMuted ? 0 : scope._dev * scope._pc) : (scope.pcMuted ? 0 : scope._pc)
    }

    // A faint baseline, as on a goniometer
    Rectangle {
        x: scope.cx - scope.outer - 6
        y: scope.cy
        width: (scope.outer + 6) * 2
        height: 1
        color: scope.trackColor
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Tracks: where each level can go
        Arc {
            radius: scope.outer
            strokeWidth: 1
            strokeColor: scope.hasDevice ? scope.trackColor : "transparent"
        }
        Arc {
            radius: scope.inner
            strokeWidth: 1
            strokeColor: scope.trackColor
        }
        // Glow under each lit arc
        Arc {
            radius: scope.outer
            sweep: Polar.arc("outer", scope._dev).sweep
            strokeWidth: scope.stroke * 4
            strokeColor: scope.hasDevice && scope._dev > 0.001 ? Theme.withAlpha(scope.deviceMuted ? scope.mutedColor : scope.deviceColor, 0.07) : "transparent"
        }
        Arc {
            radius: scope.inner
            sweep: Polar.arc("inner", scope._pc).sweep
            strokeWidth: scope.stroke * 4
            strokeColor: scope._pc > 0.001 ? Theme.withAlpha(scope.pcMuted ? scope.mutedColor : scope.pcColor, 0.07) : "transparent"
        }
        // The levels
        Arc {
            radius: scope.outer
            sweep: Polar.arc("outer", scope._dev).sweep
            strokeWidth: scope.stroke
            strokeColor: scope.hasDevice && scope._dev > 0.001 ? (scope.deviceMuted ? Theme.withAlpha(scope.mutedColor, 0.6) : scope.deviceColor) : "transparent"
        }
        Arc {
            radius: scope.inner
            sweep: Polar.arc("inner", scope._pc).sweep
            strokeWidth: scope.stroke
            strokeColor: scope._pc > 0.001 ? (scope.pcMuted ? Theme.withAlpha(scope.mutedColor, 0.6) : scope.pcColor) : "transparent"
        }
    }

    // Shown levels: follow the real ones on a short ease (a Behavior, not a
    // running animation: it lasts 260 ms per change), straight while dragging
    property string dragging: ""
    property real _dev: Math.max(0, deviceLevel)
    property real _pc: pcLevel
    Behavior on _dev {
        enabled: scope.motion && scope.dragging !== "device"
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutQuint
        }
    }
    Behavior on _pc {
        enabled: scope.motion && scope.dragging !== "pc"
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutQuint
        }
    }

    // The sound to show: a ScopeFeed owned by the caller, which turns it on
    // only while the scope is shown (one feed for every screen's pop-up)
    property var feed: null
    Connections {
        target: scope.feed
        function onArrived() {
            scope.wake();
        }
    }

    // Exposed for tests: the clock must stop alone
    readonly property bool animating: clock.running
    property double _last: 0
    function wake() {
        if (clock.running || !live || !motion || cloud.style === "none")
            return;
        _last = Date.now();
        clock.start();
    }
    Timer {
        id: clock
        interval: Math.round(1000 / Math.max(10, scope.fps))
        repeat: true
        onTriggered: {
            const now = Date.now();
            const dt = Math.max(0.001, Math.min(0.1, (now - scope._last) / 1000));
            scope._last = now;
            // A frame older than a few of cava's is silence (paused player)
            const fresh = scope.feed && scope.feed.frame && now - scope.feed.stamp < 250 ? scope.feed.frame : null;
            cloud.advance(dt, fresh);
            if (!fresh && cloud.alive === 0)
                clock.stop();
        }
    }
    // Fills the cloud from a made-up frame, for previews and tests
    function simulate(frame, seconds) {
        for (let t = 0; t < seconds; t += 1 / fps)
            cloud.advance(1 / fps, frame);
    }
    onLiveChanged: if (!live) {
        clock.stop();
        cloud.clear();
    }
    onMotionChanged: if (!motion) {
        clock.stop();
        cloud.clear();
    }

    // --- Moons, icons, numbers -----------------------------------------------------
    component Moon: Rectangle {
        property real radiusAt: 0
        property real deg: 180
        property color tint: "white"
        property bool hollow: false
        property bool big: false
        readonly property real knob: big ? 11 : 8
        width: knob
        height: knob
        radius: knob / 2
        x: scope.cx + Math.cos(deg * Math.PI / 180) * radiusAt - knob / 2
        y: scope.cy + Math.sin(deg * Math.PI / 180) * radiusAt - knob / 2
        color: hollow ? scope.hollowColor : scope.inkColor
        border.width: 1.5
        border.color: tint
    }

    Moon {
        visible: scope.hasDevice
        radiusAt: scope.outer
        deg: Polar.end("outer", scope._dev)
        tint: scope.deviceMuted ? scope.mutedColor : scope.deviceColor
        hollow: scope.deviceMuted
        big: scope.dragging === "device" || pointer.hover === "device"
    }
    Moon {
        radiusAt: scope.inner
        deg: Polar.end("inner", scope._pc)
        tint: scope.pcMuted ? scope.mutedColor : scope.pcColor
        hollow: scope.pcMuted
        big: scope.dragging === "pc" || pointer.hover === "pc"
    }

    // Who is who: an icon at the foot of each half circle, where it starts
    DankIcon {
        visible: scope.hasDevice
        name: scope.deviceMuted ? "volume_off" : scope.deviceIcon
        size: scope.iconSize
        color: scope.deviceMuted ? scope.mutedColor : scope.deviceColor
        rotation: -scope.rotation
        x: scope.cx - scope.outer - width / 2
        y: scope.cy + 6
    }
    DankIcon {
        name: scope.pcMuted ? "volume_off" : scope.pcIcon
        size: scope.iconSize
        color: scope.pcMuted ? scope.mutedColor : scope.pcColor
        rotation: -scope.rotation
        x: scope.cx - scope.inner - width / 2
        y: scope.cy + 6
    }

    // The number, next to the moon that moves, only while it moves
    component Readout: StyledText {
        property real radiusAt: 0
        property real deg: 180
        property bool shown: false
        // Off the moon along its radius (negative: toward the center)
        property real gap: 24
        // No room above the outer moon (near the top edge): just inside it
        readonly property real _out: scope.cy + Math.sin(deg * Math.PI / 180) * (radiusAt + gap) - height / 2 >= 0 ? gap : -gap - 6
        readonly property real px: scope.cx + Math.cos(deg * Math.PI / 180) * (radiusAt + _out)
        readonly property real py: scope.cy + Math.sin(deg * Math.PI / 180) * (radiusAt + _out)
        x: Math.max(0, Math.min(scope.width - width, px - width / 2))
        y: Math.max(0, py - height / 2)
        rotation: -scope.rotation
        font.pixelSize: Math.max(11, Math.round(scope.outer * 0.1))
        font.weight: Font.DemiBold
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            enabled: scope.motion
            NumberAnimation {
                duration: 160
            }
        }
    }
    Readout {
        radiusAt: scope.outer
        deg: Polar.end("outer", scope._dev)
        text: Math.round(Math.max(0, scope.deviceLevel) * 100) + "%"
        color: scope.deviceColor
        shown: scope.hasDevice && !scope.sideNumbers && (scope.numbers || scope.talking === "device" || scope.dragging === "device")
    }
    Readout {
        // Inside the inner arc, so it never meets the outer moon
        radiusAt: scope.inner
        gap: -26
        deg: Polar.end("inner", scope._pc)
        text: Math.round(scope.pcLevel * 100) + "%"
        color: scope.pcColor
        shown: !scope.sideNumbers && (scope.numbers || scope.talking === "pc" || scope.dragging === "pc")
    }

    // Beside the half circles: the device's level on the left, where its
    // arc starts, this PC's on the right
    component SideNumber: Column {
        property real level: 0
        property bool muted: false
        property color tint: "white"
        property string label: ""
        property bool lit: false
        readonly property real size: Math.max(18, Math.min(30, scope.outer * 0.22))
        y: scope.cy - scope.outer * 0.62 - height / 2
        width: scope.sideRoom
        spacing: 1
        rotation: -scope.rotation
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            StyledText {
                text: parent.parent.muted ? "Muted" : Math.round(parent.parent.level * 100)
                font.pixelSize: parent.parent.muted ? parent.parent.size * 0.6 : parent.parent.size
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: parent.parent.muted ? scope.mutedColor : parent.parent.tint
                anchors.baseline: unit.baseline
            }
            StyledText {
                id: unit
                visible: !parent.parent.muted
                text: "%"
                font.pixelSize: parent.parent.size * 0.5
                font.weight: Font.Medium
                color: Theme.withAlpha(parent.parent.tint, 0.7)
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.label
            font.pixelSize: Math.max(10, Math.round(parent.size * 0.4))
            color: parent.lit ? parent.tint : scope.mutedColor
            width: Math.min(implicitWidth, scope.sideRoom)
            elide: Text.ElideRight
        }
    }
    SideNumber {
        visible: scope.sideNumbers && scope.hasDevice
        x: 6
        level: Math.max(0, scope.deviceLevel)
        muted: scope.deviceMuted
        tint: scope.deviceColor
        label: scope.deviceLabel
        lit: scope.talking === "device" || scope.dragging === "device"
    }
    SideNumber {
        visible: scope.sideNumbers
        x: scope.width - width - 6
        level: scope.pcLevel
        muted: scope.pcMuted
        tint: scope.pcColor
        label: scope.pcLabel
        lit: scope.talking === "pc" || scope.dragging === "pc"
    }

    // --- Gestures -------------------------------------------------------------------
    // Drag along an arc, or scroll over it: 5 % steps
    property alias pointer: pointer
    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: scope.interactive
        hoverEnabled: true
        preventStealing: true
        property string hover: ""
        cursorShape: hover || scope.dragging ? Qt.PointingHandCursor : Qt.ArrowCursor
        function partAt(m) {
            const z = Polar.zone(m.x - scope.cx, m.y - scope.cy, scope.outer, scope.inner, Math.max(12, scope.stroke * 3), false);
            return z === "outer" ? (scope.hasDevice ? "device" : "") : z === "inner" ? "pc" : "";
        }
        function valueAt(part, m) {
            return Polar.valueAt(part === "device" ? "outer" : "inner", m.x - scope.cx, m.y - scope.cy);
        }
        onPositionChanged: m => {
            hover = partAt(m);
            if (scope.dragging)
                scope.moved(scope.dragging, valueAt(scope.dragging, m));
        }
        onExited: hover = ""
        // The icons at the feet of the half circles mute or unmute their level
        function iconAt(m) {
            const near = (x, y) => Math.abs(m.x - x) <= scope.iconSize && Math.abs(m.y - y) <= scope.iconSize;
            const footY = scope.cy + 6 + scope.iconSize / 2;
            if (scope.hasDevice && near(scope.cx - scope.outer, footY))
                return "device";
            return near(scope.cx - scope.inner, footY) ? "pc" : "";
        }
        onPressed: m => {
            const part = partAt(m);
            if (!part) {
                const icon = iconAt(m);
                if (icon)
                    scope.muteClicked(icon);
                else
                    m.accepted = false;
                return;
            }
            scope.dragging = part;
            scope.talk(part);
            scope.moved(part, valueAt(part, m));
        }
        onReleased: {
            if (scope.dragging)
                scope.talk(scope.dragging);
            scope.dragging = "";
        }
        onCanceled: scope.dragging = ""
        property real acc: 0
        onWheel: w => {
            const part = hover || (scope.hasDevice ? "device" : "pc");
            acc += w.angleDelta.y;
            const steps = Math.trunc(acc / 120);
            if (steps === 0)
                return;
            acc -= steps * 120;
            scope.talk(part);
            if (scope.smartWheel) {
                for (let k = 0; k < Math.abs(steps); k++)
                    scope.stepped(part, steps > 0 ? 1 : -1);
                return;
            }
            const now = part === "device" ? scope.deviceLevel : scope.pcLevel;
            scope.moved(part, Polar.clamp01(Math.round(now * 20 + steps) / 20));
        }
    }
}
