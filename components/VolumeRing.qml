import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common
import qs.Widgets
import "Volume.js" as Volume

// Volume of the focused audio device, drawn as a ring floating around its
// glyph (like a planet's ring). Wheel = 5 % steps, drag along the ring =
// fine, click the glyph = mute. A soft tick is played in the device itself
// at its new level, so the step is heard where it matters.
// Bluetooth has no volume the shell can set: the sound server does, so the
// ring drives the device's PipeWire sink, found by its address. No sink
// (keyboard, mouse, not connected): no ring at all.
// Nothing runs at rest: no timer, no animation, the tick player starts only
// on a step.
Item {
    id: ring

    required property var scene
    readonly property var body: scene.focusBody
    readonly property string address: body && body.connected ? body.address : ""

    readonly property var sink: Volume.findSink(Pipewire.nodes.values, address)
    PwObjectTracker {
        objects: ring.sink ? [ring.sink] : []
    }
    readonly property bool ready: !!sink && !!sink.audio
    readonly property real volume: ready ? Math.min(1, sink.audio.volume) : 0
    readonly property bool muted: ready && sink.audio.muted

    // Geometry: centered on the focused glyph, just outside it
    readonly property real radius: scene.focusGlyphSize * 0.5 + 8
    readonly property real thickness: 3.5
    width: radius * 2 + 40
    height: width
    x: body ? body.x + body.width / 2 - width / 2 : 0
    y: body ? body.y + body.height / 2 - height / 2 : 0
    readonly property real cx: width / 2
    readonly property real cy: height / 2

    // Fades in once the glyph has landed on the card, out at once on leave
    visible: opacity > 0.01
    opacity: ready && body && body.focusScale > scene.focusGlyphScale * 0.92 ? 1 : 0
    Behavior on opacity {
        enabled: ring.scene.motion
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // What the arc shows: follows the volume on a spring (a wheel step
    // swings a little past and settles), straight under the finger while
    // dragging. `level` keeps the arc inside the ring when the spring
    // overshoots an end.
    property bool dragging: false
    property real shown: volume
    readonly property real level: Math.max(0, Math.min(1, shown))
    Behavior on shown {
        enabled: ring.scene.motion && !ring.dragging
        SpringAnimation {
            spring: 4.5
            damping: 0.32
            epsilon: 0.002
        }
    }

    function set(v) {
        if (!ready)
            return;
        const next = Volume.clamp(v);
        const step = Volume.step(volume) !== Volume.step(next);
        const rising = next > volume;
        sink.audio.muted = false;
        sink.audio.volume = next;
        if (step) {
            tick();
            dust.puff(rising);
        }
        talking = true;
        quiet.restart();
    }

    // --- The tick, played in the adjusted device -----------------------------
    readonly property string tickPath: decodeURIComponent(Qt.resolvedUrl("../sounds/volume.wav").toString().replace(/^file:\/\//, ""))
    property double _lastTick: 0
    function tick() {
        if (!scene.prefs.volumeTick || !Volume.validSink(sink.name))
            return;
        const now = Date.now();
        // A fast wheel must not stack sounds: one tick per 45 ms at most
        if (now - _lastTick < 45 || player.running)
            return;
        _lastTick = now;
        player.command = ["pw-play", "--target", sink.name, "--", tickPath];
        player.running = true;
    }
    Process {
        id: player
    }

    // The percentage shows while you adjust, then leaves
    property bool talking: false
    Timer {
        id: quiet
        interval: 1200
        onTriggered: ring.talking = false
    }

    // --- Drawing --------------------------------------------------------------
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: ring.muted ? 0.35 : 1

        // Track: the whole ring, faint
        ShapePath {
            strokeColor: Theme.withAlpha(Theme.primary, 0.18)
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.cx
                centerY: ring.cy
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: Volume.start
                sweepAngle: Volume.sweep
            }
        }
        // Halo under the level: the light of the ring
        ShapePath {
            strokeColor: Theme.withAlpha(Theme.primary, 0.22)
            strokeWidth: ring.thickness + 6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.cx
                centerY: ring.cy
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: Volume.start
                sweepAngle: Math.max(0.01, Volume.sweep * ring.level)
            }
        }
        // Level
        ShapePath {
            strokeColor: Theme.primary
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.cx
                centerY: ring.cy
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: Volume.start
                sweepAngle: Math.max(0.01, Volume.sweep * ring.level)
            }
        }
    }

    // The moon at the end of the level: what you grab
    Rectangle {
        readonly property real a: (Volume.start + Volume.sweep * ring.level) * Math.PI / 180
        property real knob: ring.dragging || drag.containsMouse && drag.onRing ? 14 : 11
        width: knob
        height: knob
        radius: knob / 2
        x: ring.cx + Math.cos(a) * ring.radius - knob / 2
        y: ring.cy + Math.sin(a) * ring.radius - knob / 2
        color: ring.muted ? Theme.surfaceVariantText : Theme.surfaceText
        border.width: 2
        border.color: Theme.primary
        Behavior on knob {
            enabled: ring.scene.motion
            NumberAnimation {
                duration: 120
            }
        }
    }

    // The level, read in the gap at the bottom of the ring
    VolumeReadout {
        x: ring.cx - width / 2
        // Inside the gap, on the planet's lower edge, clear of the name below
        y: ring.cy + ring.radius - 9 - height / 2
        value: Math.round(ring.volume * 100)
        muted: ring.muted
        active: ring.talking || ring.dragging || ring.muted
        motion: ring.scene.motion
    }

    // Stardust: a few sparks leave the moon at each step, thrown along its
    // path and bent back by the planet's pull
    VolumeDust {
        id: dust
        anchors.fill: parent
        centerX: ring.cx
        centerY: ring.cy
        radius: ring.radius
        angle: (Volume.start + Volume.sweep * ring.level) * Math.PI / 180
        motion: ring.scene.motion
    }

    // --- Gestures ---------------------------------------------------------------
    // Exposed for tests/qml/volumeRing.test.qml
    property alias pointer: drag

    WheelHandler {
        enabled: ring.ready
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: e => {
            // Touchpads send small deltas: add them up to whole steps
            acc += e.angleDelta.y;
            const steps = Math.trunc(acc / 120);
            if (steps === 0)
                return;
            acc -= steps * 120;
            ring.set(Volume.nudge(ring.volume, steps));
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        enabled: ring.ready
        preventStealing: true
        // Only the ring and the glyph take the pointer: the card's buttons
        // right next to the glyph stay reachable
        // A QtObject, not an Item: Qt asks an Item mask its own (empty)
        // rectangle and never calls this function
        containmentMask: QtObject {
            function contains(point: point): bool {
                return drag.zone(point) !== "";
            }
        }
        property bool onRing: false
        cursorShape: onRing || ring.dragging ? Qt.PointingHandCursor : Qt.ArrowCursor
        function zone(m) {
            return Volume.zone(m.x - ring.cx, m.y - ring.cy, ring.radius, ring.scene.focusGlyphSize * 0.5);
        }
        onPositionChanged: m => {
            onRing = zone(m) !== "";
            if (ring.dragging)
                ring.set(Volume.valueAt(m.x - ring.cx, m.y - ring.cy, ring.volume));
        }
        onPressed: m => {
            const z = zone(m);
            if (z === "ring") {
                ring.dragging = true;
                ring.set(Volume.valueAt(m.x - ring.cx, m.y - ring.cy, ring.volume));
            }
        }
        onReleased: ring.dragging = false
        onCanceled: ring.dragging = false
        onClicked: m => {
            if (zone(m) === "glyph" && ring.ready) {
                ring.sink.audio.muted = !ring.muted;
                ring.talking = true;
                quiet.restart();
            }
        }
    }
}
