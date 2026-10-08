import QtQuick
import "components/centre"

// Test of CentreRing (D295): the gauge around the group's source says that it
// is the volume. It sits on the source disc as it is drawn (its body, or the
// group's rule for a wired source) and not where the group is meant to be, the
// speaker at the arc's start follows the level and the mute, a thumb marks the
// end of the level once the arc has left the speaker, and the level is written
// out for a moment after every change, whoever made it, with no timer running
// at rest. The volume and the scene are stand-ins with only what the gauge
// reads. Run with tests/qml/run.sh.
Item {
    id: h

    QtObject {
        id: fake
        property real level: 0.4
        property bool ready: true
        property bool muted: false
        function set(value) {
            level = value;
        }
        function step(dir) {
            level += dir * 0.05;
        }
        function toggleMute() {
            muted = !muted;
        }
    }
    QtObject {
        id: night
        readonly property color primary: "#6aa7ff"
        readonly property color tertiary: "#c58cff"
        function ink(alpha) {
            return Qt.rgba(1, 1, 1, alpha);
        }
        function smoke(alpha) {
            return Qt.rgba(0.04, 0.045, 0.06, alpha);
        }
    }
    QtObject {
        id: stand
        readonly property var volume: fake
        readonly property var scene: ({
                "night": night,
                "coreSize": 75
            })
        readonly property var sizes: ({
                "ring": 60,
                "source": 40,
                "chipIcon": 17,
                "chip": 25
            })
        property var group: ({
                "x": 200,
                "y": 200,
                "scale": 1
            })
        readonly property real presence: 1
        // The source disc: its body follows its slot on a spring, so it is
        // not where the group is (a wired source has no body: the group's rule
        // puts it there)
        readonly property string source: "source"
        property bool wired: false
        property var disc: ({
                "px": 190,
                "py": 205,
                "diameter": 40,
                "baseScale": 1
            })
        function bodyOf(address) {
            return wired ? null : disc;
        }
        function spotOf(address) {
            return {
                "x": group.x,
                "y": group.y,
                "size": sizes.source * group.scale
            };
        }
    }
    CentreRing {
        id: ring
        centre: stand
        holdTime: 60
    }

    Loader {
        id: late
        active: false
        sourceComponent: CentreRing {
            centre: stand
            holdTime: 60
        }
    }

    // The ring as the scene loads it: by a loader that fills the scene, which
    // resizes the ring to the scene (the speaker once landed at the scene's top)
    Item {
        id: sceneHost
        width: 400
        height: 400
        Loader {
            id: filled
            anchors.fill: parent
            sourceComponent: CentreRing {
                centre: stand
                holdTime: 60
            }
        }
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // The item called `name` somewhere under `item`
    function named(item, name) {
        for (const child of item.children) {
            if (child.objectName === name)
                return child;
            const found = named(child, name);
            if (found)
                return found;
        }
        return null;
    }
    // Where the middle of the ring's speaker lands in `host`, to a hundredth of a pixel
    function speakerAt(host, ring) {
        const chip = named(ring, "speaker");
        const at = chip ? chip.mapToItem(host, chip.width / 2, chip.height / 2) : null;
        return at ? {
            "x": Math.round(at.x * 100) / 100,
            "y": Math.round(at.y * 100) / 100
        } : null;
    }

    function atRest() {
        check("created: nothing is written out, reading the level is no change", [ring.recent, ring.reading], [false, "40%"]);
        // The arc starts at the bottom left (135 degrees), 60 px from the disc's middle
        check("the speaker sits where the arc starts, on the disc and not on the group, whoever sizes the ring", [speakerAt(h, ring), speakerAt(sceneHost, filled.item)], [
            {
                "x": 147.57,
                "y": 247.43
            },
            {
                "x": 147.57,
                "y": 247.43
            }
        ]);
        stand.disc = {
            "px": 150,
            "py": 120,
            "diameter": 40,
            "baseScale": 0.5
        };
        check("and follows the disc as it moves and shrinks", speakerAt(sceneHost, filled.item), {
            "x": 128.79,
            "y": 141.21
        });
        stand.wired = true;
        stand.group = {
            "x": 150,
            "y": 120,
            "scale": 0.5
        };
        check("a wired source has no body: it follows the group's rule, the same place", speakerAt(sceneHost, filled.item), {
            "x": 128.79,
            "y": 141.21
        });
        stand.wired = false;
        stand.group = {
            "x": 200,
            "y": 200,
            "scale": 1
        };
        stand.disc = {
            "px": 200,
            "py": 200,
            "diameter": 40,
            "baseScale": 1
        };
        check("the speaker follows the level", [ring.glyph, (fake.level = 0, ring.glyph), (fake.level = 0.8, ring.glyph)], ["volume_down", "volume_mute", "volume_up"]);
        check("the thumb sits on the arc's end once it has left the speaker", [ring.thumbSize, (fake.level = 0.01, ring.thumbSize)], [12, 0]);
        fake.level = 0.4;
    }

    // Each change writes the level out, and the timer, not running before, ends it
    function changes() {
        check("the last change is over: nothing is written out", ring.recent, false);
        fake.level = 0.5;
        check("a change writes the level out", [ring.recent, ring.reading], [true, "50%"]);
        fake.muted = true;
        check("muted: it says so and the speaker is crossed out", [ring.reading, ring.glyph, ring.recent], ["Muted", "volume_off", true]);
    }

    function afterwards() {
        check("it stops by itself", ring.recent, false);
        fake.muted = false;
        check("unmuted: the level is written out again", [ring.recent, ring.reading], [true, "50%"]);
    }

    // Reading the sound for the first time is not a change (a group that has just formed)
    function firstReading() {
        check("it stopped again", ring.recent, false);
        fake.ready = false;
        check("no sound to read: nothing is said", ring.reading, "");
        fake.level = 0.3;
        fake.ready = true;
        check("the first reading is no change", [ring.recent, ring.reading], [false, "30%"]);
        fake.level = 0.35;
        check("the next one is (counter-proof)", ring.recent, true);
        // The ring of a group that is already speaking, as the scene makes it
        late.active = true;
        check("created with the sound already there: nothing is written out", [late.item.recent, late.item.reading], [false, "35%"]);
        fake.level = 0.6;
        check("and its first change counts", late.item.recent, true);
    }

    // Each step waits for the timer of the one before to have ended
    Timer {
        id: later
        property int round: 0
        interval: 200
        repeat: true
        onTriggered: {
            round++;
            if (round === 1) {
                h.changes();
            } else if (round === 2) {
                h.afterwards();
            } else if (round === 3) {
                h.firstReading();
            } else {
                print(h.failures ? h.failures + " failure(s)" : "all passed");
                Qt.exit(h.failures ? 1 : 0);
            }
        }
    }

    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 20000
        running: true
        onTriggered: {
            print("FAIL timed out: a step threw");
            Qt.exit(1);
        }
    }

    Component.onCompleted: {
        atRest();
        later.start();
    }
}
