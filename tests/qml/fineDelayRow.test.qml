import QtQuick
import qs.Services
import qs.Modules.Plugins
import "components/settings"

// Test of the wired delay setting (D298): it reads what is saved and shows it
// with its sign; nothing is saved while it loads or while the thumb is dragged;
// one gesture saves once, when it ends, and a gesture that moves nothing saves
// nothing; the reset gives back 0 and moves the slider (a drag breaks a plain
// binding of it); a change made elsewhere (the IPC) moves the slider too; what
// is saved out of range is held within it. Run with tests/qml/run.sh.
Item {
    id: h

    PluginSettings {
        id: store
        // What the page would find already saved
        stored: ({
                "togetherFineDelay": 35
            })
    }
    // Stands in for the settings page: it words the rows from the index and shows them all
    SettingsView {
        id: index
    }
    Item {
        id: owner
        function shown(key) {
            return true;
        }
        function label(key) {
            return index.label(key);
        }
        function help(key) {
            return index.help(key);
        }
    }
    FineDelayRow {
        id: row
        owner: owner
        settings: store
    }

    Tally {
        id: tally
    }
    // The first item below `from` that `test` accepts, looking everywhere
    function find(from, test) {
        for (let i = 0; i < from.children.length; i++) {
            const item = from.children[i];
            if (test(item))
                return item;
            const inside = find(item, test);
            if (inside)
                return inside;
        }
        return null;
    }
    readonly property var slider: find(row, i => i.sliderDragFinished !== undefined)
    readonly property var reset: find(row, i => i.text === "Reset to 0")
    readonly property var shown: find(row, i => typeof i.text === "string" && / ms$/.test(i.text))
    readonly property var link: find(row, i => i.anchor !== undefined)
    // What was saved, as [key, value] pairs
    function saved() {
        return store.saves;
    }
    function elsewhere(ms, pluginId) {
        store.stored = ({
                "togetherFineDelay": ms
            });
        PluginService.pluginDataChanged(pluginId);
    }

    // DMS hands the service over once the page is built; the row reads it on the
    // next turn, and the checks wait for that turn to be over
    Timer {
        id: nextTurn
        interval: 20
        onTriggered: h.run()
    }
    Component.onCompleted: {
        store.pluginService = PluginService;
        nextTurn.start();
    }

    function run() {
        tally.check("the slider, the reset and the link are there", [slider !== null, reset !== null, shown !== null, link !== null], [true, true, true, true]);
        tally.check("the slider spans 100 ms either way, five at a time, and leaves the wheel to the page", [slider.minimum, slider.maximum, slider.step, slider.wheelEnabled, slider.showValue], [-100, 100, 5, false, false]);
        tally.check("the link goes to the guide's section on it", link.anchor, "wired-delay");

        // --- Reading what is saved ----------------------------------------------------
        tally.check("it reads what is saved", [row.value, slider.value], [35, 35]);
        tally.check("the value is shown with its sign", shown.text, "+35 ms");
        tally.check("something to give back: the reset is there", reset.visible, true);
        tally.check("nothing is saved while it loads", saved(), []);
        const width = shown.width;

        // --- A drag --------------------------------------------------------------------
        slider.dragTo(-20);
        tally.check("the value follows the thumb, with a true minus", [slider.value, shown.text], [-20, "−20 ms"]);
        slider.dragTo(-23);
        tally.check("the thumb goes by steps of five", slider.value, -25);
        tally.check("nothing is saved while the thumb is dragged", [saved(), row.value], [[], 35]);
        slider.release();
        tally.check("letting go saves once, the final value", [saved(), row.value], [[["togetherFineDelay", -25]], -25]);
        slider.release();
        tally.check("a release that moves nothing saves nothing", saved().length, 1);
        slider.dragTo(900);
        slider.release();
        tally.check("the thumb stays within the range", [slider.value, saved()[1]], [100, ["togetherFineDelay", 100]]);
        tally.check("the value never moves the others: its width is that of the longest", shown.width, width);

        // --- Giving it back ------------------------------------------------------------
        reset.clicked();
        tally.check("the reset saves 0", saved()[2], ["togetherFineDelay", 0]);
        tally.check("and moves the slider, which a drag had cut loose from its binding", [row.value, slider.value, shown.text], [0, 0, "0 ms"]);
        tally.check("nothing left to give back: the reset goes", reset.visible, false);

        // --- Changed elsewhere (dms ipc call orbitBluetooth wiredDelay …) --------------------
        const before = saved().length;
        elsewhere(45, "orbitBluetooth");
        tally.check("a change made elsewhere moves the slider", [row.value, slider.value, shown.text, reset.visible], [45, 45, "+45 ms", true]);
        tally.check("and is not saved again", saved().length, before);
        elsewhere(10, "anotherPlugin");
        tally.check("another plugin's change is none of its business", row.value, 45);
        elsewhere(999, "orbitBluetooth");
        tally.check("what is saved out of range is held within it", [row.value, slider.value], [100, 100]);
        elsewhere(-999, "orbitBluetooth");
        tally.check("either way", [row.value, slider.value], [-100, -100]);
        elsewhere("x", "orbitBluetooth");
        tally.check("what is not a number counts for nothing", [row.value, slider.value, shown.text], [0, 0, "0 ms"]);
        tally.check("none of it was saved by the page", saved().length, before);

        tally.finish();
    }
}
