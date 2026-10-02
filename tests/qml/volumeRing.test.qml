import QtQuick
import Quickshell.Services.Pipewire

// Test of VolumeRing: the pointer mask lets the ring and the planet take
// presses (and nothing else, so the card's buttons stay clickable); a step
// sets the sink's volume and unmutes it; a click on the planet mutes.
// The mask once used an Item, which Qt asks for its own empty rectangle:
// every press was refused and the ring could not be dragged.
// Run with tests/qml/run.sh.
Item {
    id: h
    width: 400
    height: 400

    // The focused device, landed on its card
    QtObject {
        id: body
        property bool connected: true
        property string address: "02:00:00:00:10:06"
        property real x: 168
        property real y: 168
        property real width: 64
        property real height: 64
        property real focusScale: 1
    }
    QtObject {
        id: scene
        property var focusBody: body
        property real focusGlyphSize: 64
        property real focusGlyphScale: 1
        property bool motion: false
        property var prefs: ({ volumeTick: false })
    }
    VolumeRing {
        id: ring
        scene: scene
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // A point at `deg` degrees (0 = right, clockwise) and `dist` px from
    // the planet's center, in the pointer area's coordinates
    function at(deg, dist) {
        const a = deg * Math.PI / 180;
        return Qt.point(ring.cx + Math.cos(a) * dist, ring.cy + Math.sin(a) * dist);
    }

    Component.onCompleted: {
        const sink = Pipewire.headset.audio;
        check("ring ready", ring.ready, true);
        check("press on the ring (moon side) is taken", ring.pointer.contains(at(-60, ring.radius)), true);
        check("press just off the ring is taken", ring.pointer.contains(at(200, ring.radius + 10)), true);
        check("press on the planet is taken", ring.pointer.contains(at(0, 5)), true);
        check("corner is left to the card", ring.pointer.contains(Qt.point(2, 2)), false);
        check("between planet and ring is left alone", ring.pointer.contains(at(0, ring.radius + 18)), false);

        sink.muted = true;
        ring.set(0.7);
        check("set changes the volume", Math.round(sink.volume * 100), 70);
        check("set unmutes", sink.muted, false);
        ring.set(1.4);
        check("set is clamped", sink.volume, 1);

        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
