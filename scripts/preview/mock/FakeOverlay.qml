import QtQuick

// What VolumeOverlay gives a ScopeScreen, made up: the device at 62 % with
// this PC at 85 %, or outputs listening together (`members`, each { part,
// level, muted, icon, label }) when there are two to four.
QtObject {
    property string style: "points"
    property real deviceLevel: 0.62
    property real pcLevel: 0.85
    property bool deviceMuted: false
    property bool pcMuted: false
    property string deviceIcon: "speaker"
    property string deviceName: "Desk speaker"
    property string pcIcon: "computer"
    property var members: []
    property var picture: null
    property bool reduceMotion: false
    property int fps: 60
    property var note: null
    property bool unfolded: false
    property string factsLine: "USB · 192 kHz · 32 bit"
    property var factsRows: [
        {
            "label": "Connection",
            "text": "USB"
        },
        {
            "label": "Sample rate",
            "text": "192 kHz"
        }
    ]
    function refreshFacts() {
    }
    function noteAction() {
    }
    function setLevel(part, level) {
    }
    function stepLevel(part, dir) {
    }
    function toggleMute(part) {
    }
}
