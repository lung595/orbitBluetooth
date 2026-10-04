import QtQuick
import qs.Common
import "Polar.js" as Polar

// The two volumes as a polar vectorscope (D250): the outer half circle is
// the device's own level (Theme.primary), the inner one this PC's level
// (Theme.tertiary, turned away when the two look alike: Palette.apart).
// Each lights up from the left to its level, with a moon to drag; an icon
// sits at the foot of each, the number only shows while
// the level moves. A cloud of points shows where the sound is going: its
// angle is left/right, its distance how loud.
// Listening together (D254, `split`): the outer half is cut at the top into
// two quarters, one per output, each lit from its bottom corner toward the
// top (the first at the left, the second at the right); this PC's inner half
// stays one, shared. The clouds follow: left half in the first one's color,
// right half in the second's.
// The sound is a ScopeModel (computed once for every screen) painted by
// PolarVisual, over an optional Ozone-like grid (PolarGrid); the icons and
// numbers are PolarReadouts; the arcs are PolarArcs, the moons PolarMoons and
// the gestures PolarGestures. This file keeps the geometry, eases the
// levels and holds the picture. The levels ease on one
// Timer that runs only while they move: a QML animation would redraw the
// whole shell (rule 23). Reduce motion: no picture, levels jump.
Item {
    id: scope

    // -1: the device has no level of its own, the outer half is not drawn
    property real deviceLevel: -1
    property real pcLevel: 0
    property bool deviceMuted: false
    property bool pcMuted: false
    // Two outputs share the sound: the second one's own level (the device's
    // fields are then the first one's)
    property bool split: false
    property real secondLevel: 0
    property bool secondMuted: false
    property string secondIcon: "speaker"
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

    // A level was dragged or scrolled: "device", "second" or "pc", 0..1
    signal moved(string part, real level)
    // Its icon was clicked: "device", "second" or "pc"
    signal muteClicked(string part)
    // With smartWheel, a wheel notch asks the caller for a step instead
    // (the caller's smart steps, D264): +1 up, -1 down
    property bool smartWheel: false
    signal stepped(string part, int dir)
    // The percentages always show (D264): beside the half circles when
    // there is room, else next to the moons
    property bool numbers: false
    property string deviceLabel: "Device"
    property string secondLabel: "Device"
    property string pcLabel: "This PC"
    readonly property real sideRoom: width / 2 - outer - 12
    readonly property bool sideNumbers: numbers && sideRoom >= 64
    readonly property bool hovered: pointer.containsMouse || dragging !== ""

    readonly property bool hasDevice: split || deviceLevel >= 0
    // Geometry: the center sits on the bottom edge, above the icons
    readonly property real iconSize: Math.max(14, Math.round(outer * 0.12))
    readonly property real cx: width / 2
    readonly property real cy: height - iconSize - 10
    // When the percentages show, the half circles give up to a quarter of
    // their size if that leaves room for them on both sides (the detail
    // card); otherwise they keep their size and the numbers sit by the moons
    readonly property real _fit: Math.min(width / 2 - 14, height - 34)
    readonly property real _besideNumbers: width / 2 - 76
    readonly property real outer: Math.max(10, numbers && _besideNumbers >= _fit * 0.75 ? Math.min(_fit, _besideNumbers) : _fit)
    // Alone (an output with no level of its own), this PC's half takes the room
    readonly property real inner: hasDevice ? outer * 0.44 : outer * 0.82
    // Thin and quiet (D263): a hairline track, a fine lit arc
    readonly property real stroke: Math.max(1.75, outer * 0.016)

    // The caller may pass night colors when the scope sits on a dark screen
    property color deviceColor: Theme.primary
    property color secondColor: Theme.secondary
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
        color: scope.hasDevice ? scope.deviceColor : scope.pcColor
        color2: scope.pcColor
        colorRight: scope.split ? scope.secondColor : color
        quiet: scope.split ? scope.pcMuted || (scope.deviceMuted && scope.secondMuted) : scope.hasDevice ? scope.deviceMuted || scope.pcMuted : scope.pcMuted
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
    property real _dev: 0
    property real _pc: 0
    property real _second: 0
    // The eased levels, for the readouts (PolarReadouts) to sit where the
    // arcs end without reaching into the easing state
    readonly property real shownDevice: _dev
    readonly property real shownPc: _pc
    readonly property real shownSecond: _second
    // A function, not a binding: read inside the level's own change
    // handler, a binding would still hold the old answer
    function _settled() {
        return Math.abs(_dev - Math.max(0, deviceLevel)) < 0.002 && Math.abs(_pc - pcLevel) < 0.002 && Math.abs(_second - secondLevel) < 0.002;
    }
    function _snap() {
        clock.stop();
        _dev = Math.max(0, deviceLevel);
        _pc = pcLevel;
        _second = secondLevel;
    }
    function _follow() {
        if (!_ready || !motion || !live || dragging !== "")
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
    onDeviceLevelChanged: _follow()
    onPcLevelChanged: _follow()
    onSecondLevelChanged: _follow()
    onDraggingChanged: _follow()

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
            gain: scope.split ? Math.max(Polar.heardLevel(scope._dev, scope._pc, scope.deviceMuted, scope.pcMuted), Polar.heardLevel(scope._second, scope._pc, scope.secondMuted, scope.pcMuted)) : Polar.heardLevel(scope.hasDevice ? scope._dev : -1, scope._pc, scope.deviceMuted, scope.pcMuted)
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
            scope._dev = Polar.ease(scope._dev, Math.max(0, scope.deviceLevel), dt, 16);
            scope._pc = Polar.ease(scope._pc, scope.pcLevel, dt, 16);
            scope._second = Polar.ease(scope._second, scope.secondLevel, dt, 16);
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
