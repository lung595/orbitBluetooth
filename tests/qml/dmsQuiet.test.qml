import QtQuick
import "components/volume"

// Test of DmsQuiet: a stand-in for DMS's settings reads "volume OSD off" while
// the `osd` switch is on, and "volume sound off" only while Orbit moves a
// level (`hold`, with `replaceSound`) and a moment after; when a switch ends,
// or the owner goes (plugin off), DMS's own value is back. While DMS saves its
// settings the switches are let go, so that a forced value is never written to
// disk (P143). Nothing is ever written for good by the plugin (value 12, D273,
// D360). Run with tests/qml/run.sh.
Item {
    id: h

    QtObject {
        id: dms
        property bool osdVolumeEnabled: true
        property bool soundVolumeChanged: true
        // DMS's flag, raised for the instant of a save
        property bool _selfWrite: false
    }
    DmsQuiet {
        id: quiet
        settings: dms
        soundWait: 300
    }
    // A DMS whose sound flag is gone (renamed by an update): nothing to hold
    QtObject {
        id: dms3
        property bool osdVolumeEnabled: true
        property bool _selfWrite: false
    }
    DmsQuiet {
        id: quiet3
        settings: dms3
        osd: true
        replaceSound: true
    }
    // An owner that goes while it holds (the overlay when the plugin is
    // turned off)
    QtObject {
        id: dms2
        property bool osdVolumeEnabled: true
        property bool soundVolumeChanged: true
    }
    Component {
        id: ownerMaker
        Item {
            id: owner
            property alias quiet: inner
            required property var settings
            DmsQuiet {
                id: inner
                settings: owner.settings
                osd: true
                replaceSound: true
            }
        }
    }

    property int failures: 0
    // A property by its name, for the one the stand-in does not have
    function read(object, name) {
        return object[name];
    }
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    readonly property var steps: [
        // --- The OSD (D273) ---------------------------------------------------------
        {
            "run": () => check("at rest DMS's OSD is as the user set it", dms.osdVolumeEnabled, true)
        },
        {
            "run": () => {
                quiet.osd = true;
                check("on: DMS's volume OSD is off", dms.osdVolumeEnabled, false);
                check("and DMS's volume sound is not touched", dms.soundVolumeChanged, true);
            }
        },
        {
            "run": () => {
                dms._selfWrite = true;
                check("a save in progress sees DMS's own value", dms.osdVolumeEnabled, true);
                dms._selfWrite = false;
                check("and the switch is back once the save is seen", dms.osdVolumeEnabled, false);
            }
        },
        {
            // A save that changes nothing leaves DMS's flag up for good
            "run": () => {
                dms._selfWrite = true;
                check("a save without a file event: the switch lets go", dms.osdVolumeEnabled, true);
            },
            "wait": 400
        },
        {
            "run": () => {
                check("then DMS's flag is lowered", dms._selfWrite, false);
                check("and the switch is back", dms.osdVolumeEnabled, false);
                dms._selfWrite = true;
                check("the next save is seen too", dms.osdVolumeEnabled, true);
                dms._selfWrite = false;
                check("and the switch comes back", dms.osdVolumeEnabled, false);
            }
        },
        {
            "run": () => {
                quiet.osd = false;
                check("ended: DMS's setting is back", dms.osdVolumeEnabled, true);
                dms.osdVolumeEnabled = false;
                check("and it is the user's again to change", dms.osdVolumeEnabled, false);
                dms.osdVolumeEnabled = true;
            }
        },
        // --- The volume sound (D360) -------------------------------------------------
        {
            "run": () => {
                check("at rest DMS's volume sound is as the user set it", [dms.soundVolumeChanged, quiet.holding, quiet.wait.running], [true, false, false]);
                quiet.hold();
                check("a level moves but the tick is not asked for alone: DMS's sound stays", [dms.soundVolumeChanged, quiet.holding, quiet.wait.running], [true, false, false]);
                quiet.replaceSound = true;
                check("asked for, and nothing moves: still nothing held, nothing running", [dms.soundVolumeChanged, quiet.holding, quiet.wait.running], [true, false, false]);
            }
        },
        {
            "run": () => {
                quiet.hold();
                check("a level moves: DMS's volume sound waits", [dms.soundVolumeChanged, quiet.holding, quiet.wait.running], [false, true, true]);
                check("the OSD switch is another one, untouched", dms.osdVolumeEnabled, true);
            }
        },
        {
            "run": () => {
                dms._selfWrite = true;
                check("a save in progress sees DMS's own sound value", dms.soundVolumeChanged, true);
                dms._selfWrite = false;
                check("and the sound waits again once the save is seen", dms.soundVolumeChanged, false);
            },
            "wait": 400
        },
        {
            "run": () => check("a moment after the last level, DMS's sound is back and nothing runs", [dms.soundVolumeChanged, quiet.holding, quiet.wait.running], [true, false, false])
        },
        // Two writes in a row are one window: the second one extends the first
        {
            "run": () => quiet.hold(),
            "wait": 200
        },
        {
            "run": () => quiet.hold(),
            "wait": 200
        },
        {
            // 400 ms after the first write, 200 after the second: the first window
            // (300) is over, the second one is not
            "run": () => check("a second write extends the window", dms.soundVolumeChanged, false),
            "wait": 300
        },
        {
            "run": () => check("and one window ends it", [dms.soundVolumeChanged, quiet.wait.running], [true, false])
        },
        // A hold that begins while DMS saves is not forced into the file
        {
            "run": () => {
                dms._selfWrite = true;
                quiet.hold();
                check("held during a save: DMS's own value is what it writes", [dms.soundVolumeChanged, quiet.holding], [true, true]);
                dms._selfWrite = false;
                check("then it waits as asked", dms.soundVolumeChanged, false);
                quiet.replaceSound = false;
                check("the tick is not alone any more: DMS's sound is back at once, the timer stopped", [dms.soundVolumeChanged, quiet.holding, quiet.wait.running], [true, false, false]);
                quiet.hold();
                check("and nothing holds it again", [dms.soundVolumeChanged, quiet.wait.running], [true, false]);
                quiet.replaceSound = true;
                quiet.soundWait = 3000;
                quiet.hold();
                dms._selfWrite = true;
                check("a save in a long hold: the sound lets go", dms.soundVolumeChanged, true);
            },
            "wait": 400
        },
        {
            "run": () => {
                check("DMS's flag was lowered by the plugin", dms._selfWrite, false);
                check("and the sound waits again", dms.soundVolumeChanged, false);
                quiet.replaceSound = false;
                quiet.soundWait = 300;
                check("ended: DMS's volume sound is back", dms.soundVolumeChanged, true);
                dms.soundVolumeChanged = false;
                check("and it is the user's again to change", dms.soundVolumeChanged, false);
                dms.soundVolumeChanged = true;
            }
        },
        // --- Whoever owns it goes, or there is nothing to hold --------------------------
        {
            "run": () => {
                h.owner = ownerMaker.createObject(h, {
                    "settings": dms2
                });
                h.owner.quiet.hold();
                check("a second owner switches its own settings off", [dms2.osdVolumeEnabled, dms2.soundVolumeChanged], [false, false]);
                h.owner.destroy();
            }
        },
        {
            "run": () => check("gone while holding: DMS's settings are back", [dms2.osdVolumeEnabled, dms2.soundVolumeChanged], [true, true])
        },
        {
            "run": () => {
                h.owner = ownerMaker.createObject(h, {
                    "settings": null
                });
                h.owner.quiet.hold();
                check("no settings to switch: nothing breaks", [h.owner.quiet.osd, h.owner.quiet.holding], [true, true]);
                h.owner.destroy();
            }
        },
        {
            "run": () => {
                quiet3.hold();
                check("no sound flag in DMS: it is not made up, the OSD is still held", [h.read(dms3, "soundVolumeChanged"), dms3.osdVolumeEnabled], [undefined, false]);
                check("and the sound's Binding is never switched on without the flag", [quiet3.hasSoundFlag, quiet3.holding, quiet3.volumeSound.when], [false, true, false]);
                quiet3.replaceSound = false;
                quiet3.osd = false;
                check("and it all ends cleanly", [h.read(dms3, "soundVolumeChanged"), dms3.osdVolumeEnabled], [undefined, true]);
            }
        }
    ]
    property var owner: null
    property int at: 0

    // One step per turn of the event loop, so that a destroyed owner is gone
    // before the next check
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
        clock.interval = steps[at - 1].wait || 20;
        clock.start();
    }
    Component.onCompleted: Qt.callLater(next)
}
