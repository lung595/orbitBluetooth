import QtQuick
import qs.Services
import "../noise/Anc.js" as Anc
import "Orbit.js" as Orbit

// The scene's side of noise control (the daemon runs the helper, see
// AncService): what a headset reports, whether it can be controlled, the
// requests to the helper, and the sessions kept with the connected
// headsets while this view is visible: the helper waits on the socket, so
// plugging or unplugging the charger shows up at once without any polling.
// Closing the view ends them.
Item {
    id: anc
    required property var scene
    // The device bodies, to find the headsets
    required property Repeater bodies

    readonly property var service: PluginService.pluginDaemonInstances[scene.prefs.pluginId]?.anc ?? null
    property var _viewing: []

    function infoFor(address) {
        const a = scene.globals.anc || {};
        return address ? (a[address] || null) : null;
    }
    function capable(body) {
        return scene.prefs.ancEnabled && !!body && body.connected && body.paired && Anc.family(body.model) !== "";
    }
    function send(address, key, value) {
        service?.send(address, key, value);
    }
    function watch(address, on) {
        service?.watch(address, on);
    }

    function syncViews() {
        const want = [];
        if (scene.active) {
            for (let i = 0; i < bodies.count; i++) {
                const b = bodies.itemAt(i);
                if (b && b.ancCapable)
                    want.push(b.address);
            }
        }
        const c = Orbit.changes(_viewing, want);
        if (!c.added.length && !c.removed.length)
            return;
        c.added.forEach(a => watch(a, true));
        c.removed.forEach(a => watch(a, false));
        _viewing = want;
    }
    // Ends every session (the scene goes)
    function endViews() {
        _viewing.forEach(a => watch(a, false));
    }
}
