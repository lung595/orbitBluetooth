import QtQuick

// Hides the full-screen layer DMS maps under an expanded Dank Island (it
// catches clicks outside the island, and lives as long as the island's host
// window) from hold() until `delay` after release(). While the island follows the volume keys, the compositor would
// otherwise re-lay that layer out at every step. The island's own motion is
// never touched: its spring and fades are DMS's, and the user's own settings
// decide them.
// The change is made in memory only, on the layer's `visible`: once let go,
// or when this object goes with its face (plugin off), Qt gives DMS's own
// binding back. Nothing of DMS is written (value 12, D259).
QtObject {
    id: mute

    // The island's host window (a DankIslandHostWindow) that carries the layer
    property var host: null
    // How long the layer stays hidden after release(), so that the way out
    // is as cheap as the way in
    property int delay: 400
    readonly property bool held: _held

    function hold() {
        if (_layer === null)
            _layer = _find();
        _held = true;
        letGo.stop();
    }
    function release() {
        letGo.restart();
    }

    property bool _held: false
    // The layer, found on the first hold() and not through a binding: the
    // host's `data` list is not bindable, so a binding on it never updates
    property var _layer: null
    // The layer is a window with a mask and an exclusive zone, which is how
    // it is told from the host's other children; null (nothing to hide, and
    // nothing breaks) if a DMS update changes that
    function _find() {
        const objects = host ? host.data : [];
        for (let i = 0; i < objects.length; i++) {
            const o = objects[i];
            if (typeof o.exclusiveZone === "number" && o.mask !== undefined && o.visible !== undefined)
                return o;
        }
        return null;
    }
    // A Binding deleted along with its owner gives nothing back (the layer
    // would stay hidden for good), so it is let go of first
    Component.onDestruction: _held = false
    property Timer letGo: Timer {
        interval: mute.delay
        onTriggered: mute._held = false
    }
    property Binding unmapped: Binding {
        target: mute._layer
        property: "visible"
        value: false
        when: mute._held && mute._layer !== null
        // The layer's visibility may be a plain value as well as a binding
        restoreMode: Binding.RestoreBindingOrValue
    }
}
