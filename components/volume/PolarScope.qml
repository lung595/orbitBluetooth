import QtQuick
import qs.Common
import "Members.js" as Members
import "Polar.js" as Polar

// The volumes as a polar vectorscope (D250): the outer half circle is the
// device's own level (Theme.primary), the inner one this PC's level
// (Theme.tertiary, turned away when the two look alike: Palette.apart).
// Each lights up from the left to its level, with a moon to drag; an icon
// sits at the foot of each, the number only shows while the level moves. A
// cloud of points shows where the sound is going: its angle is left/right,
// its distance how loud.
// Listening together (D254, D277, `members`): the outer half is cut into one
// arc per output, two to four, in the order they joined, left to right. Each
// is lit from the end farthest from the top and grows toward it, in its own
// color; this PC's inner half stays one, shared. The cloud follows: each
// arc's sector of it in that output's color, as big as that output is heard.
// The sound is a ScopeModel (computed once for every screen) painted by
// PolarVisual, over an optional Ozone-like grid (PolarGrid); the icons and
// numbers are PolarReadouts; the arcs are PolarArcs, the moons PolarMoons and
// the gestures PolarGestures. This file keeps the geometry, eases the
// levels and holds the picture. The levels ease on one Timer that runs only
// while they move: a QML animation would redraw the whole shell (rule 23).
// Reduce motion: no picture, levels jump.
Item {
    id: scope

    // -1: the device has no level of its own, the outer half is not drawn
    property real deviceLevel: -1
    property real pcLevel: 0
    property bool deviceMuted: false
    property bool pcMuted: false
    // The outputs sharing the sound, two to four, in the order they joined
    // (each { level, muted, icon, label }, the level 0..1) with the color of
    // each: the device's fields above are then not shown
    property var members: []
    property var memberColors: []
    readonly property bool split: members.length >= 2
    property string deviceIcon: "headphones"
    property string pcIcon: "computer"
    // On screen and wanted to move (the caller knows: popup shown, card open)
    property bool live: false
    property bool motion: true
    property int fps: 60
    property bool interactive: true
    // "points", "rays", "waves" or "none" (Polar.styleOf)
    property string style: "points"
    // The scope's own screen behind it: guide rings and L / R lines
    property bool grid: false
    // Light added on a dark screen; plain paint on a light one
    property bool additive: true

    // A level was dragged or scrolled: "device" (the device's own), "m0" to
    // "m3" (an output listening together) or "pc", 0..1
    signal moved(string part, real level)
    // Its icon was clicked: a part, as above
    signal muteClicked(string part)
    // With smartWheel, a wheel notch asks the caller for a step instead
    // (the caller's smart steps, D264): +1 up, -1 down
    property bool smartWheel: false
    signal stepped(string part, int dir)
    // The percentages always show (D264): beside the half circles when
    // there is room, else next to the moons
    property bool numbers: false
    property string deviceLabel: "Device"
    property string pcLabel: "This PC"
    readonly property real sideRoom: width / 2 - outer - 12
    // Beside the half circles there is room for two numbers, no more: with
    // three or four outputs they stay by their moons
    readonly property bool sideNumbers: numbers && sideRoom >= 64 && members.length <= 2
    readonly property bool hovered: pointer.containsMouse || dragging !== ""

    // The arcs of the outer half, left to right: one per output listening
    // together, else the device's own, else none. Delegates count them
    // (outputs.length) and read their own by index (output(i)), which
    // answers for an index that is just gone
    readonly property var outputs: split ? members.slice(0, Polar.MAX_MEMBERS).map((m, i) => ({
                "part": Polar.partOf(i, Math.min(members.length, Polar.MAX_MEMBERS)),
                "level": m.level,
                "muted": m.muted,
                "icon": m.icon,
                "label": m.label,
                "color": memberColors[i] || deviceColor
            })) : deviceLevel >= 0 ? [
        {
            "part": "device",
            "level": deviceLevel,
            "muted": deviceMuted,
            "icon": deviceIcon,
            "label": deviceLabel,
            "color": deviceColor
        }
    ] : []
    readonly property var slices: Polar.slices(Math.max(1, outputs.length))
    // This PC's half circle is always whole
    readonly property var innerSlice: Polar.slices(1)[0]
    readonly property var _none: ({
            "part": "",
            "level": 0,
            "muted": false,
            "icon": "speaker",
            "label": "",
            "color": deviceColor
        })
    function output(i) {
        return outputs[i] || _none;
    }
    function sliceOf(i) {
        return slices[Math.min(i, slices.length - 1)];
    }
    // The level a part has now (not the eased one), for the wheel's steps
    function levelOf(part) {
        return part === "pc" ? pcLevel : output(Polar.indexOf(part)).level;
    }
    readonly property bool hasDevice: outputs.length > 0
    // Geometry: the center sits on the bottom edge, above the icons
    readonly property real iconSize: Math.max(14, Math.round(outer * 0.12))
    readonly property real cx: width / 2
    readonly property real cy: height - iconSize - 10
    // When the percentages show, the half circles give up to a quarter of
    // their size if that leaves room for them on both sides (the detail
    // card); otherwise they keep their size and the numbers sit by the moons
    // With more than two outputs the legend (PolarLegend) needs a line above the
    // top of the arcs, for the one that sits there
    readonly property real _legendRoom: outputs.length > 2 ? 16 : 0
    readonly property real _fit: Math.min(width / 2 - 14, height - 34 - _legendRoom)
    readonly property real _besideNumbers: width / 2 - 76
    readonly property real outer: Math.max(10, numbers && _besideNumbers >= _fit * 0.75 ? Math.min(_fit, _besideNumbers) : _fit)
    // Alone (an output with no level of its own), this PC's half takes the room
    readonly property real inner: hasDevice ? outer * 0.44 : outer * 0.82
    // Thin and quiet (D263): a hairline track, a fine lit arc
    readonly property real stroke: Math.max(1.75, outer * 0.016)

    // The caller may pass night colors when the scope sits on a dark screen
    property color deviceColor: Theme.primary
    property color pcColor: Theme.tertiary
    property color trackColor: Theme.withAlpha(Theme.outline, 0.22)
    property color inkColor: Theme.surfaceText
    property color mutedColor: Theme.outline
    // Inside a muted moon
    property color hollowColor: Theme.surfaceContainer

    // Which number shows, and for how long
    property string talking: ""
    function talk(part) {
        talking = part;
        quiet.restart();
    }
    Timer {
        id: quiet
        interval: 1400
        onTriggered: scope.talking = ""
    }

    // --- Grid and picture ---------------------------------------------------------
    PolarGrid {
        anchors.fill: parent
        scope: scope
    }

    PolarVisual {
        id: cloud
        anchors.fill: parent
        visible: !!scope._picture && scope.live && scope.motion && scope._picture.style !== "none"
        model: scope._picture
        centerX: scope.cx
        centerY: scope.cy
        radius: scope.outer - scope.stroke
        sectors: scope._sectors
        color2: scope.pcColor
        additive: scope.additive
    }

    // A faint baseline, as on a goniometer
    Rectangle {
        x: scope.cx - scope.outer - 6
        y: scope.cy
        width: (scope.outer + 6) * 2
        height: 1
        color: scope.trackColor
    }

    PolarArcs {
        scope: scope
    }

    // Shown levels: follow the real ones on a short ease, straight while
    // dragging. Eased on the scope's own clock, not a Behavior: a QML
    // animation would redraw the whole shell at the screen's rate on every
    // volume step (rule 23)
    property string dragging: ""
    property var _shown: []
    property real _pc: 0
    // The eased levels, for the readouts (PolarReadouts) to sit where the
    // arcs end without reaching into the easing state
    readonly property real shownPc: _pc
    function shownAt(i) {
        return i < _shown.length ? _shown[i] : 0;
    }
    function _targets() {
        return outputs.map(o => o.level);
    }
    // A function, not a binding: read inside the level's own change
    // handler, a binding would still hold the old answer
    function _settled() {
        return Members.settled(_shown, _targets(), 0.002) && Math.abs(_pc - pcLevel) < 0.002;
    }
    function _snap() {
        clock.stop();
        _shown = _targets();
        _pc = pcLevel;
    }
    function _follow() {
        // An output joined or left: the arcs are not the same, nothing glides
        if (!_ready || !motion || !live || dragging !== "" || _shown.length !== outputs.length)
            _snap();
        else if (!_settled() && !clock.running) {
            _last = Date.now();
            clock.start();
        }
    }
    // The first levels are shown as they are, nothing eases in
    property bool _ready: false
    Component.onCompleted: {
        _ready = true;
        _snap();
    }
    onOutputsChanged: _follow()
    onPcLevelChanged: _follow()
    onDraggingChanged: _follow()

    // The cloud's sectors, one per arc: the color, how big next to the
    // loudest, whether it is muted (Members.sectors)
    readonly property var _heard: outputs.map((o, i) => Polar.heardLevel(shownAt(i), _pc, o.muted, pcMuted))
    readonly property var _sectors: Members.sectors(outputs, _heard, pcColor, pcMuted)

    // The sound to show: a ScopeModel shared by every screen (the caller's),
    // or the scope's own one, fed by hand (previews, tests)
    property var picture: null
    readonly property var _picture: picture || ownPicture.item
    Loader {
        id: ownPicture
        active: !scope.picture
        sourceComponent: ScopeModel {
            style: Polar.styleOf(scope.style)
            fps: scope.fps
            gain: scope._heard.length ? Math.max(...scope._heard) : Polar.heardLevel(-1, scope._pc, false, scope.pcMuted)
        }
    }

    // Exposed for tests: the clocks must stop alone
    readonly property bool animating: clock.running || (!!_picture && _picture.animating)
    property double _last: 0
    Timer {
        id: clock
        interval: Math.round(1000 / Math.max(10, scope.fps))
        repeat: true
        onTriggered: {
            const now = Date.now();
            const dt = Math.max(0.001, Math.min(0.1, (now - scope._last) / 1000));
            scope._last = now;
            scope._shown = Members.easeAll(scope._shown, scope._targets(), dt, 16);
            scope._pc = Polar.ease(scope._pc, scope.pcLevel, dt, 16);
            if (scope._settled())
                scope._snap();
        }
    }
    // Fills the picture from a made-up frame, for previews and tests
    function simulate(frame, seconds) {
        _picture.simulate(frame, seconds);
    }
    onLiveChanged: if (!live)
        _follow()

    // --- Moons, readouts, then the gestures ---------------------------------------
    PolarMoons {
        scope: scope
    }

    PolarReadouts {
        anchors.fill: parent
        scope: scope
    }

    // --- Gestures -------------------------------------------------------------------
    property alias pointer: pointer
    PolarGestures {
        id: pointer
        scope: scope
    }
}
