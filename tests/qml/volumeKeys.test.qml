import QtQuick
import Quickshell.Io
import "components/volume"
import "components/volume/Keys.js" as Keys

// Test of VolumeKeys (NAK-214, D265): on a fresh install the keys become
// Orbit's at the first start with no click; once the user gave them back, a
// restart does not take them again; a shortcut of the user's own is left
// alone; the step to give back is kept ready for the uninstall. `dms
// keybinds` is played by hand through the stand-in processes (a listing as
// DMS prints it, the answer of each `set`). Made-up shortcuts only. Run
// with tests/qml/run.sh.
Item {
    id: h

    // The plugin's settings as Prefs shows them, with what was saved
    component FakePrefs: QtObject {
        property bool keysGivenBack: false
        property var saved: ({})
        function set(key, value) {
            saved[key] = value;
            if (key === "keysGivenBack")
                keysGivenBack = value;
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
        property int told: 0
        onClaimed: told++
    }

    // One user's story, step by step: each `run` is a turn of the event loop
    readonly property var steps: [
        {
            "run": () => {
                check("a fresh start reads nothing before it is asked", [keys.keys, h.shower().running], ["unknown", false]);
                keys.claim();
                check("the first start reads the keys", h.shower().running, true);
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                check("DMS's default keys: the up key is set to Orbit, no click", [h.setter().running, h.setter().command.slice(0, 5)], [true, ["dms", "keybinds", "set", "niri", "XF86AudioRaiseVolume"]]);
                check("with Orbit's action and DMS's own step as the fallback", h.setter().command[5], Keys.action("up", 5));
                h.answer(h.setter(), '{"success":true}');
                check("then the down key", h.setter().command[4], "XF86AudioLowerVolume");
                h.answer(h.setter(), '{"success":true}');
                check("then one read to confirm", h.shower().running, true);
                h.answer(h.shower(), h.listing(Keys.action("up", 5), Keys.action("down", 5)));
                check("the keys are Orbit's, said once, nothing failed", [keys.keys, keys.told, keys.failed], ["orbit", 1, false]);
                check("nothing was remembered as given back", [keys.prefs.keysGivenBack, keys.prefs.saved.keysGivenBack], [false, undefined]);
                check("the uninstall has the give-back ready, with the step", keys.restore.slice(0, 2).concat(keys.restore.slice(4)), ["sh", "-c", "XF86AudioRaiseVolume", h.dmsUp, "XF86AudioLowerVolume", h.dmsDown]);
            }
        },
        {
            "run": () => {
                keys.disable();
                check("giving back is remembered", [prefs.saved.keysGivenBack, prefs.keysGivenBack], [true, true]);
                h.answer(h.shower(), h.listing(Keys.action("up", 5), Keys.action("down", 5)));
                check("the up key goes back to DMS's own action with its step", h.setter().command[5], h.dmsUp);
                h.answer(h.setter(), '{"success":true}');
                check("and the down key", h.setter().command[5], h.dmsDown);
                h.answer(h.setter(), '{"success":true}');
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                check("DMS's keys again, and nothing to give back at uninstall", [keys.keys, keys.restore, keys.told], ["dms", [], 1]);
            }
        },
        {
            "run": () => {
                keys.claim();
                check("after a give-back, a restart does not read, nor bind, anything", [h.shower().running, h.setter().running, keys.keys], [false, false, "dms"]);
            }
        },
        {
            "run": () => {
                keys.enable();
                check("the user asking again clears the give-back", [prefs.saved.keysGivenBack, prefs.keysGivenBack], [false, false]);
                h.answer(h.shower(), h.listing(h.dmsUp, h.dmsDown));
                check("and binds the keys", h.setter().running, true);
                h.answer(h.setter(), '{"success":false}');
                check("a refusal of DMS stops there and is said", [keys.failed, h.setter().running], [true, false]);
                h.answer(h.shower(), h.listing(Keys.action("up", 5), h.dmsDown));
                check("one key on Orbit is still given back at uninstall", keys.restore.slice(4), ["XF86AudioRaiseVolume", h.dmsUp]);
                check("a failed claim is not announced", keys.told, 1);
            }
        },
        {
            "run": () => {
                prefs.set("keysGivenBack", false);
                keys.claim();
                h.answer(h.shower(), h.listing("spawn pamixer -i 5", h.dmsDown));
                check("the user's own shortcut is left alone", [keys.keys, h.setter().running], ["custom", false]);
                check("and a claim that did nothing announces nothing", keys.told, 1);
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
