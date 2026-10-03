import QtQuick
import qs.Services

// Bluetooth discovery for one Orbit view: it only runs while the view is
// open and stops on its own after the scan time (prefs.scanSeconds).
Item {
    id: discovery
    required property var scene

    readonly property var adapter: discovery.scene.adapter
    property bool _ownsDiscovery: false
    // The daemon's background scan for the pop-up must not end a view's scan
    readonly property var _newDevices: PluginService.pluginDaemonInstances[discovery.scene.prefs.pluginId]?.newDevices ?? null
    property bool _holdingScan: false
    function _holdScan(on) {
        if (_holdingScan === on)
            return;
        _holdingScan = on;
        _newDevices?.holdScan(on);
    }

    function start() {
        if (!adapter || !discovery.scene.btOn)
            return;
        // Already running for the pop-up's background scan: take it over
        if (!adapter.discovering || _newDevices?._owns)
            _ownsDiscovery = true;
        if (!adapter.discovering)
            adapter.discovering = true;
        _holdScan(true);
        if (discovery.scene.prefs.scanSeconds > 0)
            scanStopTimer.restart();
    }

    function stop() {
        scanStopTimer.stop();
        if (adapter && _ownsDiscovery && adapter.discovering)
            adapter.discovering = false;
        _ownsDiscovery = false;
        _holdScan(false);
    }

    // With the autoScan preference off, only the center or the Scan chip start
    // discovery; a manual scan is still stopped when the view closes.
    function update() {
        const s = discovery.scene;
        if (s.active && s.btOn && s.autoScan && s.prefs.autoScan)
            start();
        else if (!s.active || !s.btOn || !s.autoScan)
            stop();
    }

    Timer {
        id: scanStopTimer
        interval: Math.max(5, discovery.scene.prefs.scanSeconds) * 1000
        onTriggered: discovery.stop()
    }
}
