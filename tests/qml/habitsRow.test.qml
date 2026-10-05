import QtQuick
import qs.Services
import qs.Modules.Plugins
import "components/settings"

// Test of the "Learn my groups" settings row (D299): in a narrow page the
// description wraps onto several lines, and the row is as tall as that text, so
// it never spills over what sits above it (the wired delay slider) or under it
// (the line that counts the groups and the button that forgets them); it reads
// what is saved, shows how many groups are remembered, saves the switch, and
// forgets on demand; every part has its link to the guide. Run with
// tests/qml/run.sh.
Item {
    id: h

    PluginSettings {
        id: store
        // What the page would find already saved: learning off, two groups known
        stored: ({
                "learnHabits": false,
                "togetherHabits": ({
                        "0a0a0a0a,1b1b1b1b": ({
                                "n": 3,
                                "d": 20000
                            }),
                        "2c2c2c2c,3d3d3d3d": ({
                                "n": 1,
                                "d": 20001
                            })
                    })
            })
    }
    // A page about as wide as the settings column of a narrow window
    Item {
        id: page
        width: 328
        height: 600

        HabitsRow {
            id: row
            settings: store
        }
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
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
    readonly property var title: find(row, i => i.text === "Learn my groups")
    readonly property var description: find(row, i => typeof i.text === "string" && i.text.startsWith("The suggested group"))
    readonly property var toggle: find(row, i => i.checked !== undefined && i.toggled !== undefined)
    readonly property var forget: find(row, i => i.text === "Forget what Orbit learned")
    readonly property var count: find(row, i => typeof i.text === "string" && /remembered$/.test(i.text))
    readonly property var links: findAll(row, i => i.anchor !== undefined).map(i => i.anchor)
    function findAll(from, test) {
        let found = [];
        for (let i = 0; i < from.children.length; i++) {
            const item = from.children[i];
            if (test(item))
                found.push(item);
            found = found.concat(findAll(item, test));
        }
        return found;
    }
    // Where an item's top and bottom edges are, in the row's own coordinates
    function topOf(item) {
        return item.mapToItem(row, 0, 0).y;
    }
    function bottomOf(item) {
        return item.mapToItem(row, 0, item.height).y;
    }
    // What was saved, as [key, value] pairs
    function saved() {
        return store.saves;
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
        check("the parts are there", [title !== null, description !== null, toggle !== null, forget !== null, count !== null], [true, true, true, true, true]);

        // --- The layout: nothing spills over its neighbours ---------------------------------
        check("in a narrow page the description wraps onto several lines", description.lineCount > 2, true);
        check("the title is not above the row", topOf(title) >= 0, true);
        check("the description ends inside the row's first line of controls", bottomOf(description) <= topOf(count), true);
        check("the groups line and the button sit under the whole text", topOf(count) >= bottomOf(description) && topOf(forget) >= bottomOf(description), true);
        check("the whole row ends with the button", Math.abs(bottomOf(forget) - row.height) < 1, true);
        check("the switch is centred on the text", Math.abs((topOf(toggle) + bottomOf(toggle)) / 2 - (topOf(title) + bottomOf(description)) / 2) < 1, true);

        // --- What is saved ---------------------------------------------------------------------
        check("it reads what is saved: learning off, two groups", [row.learning, toggle.checked, row.remembered, count.text], [false, false, 2, "2 groups remembered"]);
        check("nothing is saved while it loads", saved(), []);
        check("each part has its link to the guide", row.children.length > 0 && links, ["learn-my-groups", "forget-what-orbit-learned"]);

        // --- The switch ------------------------------------------------------------------------
        toggle.toggled(true);
        check("the switch saves once, as it is now", [saved(), row.learning], [[["learnHabits", true]], true]);

        // --- Forgetting ------------------------------------------------------------------------
        forget.clicked();
        check("forgetting saves an empty memory", saved()[1], ["togetherHabits",
            {}
        ]);
        check("and the line that counted them goes", [row.remembered, count.visible && count.parent.visible], [0, false]);
        check("without touching the switch", [saved().length, row.learning], [2, true]);

        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
