import QtQuick
import qs.Common
import qs.Services
import "components/scene"
import "mock"
import "mock/State.js" as State
import "mock/Devices.js" as Devices

// Test of the radar's sky: one Canvas that is painted once when the radar opens and
// again only when its size, the theme or the places of the dials change; never for a
// new hero, a level, a mute or the clock. Also times one paint (360 px card, four
// small dials, dark then light). Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 560

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string dac: "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"
    readonly property string screen: "alsa_output.pci-0000_00_1f.3.hdmi-stereo"

    FakeRoute {
        id: route
    }
    OrbitScene {
        id: scene
        anchors.fill: parent
        active: true
        autoScan: false
        previewDevices: Devices.list(false, 2)
        audioRoute: route
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function find(item, test) {
        for (const child of item.children) {
            if (test(child))
                return child;
            const found = find(child, test);
            if (found)
                return found;
        }
        return null;
    }
    readonly property var radar: scene.radar
    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling

    // The sky's paints since it was made
    property var sky: null
    property int paints: 0
    Connections {
        target: h.sky
        function onPainted() {
            h.paints++;
        }
    }
    // Milliseconds of one paint (the drawing and its raster), the median of 20 batches of 5
    function paintMs() {
        const ctx = h.sky.getContext("2d");
        const times = [];
        for (let i = 0; i < 20; i++) {
            const start = Date.now();
            for (let j = 0; j < 5; j++) {
                h.sky.draw(ctx);
                // Reading a pixel makes the canvas run what was drawn now
                ctx.getImageData(0, 0, 1, 1);
            }
            times.push((Date.now() - start) / 5);
        }
        times.sort((a, b) => a - b);
        return times[10];
    }

    readonly property var steps: [
        {
            "then": 100,
            "until": () => h.landed,
            "run": () => {
                SettingsData.reduceMotion = true;
                route.sharing = [h.headset, h.one, h.dac, h.screen];
            }
        },
        {
            "then": 100,
            "until": () => h.landed && scene.centre.members.length === 4,
            "run": () => {
                check("at rest there is no sky", h.find(scene, c => "actionsY" in c), null);
                h.radar.show("");
                // The view is made as the radar opens, before its first frame
                h.sky = h.find(scene, c => "actionsY" in c);
                check("opening the radar makes its sky", !!h.sky, true);
            }
        },
        {
            "then": 300,
            "run": () => {
                // The card's header settles in the first frame (the scene's glyph overlap grows
                // from 66 to 107 px while the card is still transparent), so the sky may
                // be painted a second time then, and never again
                check("the sky is painted as the radar opens, twice at most", h.paints >= 1 && h.paints <= 2, true);
                check("it takes no click and says nothing to a screen reader", [h.sky.enabled, h.sky.Accessible.ignored], [false, true]);
                check("it has a place for every small dial and an orbit around the hero", [h.sky.places.satellites.length, h.sky.side > 100], [4, true]);
                h.paints = 0;
                h.radar.show(h.one);
            }
        },
        {
            "then": 300,
            "run": () => {
                check("a new hero does not repaint it", [h.radar.heroId, h.paints], [h.one, 0]);
                h.radar.setLevel(h.one, 0.2);
                h.radar.toggleMute(h.one);
            }
        },
        {
            "then": 300,
            "run": () => {
                check("a level and a mute do not repaint it", h.paints, 0);
                Theme.isLightMode = true;
            }
        },
        {
            "then": 300,
            "run": () => {
                check("a light theme repaints it once", h.paints, 1);
                const ms = h.paintMs();
                h.paints = 0;
                print("paint, light, 360 px, 4 small dials: " + ms + " ms (median of 20)");
                check("a paint takes at most 5 ms, light", ms <= 5, true);
                Theme.isLightMode = false;
            }
        },
        {
            "then": 300,
            "run": () => {
                check("back to dark repaints it once more", h.paints, 1);
                h.paints = 0;
                const ms = h.paintMs();
                print("paint, dark, 360 px, 4 small dials: " + ms + " ms (median of 20)");
                check("a paint takes at most 5 ms, dark", ms <= 5, true);
                h.paints = 0;
                // Narrower than the card's 360 px
                h.width = 300;
            }
        },
        {
            "then": 300,
            "run": () => {
                check("a new size repaints it once", h.paints, 1);
                h.radar.close();
            }
        }
    ]

    property int step: 0
    property int waited: 0
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 60000
        running: true
        onTriggered: {
            print("FAIL timed out at step " + h.step);
            Qt.exit(1);
        }
    }
    Timer {
        id: clock
        onTriggered: h.next()
    }
    function next() {
        const prev = step > 0 ? steps[step - 1] : null;
        if (prev && prev.until && !prev.until() && waited < 20000) {
            waited += 50;
            clock.interval = 50;
            clock.start();
            return;
        }
        waited = 0;
        if (step >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        const s = steps[step++];
        s.run();
        clock.interval = s.then;
        clock.start();
    }
    Component.onCompleted: {
        PluginService.globalVars = State.globals("orbit", Date.now());
        Qt.callLater(next);
    }
}
