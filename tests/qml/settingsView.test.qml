import QtQuick
import QtTest
import qs.Common
import "components/settings"

// Test of the settings page's view (NAK-261): the rail opens one category at
// a time, typing in the search field filters the page in place (badges on the
// rail, only the matching settings shown), Esc gives the page back, Enter and a
// click on the rail jump to the best match and light it once, and Reduce
// motion keeps it lit instead of fading it. Real keys and clicks (QtTest) on
// the real field and rail; the settings themselves are stand-ins, the real
// ones need DMS. Run with tests/qml/run.sh.
Item {
    id: h
    width: 550
    height: 600

    SettingsView {
        id: view
    }
    SearchField {
        id: search
        view: view
        width: 550
    }
    CategoryRail {
        id: rail
        view: view
        y: 60
    }
    // Two categories, each with a setting that carries its key like the real ones
    Item {
        x: 200
        y: 60
        width: 340
        height: 400
        CategoryPage {
            id: sounds
            view: view
            category: "sounds"
            Item {
                id: effects
                property string settingKey: "sounds"
                width: parent.width
                height: 30
                visible: sounds.shown("sounds")
            }
            Item {
                id: loudness
                property string settingKey: "soundVolume"
                width: parent.width
                height: 30
                visible: sounds.shown("soundVolume")
            }
        }
        CategoryPage {
            id: look
            view: view
            category: "look"
            Item {
                property string settingKey: "shootingStars"
                width: parent.width
                height: 30
                visible: look.shown("shootingStars")
            }
        }
    }
    // A second view, made once a widget is placed: it opens on the Orbit settings
    Loader {
        id: later
        active: false
        sourceComponent: SettingsView {}
    }
    TestCase {
        id: input
        name: "settingsView"
        when: false
    }

    Tally {
        id: tally
    }
    // The rail entry of a category
    function entryOf(id) {
        return rail.children[1].children.find(c => c.modelData && c.modelData.id === id);
    }
    // The lit frame of a page: it sits inside the setting it frames, the only
    // bordered item behind its controls
    function frameOf(item) {
        for (const child of item.children) {
            if (child.border && child.z === -1)
                return child;
            const inside = frameOf(child);
            if (inside)
                return inside;
        }
        return null;
    }

    readonly property var steps: [
        {
            "then": 50,
            "run": () => {
                SettingsData.reduceMotion = false;
                // Nine since the Pop-up category left with Orbit's OSD (0c73f6a), ten with Getting started
                tally.check("ten categories on the rail", rail.view.categories.length, 10);
                tally.check("no Orbit widget placed: Getting started is open", [view.current, h.entryOf("start").on], ["start", true]);
                tally.check("no page of another category shows", [sounds.visible, look.visible], [false, false]);
                tally.check("narrow? no: the rail is 172 px", rail.width, 172);
                input.mouseClick(h.entryOf("sounds"), 80, 20);
            }
        },
        {
            "then": 50,
            "run": () => {
                tally.check("a click on a category opens it, and only it", [view.current, sounds.visible, look.visible], ["sounds", true, false]);
                tally.check("it is the planet in focus now", [h.entryOf("sounds").on, h.entryOf("orbit").on], [true, false]);
                input.mouseClick(search, 100, 20);
                input.keyClick("s");
                input.keyClick("n");
                input.keyClick("a");
                input.keyClick("p");
            }
        },
        {
            "then": 150,
            "run": () => {
                tally.check("typing sets the query", view.query, "snap");
                tally.check("the page is a filter now", [view.filtering, view.hasResults], [true, true]);
                tally.check("the sounds page shows its match and hides the other setting", [sounds.visible, effects.visible, loudness.visible], [true, true, false]);
                tally.check("the page with no match is gone", look.visible, false);
                tally.check("the rail counts per category", [h.entryOf("sounds").badge > 0, h.entryOf("look").badge], [true, 0]);
                tally.check("no planet while filtering, no match fades", [h.entryOf("sounds").on, h.entryOf("look").dim], [false, true]);
                input.keyClick(Qt.Key_Escape);
            }
        },
        {
            "then": 150,
            "run": () => {
                tally.check("Esc clears the text and gives the page back", [view.query, view.filtering, view.current], ["", false, "sounds"]);
                tally.check("and the settings all show again", [sounds.visible, look.visible, effects.visible, loudness.visible], [true, false, true, true]);
                input.keyClick("x");
                input.keyClick("y");
                input.keyClick("z");
                input.keyClick("z");
                input.keyClick("y");
            }
        },
        {
            "then": 100,
            "run": () => {
                tally.check("a query with no match: nothing shows, rail stays", [view.filtering, view.hasResults, sounds.visible, look.visible], [true, false, false, false]);
                input.keyClick(Qt.Key_Escape);
                input.keyClick("s");
                input.keyClick("n");
                input.keyClick("a");
                input.keyClick("p");
                input.keyClick(Qt.Key_Return);
            }
        },
        {
            "then": 900,
            "run": () => {
                tally.check("Enter opens the best match's category and leaves the search", [view.query, view.current, view.litKey], ["", "sounds", view.litKey]);
                tally.check("the match is lit at once", h.frameOf(sounds).opacity, 1);
            }
        },
        {
            "then": 900,
            "run": () => {
                tally.check("the light fades once, after 300 ms of holding, and is gone", h.frameOf(sounds).opacity, 0);
                SettingsData.reduceMotion = true;
                view.open("sounds", "soundVolume");
            }
        },
        {
            "then": 900,
            "run": () => {
                tally.check("Reduce motion: it stays lit, no fade", h.frameOf(sounds).opacity, 1);
                input.mouseClick(sounds, 10, 10);
            }
        },
        {
            "then": 100,
            "run": () => {
                tally.check("a click on the page puts it out", h.frameOf(sounds).opacity, 0);
                SettingsData.reduceMotion = false;
                input.mouseClick(search, 100, 20);
                for (const c of "star")
                    input.keyClick(c);
            }
        },
        {
            "then": 150,
            "run": () => {
                tally.check("'star' matches the shooting stars", [view.hits.shootingStars, view.counts.look >= 1], [true, true]);
                input.mouseClick(h.entryOf("look"), 80, 20);
            }
        },
        {
            "then": 100,
            "run": () => {
                tally.check("a click on a category with a match opens it at its best match", [view.query, view.current, view.litKey], ["", "look", "shootingStars"]);
                SettingsData.controlCenterWidgets = [{ "id": "plugin_orbitBluetooth", "enabled": true }];
                later.active = true;
            }
        },
        {
            "then": 50,
            "run": () => {
                tally.check("the view knows where Orbit is placed", [view.placed.cc, view.placed.bar, view.placed.any], [true, false, true]);
                tally.check("Orbit in the Control Center: the settings open on Orbit", later.item.current, "orbit");
                tally.check("a widget added while the page is open does not move it", view.current, "look");
                SettingsData.controlCenterWidgets = [];
                later.active = false;
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
            tally.finish();
            return;
        }
        const s = steps[step++];
        s.run();
        clock.interval = s.then;
        clock.start();
    }
    Component.onCompleted: Qt.callLater(next)
}
