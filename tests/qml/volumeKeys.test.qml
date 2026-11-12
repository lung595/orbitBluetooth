import QtQuick
import Quickshell.Io
import "components/volume"
import "components/volume/Keys.js" as KeyBinds

// Test of VolumeKeys (NAK-214, D265): the keys are DMS's by default. Keys an
// older version took by itself go back to DMS at the first start, once; a
// later start runs nothing. The user's "use smart steps" binds them and is
// remembered; giving them back unbinds them; a shortcut of the user's own is
// left alone. The uninstall reads DMS's listing itself (uninstall/ tests).
// `dms keybinds` is played by hand through the stand-in processes (a listing
// as DMS prints it, the answer of each `set`). Made-up shortcuts only. Run
// with tests/qml/run.sh.
Item {
    id: h

    // The plugin's settings as Prefs shows them, with what was saved
    component FakePrefs: QtObject {
        property bool keysOrbit: false
        property bool keysReturned: false
        property var saved: ({})
        function set(key, value) {
            saved[key] = value;
            if (key === "keysOrbit")
                keysOrbit = value;
            if (key === "keysReturned")
                keysReturned = value;
        }
    }

    readonly property string dmsUp: "spawn dms ipc call audio increment 5"
    readonly property string dmsDown: "spawn dms ipc call audio decrement 5"
    function listing(up, down) {
        return JSON.stringify({
            "binds": {
                "Audio": [
                    {
                        "key": "XF86AudioRaiseVolume",
                        "action": up
                    },
                    {
                        "key": "XF86AudioLowerVolume",
                        "action": down
                    }
                ]
            }
        });
    }
    // The processes that exist: `dms keybinds show` and `dms keybinds set`
    function shower() {
        return ProcessLog.live.find(p => p.command[2] === "show");
    }
    function setter() {
        return ProcessLog.live.find(p => p.command[2] !== "show");
    }
    function answer(p, text) {
        p.stdout.text = text;
        p.running = false;
        p.exited(0);
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    FakePrefs {
        id: prefs
    }
    VolumeKeys {
        id: keys
        prefs: prefs
    }

    // One user's story, step by step: each `run` is a turn of the event loop
    readonly property var steps: [
        {
            "run": () => {
                check("a fresh start reads nothing before it is asked", [keys.keys, h.shower().running], ["unknown", false]);
                keys.claim();
                check("the first start reads the keys once", h.shower().running, true);
                check("and remembers that it did", [prefs.keysReturned, prefs.saved.keysOrbit], [true, undefined]);
                // An older version had taken them by itself
                h.answer(h.shower(), h.listing(KeyBinds.action("up", 5), KeyBinds.action("down", 5)));
                check("keys taken by an older version: the up key goes back to DMS with its step", h.setter().command[5], h.dmsUp);
                h.answer(h.setter(), '{"success":true}');
                check("and the down key", h.setter().command[5], h.dmsDown);
                h.answer(h.setter(), '{"success":true}');
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                check("DMS's keys again, nothing failed", [keys.keys, keys.failed], ["dms", false]);
            }
        },
        {
            "run": () => {
                keys.claim();
                check("a later start reads nothing, binds nothing", [h.shower().running, h.setter().running, keys.keys], [false, false, "dms"]);
            }
        },
        {
            "run": () => {
                keys.enable();
                check("the user asks for smart steps: remembered", [prefs.saved.keysOrbit, prefs.keysOrbit], [true, true]);
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                check("DMS's default keys: the up key is set to Orbit", [h.setter().running, h.setter().command.slice(0, 5)], [true, ["dms", "keybinds", "set", "niri", "XF86AudioRaiseVolume"]]);
                check("with Orbit's action and DMS's own step as the fallback", h.setter().command[5], KeyBinds.action("up", 5));
                h.answer(h.setter(), '{"success":true}');
                check("then the down key", h.setter().command[4], "XF86AudioLowerVolume");
                h.answer(h.setter(), '{"success":true}');
                h.answer(h.shower(), h.listing(KeyBinds.action("up", 5), KeyBinds.action("down", 5)));
                check("the keys are Orbit's, nothing failed", [keys.keys, keys.failed], ["orbit", false]);
            }
        },
        {
            "run": () => {
                keys.claim();
                check("asked for: a restart binds them again", h.shower().running, true);
                h.answer(h.shower(), h.listing(KeyBinds.action("up", 5), KeyBinds.action("down", 5)));
                check("already Orbit's: nothing to set", h.setter().running, false);
            }
        },
        {
            "run": () => {
                keys.disable();
                check("giving back is remembered", [prefs.saved.keysOrbit, prefs.keysOrbit], [false, false]);
                h.answer(h.shower(), h.listing(KeyBinds.action("up", 5), KeyBinds.action("down", 5)));
                check("the up key goes back to DMS's own action with its step", h.setter().command[5], h.dmsUp);
                h.answer(h.setter(), '{"success":true}');
                check("and the down key", h.setter().command[5], h.dmsDown);
                h.answer(h.setter(), '{"success":true}');
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                check("DMS's keys again", keys.keys, "dms");
            }
        },
        {
            "run": () => {
                keys.enable();
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                h.answer(h.setter(), '{"success":false}');
                check("a refusal of DMS stops there and is said", [keys.failed, h.setter().running], [true, false]);
                h.answer(h.shower(), h.listing(KeyBinds.action("up", 5), h.dmsDown));
            }
        },
        {
            "run": () => {
                keys.claim();
                h.answer(h.shower(), h.listing("spawn pamixer -i 5", h.dmsDown));
                check("the user's own shortcut is left alone", [keys.keys, h.setter().running], ["custom", false]);
            }
        },
        {
            "run": () => {
                keys.disable();
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                keys.enable();
                // `volumeKeys status` from the command line while the read runs
                keys.refresh();
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                check("a status read meanwhile does not cancel the bind", [h.setter().running, h.setter().command[4]], [true, "XF86AudioRaiseVolume"]);
                h.answer(h.setter(), '{"success":true}');
                h.answer(h.setter(), '{"success":true}');
                h.answer(h.shower(), h.listing(KeyBinds.action("up", 5), KeyBinds.action("down", 5)));
                check("and the keys end up Orbit's", keys.keys, "orbit");
            }
        }
    ]
    property int at: 0
    Timer {
        id: clock
        interval: 20
        onTriggered: h.next()
    }
    function next() {
        if (at >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        steps[at++].run();
        clock.start();
    }
    Component.onCompleted: Qt.callLater(next)
}
