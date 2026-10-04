import QtQuick
import "components/volume"

// Test of IslandFace against a stand-in for DMS's island controller: the
// island folds by itself while our sheet is up (a screenshot suspends it and
// folds it without a word) and is sent home at once instead of being left on
// its compact volume face (P148); a folded island that is not ours is left
// alone; the facts unfold only for the visit they were asked in. Run with
// tests/qml/run.sh.
Item {
    id: h
    width: 460
    height: 176

    // What DMS's IslandController does that matters here: asking for the
    // system activity sets it and starts a timer that gives up when the
    // island is expanded (so it never comes back), a screenshot folds the
    // island straight away with the activity left as it was, and
    // requestCollapse() finishes the transient
    QtObject {
        id: island
        property string activeActivity: "home"
        property bool expanded: false
        property bool inputSuspended: false
        property bool pointerInside: false
        // A notification showing: asking for the volume folds it first
        property bool foldOnRequest: false
        function requestSystemActivity(id) {
            if (foldOnRequest) {
                expanded = false;
                foldOnRequest = false;
            }
            activeActivity = id;
            return true;
        }
        function requestCollapse() {
            expanded = false;
            if (activeActivity === "volume")
                activeActivity = "home";
            return true;
        }
        function expandedTargetFor(id) {
            return {
                "topLeftRadius": 4,
                "topRightRadius": 4,
                "bottomLeftRadius": 24,
                "bottomRightRadius": 24
            };
        }
    }
    // What VolumeOverlay gives the face
    QtObject {
        id: fakeOverlay
        property string style: "points"
        property real deviceLevel: 0.62
        property real pcLevel: 0.85
        property bool deviceMuted: false
        property bool pcMuted: false
        property string deviceIcon: "speaker"
        property string pcIcon: "computer"
        property var members: []
        property var picture: null
        property bool reduceMotion: false
        property int fps: 60
        property var note: null
        property string factsLine: "USB · 192 kHz · 32 bit"
        property var factsRows: [
            {
                "label": "Connection",
                "text": "USB"
            }
        ]
        property int shownCount: 0
        function islandShown(face, on) {
            shownCount += on ? 1 : -1;
        }
        function refreshFacts() {
        }
        function noteAction() {
        }
        function setLevel(part, level) {
        }
        function toggleMute(part) {
        }
    }
    QtObject {
        id: fakeHost
        property var data: []
    }
    // The island's volume sheet: a Loader-like parent holding DMS's own slider
    Item {
        id: sheet
        anchors.fill: parent
        property Item item: Item {
            id: nativeSlider
        }
    }
    // Made once the sheet holds its slider, as DMS's sheet does
    Component {
        id: faceMaker
        IslandFace {
            overlay: fakeOverlay
            controller: island
            host: fakeHost
        }
    }
    property var face: null

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function find(item, name) {
        if (item.objectName === name)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const hit = find(item.children[i], name);
            if (hit)
                return hit;
        }
        return null;
    }

    Component.onCompleted: {
        face = faceMaker.createObject(sheet);
        check("at rest the face is not shown", [face.shown, nativeSlider.visible], [false, true]);
        check("it opens the island on the volume", [face.open(), island.activeActivity, island.expanded], [true, "volume", true]);
        check("shown, with DMS's own slider hidden", [face.shown, nativeSlider.visible], [true, false]);

        // A screenshot folds the island behind our back
        island.inputSuspended = true;
        island.expanded = false;
        check("folded by DMS: the island is sent home, not left on its compact face", [island.activeActivity, face.shown], ["home", false]);
        island.inputSuspended = false;

        // The same through the timer-less path: closing a folded island
        check("it opens again", [face.open(), island.activeActivity, island.expanded], [true, "volume", true]);
        island.expanded = false;
        check("folded again: sent home again", island.activeActivity, "home");

        // Asking for the volume folds a showing notification first: that
        // is not the island leaving us
        island.foldOnRequest = true;
        check("opened over a notification", [face.open(), island.activeActivity, island.expanded], [true, "volume", true]);
        island.foldOnRequest = true;
        check("again, the fold made by the request is not taken for a leave", [face.open(), island.activeActivity, island.expanded], [true, "volume", true]);

        // The island showing its own compact volume (DMS's OSD switched back
        // on) is not ours to send home when it folds
        face.close();
        island.activeActivity = "volume";
        island.expanded = true;
        island.expanded = false;
        check("an island we did not open is left alone", island.activeActivity, "volume");
        island.activeActivity = "home";

        // The facts open folded, every time
        const facts = find(face, "factsLine");
        check("the facts line is there", facts !== null, true);
        face.open();
        facts.expanded = true;
        face.close();
        check("closed: the facts fold", facts.expanded, false);
        face.open();
        check("opened again: still folded", facts.expanded, false);
        face.close();

        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
