import QtQuick

// Makes a Dank Island apply its size changes at once (no spring, no
// cross-fade between its activities) from hold() until `delay` after
// release(). The island's spring and fade are QML animations, and every
// running animation redraws the whole shell at the screen's rate: a few
// steps of volume in a row cost about 8 windows times 240 frames a second.
// While held, the full-screen layer DMS maps under an expanded island (to
// catch clicks outside it) is hidden too: the compositor would otherwise
// re-lay it out at every step.
// Both changes are made in memory only, on the island's own `reducedMotion`
// switch and on the layer's `visible`: once let go, or when this object goes
// with its face (plugin off), Qt gives DMS's own bindings back, with the
// user's Reduce Motion settings in them. Nothing of DMS is written (value
// 12, D259).
QtObject {
    id: snap

    // DMS's DankIslandSurface (null: nothing to do)
    required property var surface
    // DMS's full-screen click-away layer of that island (null: nothing to do)
    property var clickAway: null
    // How long the island keeps following at once after release(), so that
    // the way out is as cheap as the way in
    property int delay: 400
    readonly property bool held: _held

    function hold() {
        _held = true;
        letGo.stop();
    }
    function release() {
        letGo.restart();
    }

    property bool _held: false
    // A Binding deleted along with its owner gives nothing back (the island
    // would stay still for good), so it is let go of first
    Component.onDestruction: _held = false
    property Timer letGo: Timer {
        interval: snap.delay
        onTriggered: snap._held = false
    }
    property Binding unmapped: Binding {
        target: snap.clickAway
        property: "visible"
        value: false
        when: snap._held && snap.clickAway !== null
        // The layer's visibility may be a plain value as well as a binding
        restoreMode: Binding.RestoreBindingOrValue
    }
    property Binding motion: Binding {
        target: snap.surface
        property: "reducedMotion"
        value: true
        when: snap._held && snap.surface !== null
        restoreMode: Binding.RestoreBinding
    }
}
