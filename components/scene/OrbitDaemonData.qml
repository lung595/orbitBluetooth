import QtQuick
import qs.Services

// What the daemon publishes for the scene (connection times, battery logs,
// power readings, real device pictures) and the clock that keeps the
// elapsed times fresh. The scene hands these to the bodies and the cards
// through its own functions.
Item {
    id: daemon
    required property var scene

    readonly property var globals: PluginService.globalVars[scene.prefs.pluginId] || ({})
    readonly property var _pictureService: PluginService.pluginDaemonInstances[scene.prefs.pluginId]?.pictureLookup ?? null
    property double now: Date.now()

    function sinceFor(address) {
        const s = globals.since || {};
        return address && s[address] ? s[address] : 0;
    }
    function batteryLogFor(address) {
        const l = globals.batteryLog || {};
        return address ? (l[address] || []) : [];
    }
    function powerFor(address) {
        const p = globals.power || {};
        return address ? (p[address] || null) : null;
    }
    // Opt-in (Real device pictures): the daemon does the lookups
    function pictureFor(model) {
        const p = globals.pictures || {};
        return scene.prefs.realPictures && model ? (p[model] || null) : null;
    }
    function requestPicture(query) {
        if (query)
            _pictureService?.request(query);
    }

    // Connection timers tick once per second, only while the scene is awake:
    // an idle desktop orbit stays frozen (zero frames) and catches up on wake.
    Timer {
        interval: 1000
        repeat: true
        running: daemon.scene.awake && daemon.scene.btOn && Object.keys(daemon.globals.since || {}).length > 0
        triggeredOnStart: true
        onTriggered: daemon.now = Date.now()
    }
    // Fresh clock on every daemon event (connection, battery sample), so the
    // charge estimates never use a stale time, even while the ticker sleeps.
    onGlobalsChanged: now = Date.now()
}
