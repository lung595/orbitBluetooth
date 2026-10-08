import QtQuick
import qs.Common
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs.Services
import "components/scene"
import "components/volume"
import "mock"
import "mock/State.js" as State

// Test of the real scene with a view open while its device goes away (NAK-60):
// the detail card of a headset and the volume radar of a group, each held open
// while the headset disconnects mid-play, is destroyed while the list still
// holds it, then drops out of the list; and the group ends under the open
// radar. The QML warnings and TypeErrors this prints are counted by
// tests/qml/run.sh, which fails the test when there is any. The devices are
// real objects (Device.qml) so that destroy() leaves what Quickshell leaves
// behind. While each view is open, PipeWire's default output also vanishes,
// returns, goes to the headset and to an output with no name, read by the
// real AudioRoute (and the ghost of the scene) with the headset playing.
// Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"

    FakeRoute {
        id: route
    }
    Component {
        id: dev
        Device {}
    }
    // The real route over the same devices, the way the daemon holds it
    AudioRoute {
        id: realRoute
        prefs: QtObject {
            property bool volumeTick: false
            property bool tickAlone: true
            property bool separatePc: true
            property var pcLevels: ({})
            property string volumeSteps: "fixed"
            property int volumeStep: 5
            property string volumeSpeed: "balanced"
            property int togetherFineDelay: 0
        }
    }
    Component {
        id: nodeType
        QtObject {
            property string name: ""
        }
    }
    OrbitScene {
        id: scene
        anchors.fill: parent
        active: true
        autoScan: false
        audioRoute: route
    }

    function make(address, name, icon, battery) {
        return dev.createObject(h, {
            "address": address,
            "name": name,
            "deviceName": name,
            "icon": icon,
            "paired": true,
            "bonded": true,
            "connected": true,
            "battery": battery
        });
    }
    // The device list the scene draws and the route reads, kept together
    function setList(list) {
        Bluetooth.devices = list;
        scene.previewDevices = list;
        scene.refresh();
    }
    // The default output goes to the headset, vanishes, returns, then has no
    // name, with a view open; the route is asked what it makes of each
    function outputSteps(view) {
        const ask = what => () => {
                check(view + ": " + what, [realRoute.current?.address, realRoute.find("")?.address], [h.headset, h.headset]);
            };
        return [
            {
                "then": 250,
                "run": () => {
                    Pipewire.defaultAudioSink = Pipewire.headset;
                }
            },
            {
                "then": 250,
                "run": ask("the headset's output is the current one")
            },
            {
                "then": 250,
                "run": () => {
                    Pipewire.defaultAudioSink = null;
                }
            },
            {
                "then": 250,
                "run": () => {
                    check(view + ": no default output, no current device", [realRoute.current, realRoute.pcNode(null)], [null, null]);
                    Pipewire.defaultAudioSink = Pipewire.headset;
                }
            },
            {
                "then": 250,
                "run": ask("the output returns, the headset again")
            },
            {
                "then": 250,
                "run": () => {
                    Pipewire.defaultAudioSink = nodeType.createObject(h, {});
                }
            },
            {
                "then": 250,
                "run": () => {
                    check(view + ": an output with no name is no device", [realRoute.current, realRoute.pcNode(null).name], [null, ""]);
                    Pipewire.defaultAudioSink = null;
                }
            }
        ];
    }
    function body(address) {
        return scene.world.bodyList().find(b => b.address === address) ?? null;
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    property var phones: null
    property var speaker: null

    readonly property var steps: [
        {
            "then": 400,
            "run": () => {
                SettingsData.reduceMotion = true;
                h.phones = h.make(h.headset, "WH-1000XM6", "audio-headphones", 0.54);
                h.speaker = h.make(h.one, "Marantz Cinema 50", "audio-speakers", 0.8);
                h.setList([h.phones, h.speaker]);
            }
        },
        {
            "then": 300,
            "run": () => {
                // The detail card of the headset is open
                check("both devices are drawn", [!!h.body(h.headset), !!h.body(h.one)], [true, true]);
                scene.focusOn(h.body(h.headset));
            }
        },
        {
            "then": 300,
            "run": () => {
                check("the detail card is open on the headset", [scene.detailOpen, scene.focusBody?.address], [true, h.headset]);
            }
        },
        ...outputSteps("card open"),
        {
            "then": 300,
            "run": () => {
                // It disconnects in mid-play, the output being the headset's
                Pipewire.defaultAudioSink = Pipewire.headset;
                h.phones.connected = false;
            }
        },
        {
            "then": 300,
            "run": () => {
                // BlueZ destroys the object while the list still holds it
                h.phones.destroy();
            }
        },
        {
            "then": 300,
            "run": () => {
                // Then the list drops it
                h.setList([h.speaker]);
            }
        },
        {
            "then": 600,
            "run": () => {
                // The body fades out before it is dropped; the card follows it
                check("the headset that is gone is leaving the sky", h.body(h.headset)?.leaving, true);
                scene.clearFocus();
                // The radar of a group, on the headset
                h.phones = h.make(h.headset, "WH-1000XM6", "audio-headphones", 0.54);
                h.setList([h.phones, h.speaker]);
                route.sharing = [h.headset, h.one];
            }
        },
        {
            "then": 600,
            "run": () => {
                check("the group is formed", [scene.centre.grouped, scene.centre.members.length], [true, 2]);
                scene.radar.show(h.headset);
            }
        },
        {
            "then": 300,
            "run": () => {
                check("the radar is open on the headset", [scene.radar.open, scene.radar.heroId], [true, h.headset]);
            }
        },
        ...outputSteps("radar open"),
        {
            "then": 300,
            "run": () => {
                Pipewire.defaultAudioSink = Pipewire.headset;
                h.phones.battery = 0.2;
                h.phones.connected = false;
            }
        },
        {
            "then": 300,
            "run": () => {
                h.phones.destroy();
            }
        },
        {
            "then": 300,
            "run": () => {
                h.setList([h.speaker]);
                route.sharing = [h.one];
            }
        },
        {
            "then": 600,
            "run": () => {
                check("the radar is not left on a headset that is gone", scene.radar.heroId !== h.headset, true);
                // The group ends under an open radar, and the other device goes too
                scene.radar.show("");
                route.sharing = [];
                h.speaker.destroy();
                Pipewire.defaultAudioSink = null;
                h.setList([]);
            }
        },
        {
            "then": 600,
            "run": () => {
                check("no group, no radar", [scene.radar.open, scene.centre.grouped], [false, false]);
            }
        }
    ]
    property int step: 0
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 20000
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
        if (step >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        const s = steps[step++];
        try {
            s.run();
        } catch (e) {
            failures++;
            print("FAIL step " + step + " threw: " + e);
        }
        clock.interval = s.then;
        clock.start();
    }
    Component.onCompleted: {
        PluginService.globalVars = State.globals("orbit", Date.now());
        Qt.callLater(next);
    }
}
