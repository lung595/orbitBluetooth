import QtQuick
import "components/card"

// Test of NAK-9 on the detail card: turning the wheel over a member's planet
// makes it the member the volume keys move, and a device outside a group does
// not. A stand-in route and scene; made-up addresses only.
// Run with tests/qml/run.sh.
Item {
    id: h

    QtObject {
        id: together
        property bool active: false
        function isMember(a: string): bool {
            return active && a === "AA:01";
        }
    }
    QtObject {
        id: route
        readonly property var together: together
        property string touched: ""
        property int steps: 0
        function find(a) {
            return {};
        }
        function mainPart(a) {
            return "main";
        }
        function touch(a) {
            touched = a;
        }
        function setLevel(part, dir, a) {
            steps++;
        }
    }
    QtObject {
        id: scene
        property bool detailOpen: true
        property var focusBody: ({
                "connected": true,
                "address": "AA:01",
                "x": 0,
                "y": 0,
                "width": 10,
                "height": 10,
                "focusScale": 1
            })
        property var audioRoute: route
        property real focusGlyphSize: 40
        property real focusGlyphScale: 1
        property var note: null
        function explain(n) {
        }
    }
    PlanetControl {
        id: planet
        scene: scene
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function wheel() {
        for (const o of planet.data)
            if (typeof o.turned === "function")
                o.turned(1, 0, 0);
    }

    Component.onCompleted: {
        wheel();
        check("no group: the level moves", route.steps, 1);
        check("no group: nothing is touched", route.touched, "");
        together.active = true;
        wheel();
        check("in a group: the level moves", route.steps, 2);
        check("in a group: the member is touched", route.touched, "AA:01");
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
