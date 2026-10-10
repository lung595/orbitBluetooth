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
                id: tick
                property string settingKey: "volumeTick"
                width: parent.width
                height: 30
                visible: sounds.shown("volumeTick")
            }
            Item {
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
    TestCase {
        id: input
        name: "settingsView"
        when: false
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
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
                h.check("ten categories on the rail", rail.view.categories.length, 10);
                h.check("the first one is open", [view.current, h.entryOf("orbit").on], ["orbit", true]);
                h.check("no page of another category shows", [sounds.visible, look.visible], [false, false]);
                h.check("narrow? no: the rail is 160 px", rail.width, 160);
                input.mouseClick(h.entryOf("sounds"), 80, 20);
            }
        },
        {
            "then": 50,
            "run": () => {
                h.check("a click on a category opens it, and only it", [view.current, sounds.visible, look.visible], ["sounds", true, false]);
                h.check("it is the planet in focus now", [h.entryOf("sounds").on, h.entryOf("orbit").on], [true, false]);
                input.mouseClick(search, 100, 20);
                input.keyClick("t");
                input.keyClick("i");
                input.keyClick("c");
                input.keyClick("k");
            }
        },
        {
            "then": 150,
            "run": () => {
                h.check("typing sets the query", view.query, "tick");
                h.check("the page is a filter now", [view.filtering, view.hasResults], [true, true]);
                h.check("the sounds page shows its match and hides the other setting", [sounds.visible, tick.visible], [true, true]);
                h.check("the page with no match is gone", look.visible, false);
                h.check("the rail counts per category", [h.entryOf("sounds").badge > 0, h.entryOf("look").badge], [true, 0]);
                h.check("no planet while filtering, no match fades", [h.entryOf("sounds").on, h.entryOf("look").dim], [false, true]);
                input.keyClick(Qt.Key_Escape);
            }
        },
        {
            "then": 150,
            "run": () => {
                h.check("Esc clears the text and gives the page back", [view.query, view.filtering, view.current], ["", false, "sounds"]);
                h.check("and the settings all show again", [sounds.visible, look.visible, tick.visible], [true, false, true]);
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
                h.check("a query with no match: nothing shows, rail stays", [view.filtering, view.hasResults, sounds.visible, look.visible], [true, false, false, false]);
                input.keyClick(Qt.Key_Escape);
                input.keyClick("t");
                input.keyClick("i");
                input.keyClick("c");
                input.keyClick("k");
                input.keyClick(Qt.Key_Return);
            }
        },
        {
            "then": 900,
            "run": () => {
                h.check("Enter opens the best match's category and leaves the search", [view.query, view.current, view.litKey], ["", "sounds", view.litKey]);
                h.check("the match is lit at once", h.frameOf(sounds).opacity, 1);
            }
        },
        {
            "then": 900,
            "run": () => {
                h.check("the light fades once, after 300 ms of holding, and is gone", h.frameOf(sounds).opacity, 0);
                SettingsData.reduceMotion = true;
                view.open("sounds", "soundVolume");
            }
        },
        {
            "then": 900,
            "run": () => {
                h.check("Reduce motion: it stays lit, no fade", h.frameOf(sounds).opacity, 1);
                input.mouseClick(sounds, 10, 10);
            }
        },
        {
            "then": 100,
            "run": () => {
                h.check("a click on the page puts it out", h.frameOf(sounds).opacity, 0);
                SettingsData.reduceMotion = false;
                input.mouseClick(search, 100, 20);
                for (const c of "star")
                    input.keyClick(c);
            }
        },
        {
            "then": 150,
            "run": () => {
                h.check("'star' matches the shooting stars", [view.hits.shootingStars, view.counts.look >= 1], [true, true]);
                input.mouseClick(h.entryOf("look"), 80, 20);
            }
        },
        {
            "then": 100,
            "run": () => {
                h.check("a click on a category with a match opens it at its best match", [view.query, view.current, view.litKey], ["", "look", "shootingStars"]);
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
        s.run();
        clock.interval = s.then;
        clock.start();
    }
    Component.onCompleted: Qt.callLater(next)
}
