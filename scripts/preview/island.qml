import QtQuick
import QtQuick.Window
import "../../components/volume"

// Offscreen bench of Orbit's own share of a volume key step in the Dank
// Island (NAK-36): Orbit's face in a stand-in island sheet, the levels moved
// and the face opened by the scene, as VolumeOverlay does on a key. DMS's own
// island (its spring, its windows) is not here: what this measures is what
// Orbit adds. Never grabs, never quits: it runs until the bench stops it.
// Made-up levels only.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports island.qml -- <mode> /dev/null
// Modes: rest (the island folded, the face idle), step (one key step every
//        4 s: the face opens, follows the level, folds back 3 s later),
//        burst (a run of 8 steps 150 ms apart every 4 s), burstgroup /
//        burstmember (the same run with three outputs listening together,
//        one member's level moving; burstmember lights it as the keys'
//        target, NAK-9)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]

    width: 460
    height: 176
    visible: true
    color: "#101114"

    // What DMS's IslandController does that the face uses
    QtObject {
        id: island
        property string activeActivity: "home"
        property bool expanded: false
        property bool inputSuspended: false
        property bool pointerInside: false
        function requestSystemActivity(id) {
            activeActivity = id;
            return true;
        }
        function requestCollapse() {
            expanded = false;
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
        id: overlay
        property string style: "points"
        property real deviceLevel: 0.5
        property real pcLevel: 0.85
        property bool deviceMuted: false
        property bool pcMuted: false
        property string deviceIcon: "headphones"
        property string pcIcon: "computer"
        property var members: []
        property var picture: null
        property bool reduceMotion: false
        property int fps: 30
        property var note: null
        property alias unfolded: visit.unfolded
        property UnfoldedVisit visit: UnfoldedVisit {
            id: visit
        }
        function scopeShown(on) {
            visit.screenShown(on);
        }
        property string factsLine: "Bluetooth · LDAC · 96 kHz"
        property var factsRows: []
        function islandShown(face, on) {
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
        id: host
        property var data: []
    }
    // The island's volume sheet, holding DMS's own slider
    Item {
        id: sheet
        anchors.fill: parent
        property Item item: Item {}
        IslandFace {
            id: face
            overlay: overlay
            controller: island
            host: host
        }
    }

    // Outputs listening together: made-up members, the second one moved by
    // the keys (and lit as their target in burstmember)
    readonly property bool together: mode === "burstgroup" || mode === "burstmember"
    property real _level: 0.5
    function members() {
        const m = (i, level, icon, label) => ({
                    "part": "m" + i,
                    "address": "02:00:00:00:00:0" + i,
                    "level": level,
                    "muted": false,
                    "icon": icon,
                    "label": label,
                    "target": i === 1 && mode === "burstmember"
                });
        return [m(0, 0.7, "headphones", "Studio headphones"), m(1, _level, "speaker", "Desk speaker"), m(2, 0.3, "earbuds", "Earbuds")];
    }
    Component.onCompleted: if (together)
        overlay.members = members()

    // One key step: the level moves 5 %, up then down, and the face opens
    property int _dir: 1
    function step() {
        let l = _level + 0.05 * _dir;
        if (l > 0.9 || l < 0.1) {
            _dir = -_dir;
            l = _level + 0.05 * _dir;
        }
        _level = l;
        if (together)
            overlay.members = members();
        else
            overlay.deviceLevel = l;
        face.open();
    }
    property int _left: 0
    Timer {
        interval: 4000
        repeat: true
        triggeredOnStart: true
        running: win.mode === "step" || win.mode.startsWith("burst")
        onTriggered: {
            win._left = win.mode.startsWith("burst") ? 8 : 1;
            run.start();
        }
    }
    Timer {
        id: run
        interval: 150
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            win.step();
            if (--win._left <= 0)
                stop();
        }
    }
}
