import QtQuick
import "components/volume"

// Test of how often PolarVisual paints (volume research, 2026-10-05). A step of
// its sectors (every volume step moves their sizes) used to ask for a picture on
// top of the feed's own frames, so a held volume key made the scope paint about
// twice as often as the sound moved it. Now a step asks only when nothing else is
// about to paint it: on a blank picture it asks for nothing, and while frames
// arrive they carry the new sizes. The paints are counted on the Canvas's own
// `painted` signal. Run with tests/qml/run.sh.
Item {
    id: h
    width: 360
    height: 200

    // A made-up ScopeFeed
    Item {
        id: feed
        property var frame: null
        property bool active: true
        signal arrived
        function push(f) {
            frame = f;
            arrived();
        }
    }
    ScopeModel {
        id: scopeModel
        feed: feed
        gain: 0.5
    }
    PolarVisual {
        id: vis
        anchors.fill: parent
        model: scopeModel
        centerX: 180
        centerY: 160
        radius: 100
    }

    property int failures: 0
    function check(what, ok, detail) {
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  " + detail));
    }

    property int paints: 0
    property int frames: 0
    property bool turn: false
    // The scope's sectors with a made-up size, as a volume step would make them
    function sectorsAt(scale) {
        return [
            {
                "color": "white",
                "scale": scale,
                "quiet": false
            }
        ];
    }

    Component.onCompleted: {
        const canvas = vis.children.find(c => "renderStrategy" in c);
        canvas.painted.connect(() => h.paints++);
        // The first paints of a new Canvas are not the test's business
        blank.start();
    }

    // 1. Blank picture: ten volume steps ask for nothing
    Timer {
        id: blank
        interval: 600
        onTriggered: {
            h.paints = 0;
            for (let i = 0; i < 10; i++)
                vis.sectors = h.sectorsAt(1 - i * 0.03);
            blankEnd.start();
        }
    }
    Timer {
        id: blankEnd
        interval: 400
        onTriggered: {
            h.check("a volume step on a blank picture paints nothing", h.paints === 0, "painted " + h.paints + " times");
            h.paints = 0;
            h.frames = 0;
            sound.start();
            steps.start();
            stop.start();
        }
    }

    // 2. Sound flowing: a frame every 33 ms and, between two of them, several volume steps
    Timer {
        id: sound
        interval: 33
        repeat: true
        onTriggered: {
            feed.push({
                "l": [0.8, 0.5, 0.3],
                "r": [0.6, 0.7, 0.2]
            });
            h.frames++;
        }
    }
    // A held volume key repeats about 25 times a second, and each step may move several arcs
    Timer {
        id: steps
        interval: 11
        repeat: true
        onTriggered: {
            h.turn = !h.turn;
            vis.sectors = h.sectorsAt(h.turn ? 0.8 : 1);
        }
    }
    Timer {
        id: stop
        interval: 1500
        onTriggered: {
            sound.stop();
            steps.stop();
            // One paint per frame at most (a couple more: the last fade step, a repaint of the first frame)
            h.check("sound flowing: the steps add no paint to the frames' own (" + h.frames + " frames)", h.paints <= h.frames + 3, "painted " + h.paints + " times for " + h.frames + " frames");
            h.check("and the sound is painted (counter-proof: the test does count paints)", h.paints >= h.frames / 2, "painted only " + h.paints + " times for " + h.frames + " frames");
            print(h.failures ? h.failures + " failure(s)" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }
    }
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 20000
        running: true
        onTriggered: {
            print("FAIL timed out");
            Qt.exit(1);
        }
    }
}
