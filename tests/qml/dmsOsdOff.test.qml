import QtQuick
import "components/volume"

// Test of DmsOsdOff: while active, a stand-in for DMS's settings reads
// "volume OSD off"; when it ends, or the owner goes (plugin off), DMS's own
// value is back. While DMS saves its settings the switch is let go, so that
// the forced value is never written to disk (P143). Nothing is ever written
// for good by the plugin (value 12, D273). Run with tests/qml/run.sh.
Item {
    id: h

    QtObject {
        id: dms
        property bool osdVolumeEnabled: true
        // DMS's flag, raised for the instant of a save
        property bool _selfWrite: false
    }
    DmsOsdOff {
        id: off
        settings: dms
    }
    // An owner that goes while it holds (the overlay when the plugin is
    // turned off)
    QtObject {
        id: dms2
        property bool osdVolumeEnabled: true
    }
    Component {
        id: ownerMaker
        Item {
            id: owner
            property alias off: inner
            required property var settings
            DmsOsdOff {
                id: inner
                settings: owner.settings
                active: true
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

    readonly property var steps: [
        {
            "run": () => check("at rest DMS's OSD is as the user set it", dms.osdVolumeEnabled, true)
        },
        {
            "run": () => {
                off.active = true;
                check("active: DMS's volume OSD is off", dms.osdVolumeEnabled, false);
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
                off.active = false;
                check("ended: DMS's setting is back", dms.osdVolumeEnabled, true);
                dms.osdVolumeEnabled = false;
                check("and it is the user's again to change", dms.osdVolumeEnabled, false);
                dms.osdVolumeEnabled = true;
            }
        },
        {
            "run": () => {
                h.owner = ownerMaker.createObject(h, {
                    "settings": dms2
                });
                check("a second owner switches its own settings off", dms2.osdVolumeEnabled, false);
                h.owner.destroy();
            }
        },
        {
            "run": () => check("gone while active: DMS's setting is back", dms2.osdVolumeEnabled, true)
        },
        {
            "run": () => {
                h.owner = ownerMaker.createObject(h, {
                    "settings": null
                });
                check("no settings to switch: nothing breaks", h.owner.off.active, true);
                h.owner.destroy();
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
