import QtQuick
import "components/device"
import "components/scene"

// Test of the battery arc around a device's disc (BodyArcs): its colour drifts
// from the theme's red through its amber to its green as the level climbs, a
// point of level moves it, and it keeps a colour of its own while the device
// charges. The colours are the scene's (NightColors); the body is a stand-in
// with only what the arcs read. Run with tests/qml/run.sh.
Item {
    id: h
    width: 80
    height: 80

    NightColors {
        id: tones
    }
    QtObject {
        id: fake
        property int battery: 100
        property bool charging: false
        property bool connected: true
        property bool focused: false
        property string ancMode: ""
        property real diameter: 60
        readonly property var night: tones
        readonly property var scene: ({
                "motion": false,
                "awake": false,
                "fxTime": 0
            })
    }
    BodyArcs {
        id: arcs
        anchors.fill: parent
        body: fake
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // The arc's colour for a level, copied: QML hands a colour property out by
    // reference, so two levels read one after the other would be the same value
    function tint(level, charging) {
        fake.battery = level;
        fake.charging = charging === true;
        const c = arcs.tint;
        return Qt.rgba(c.r, c.g, c.b, c.a);
    }
    function apart(a, b) {
        return Math.hypot(a.r - b.r, a.g - b.g, a.b - b.b);
    }
    function same(a, b) {
        return apart(a, b) < 0.004;
    }
    // Each one farther than the one before
    function climbs(values) {
        return values.every((v, i) => i === 0 || v > values[i - 1]);
    }

    Component.onCompleted: {
        const red = tones.error, amber = tones.warning, green = tones.success;
        check("the three tones are told apart", [apart(red, amber) > 0.2, apart(amber, green) > 0.2], [true, true]);

        check("a full battery is the theme's green", same(tint(100), green), true);
        check("15 % and down is the theme's red", [15, 8, 0].map(l => same(tint(l), red)), [true, true, true]);
        check("35 % is the theme's amber", same(tint(35), amber), true);

        const between = tint(25);
        check("25 % is neither red nor amber but between them", [same(between, red), same(between, amber), apart(between, red) < apart(red, amber), apart(between, amber) < apart(red, amber)], [false, false, true, true]);
        check("from red to amber it moves away from red all the way", climbs([15, 20, 25, 30, 35].map(l => apart(tint(l), red))), true);
        check("from amber to full it moves toward green all the way", climbs([100, 85, 70, 50, 35].map(l => apart(tint(l), green))), true);
        check("a point of level moves the colour", [apart(tint(60), tint(61)) > 0, apart(tint(20), tint(21)) > 0], [true, true]);
        check("it never passes through a colour of the other side (no jump at 35 %)", apart(tint(35), tint(36)) < 0.05, true);

        check("charging: a colour of its own, whatever the level", [100, 50, 5].map(l => same(tint(l, true), tones.charging)), [true, true, true]);
        check("and not the green of a full battery", same(tint(100, true), green), false);
        check("a device that stops charging gets its level's colour back", same(tint(100), green), true);

        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }
}
