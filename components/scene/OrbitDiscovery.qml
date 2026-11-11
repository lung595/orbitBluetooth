import QtQuick

// Bluetooth discovery for one Orbit view: it only runs while the view is
// open and stops on its own after the scan time (prefs.scanSeconds).
Item {
    id: discovery
    required property var scene

    readonly property var adapter: discovery.scene.adapter
    property bool _ownsDiscovery: false

    function start() {
        if (!adapter || !discovery.scene.btOn)
            return;
        // A scan someone else started (DMS's panel) is theirs to stop
        if (!adapter.discovering) {
            _ownsDiscovery = true;
            adapter.discovering = true;
        }
        if (discovery.scene.prefs.scanSeconds > 0)
            scanStopTimer.restart();
    }

    function stop() {
        scanStopTimer.stop();
        if (adapter && _ownsDiscovery && adapter.discovering)
            adapter.discovering = false;
        _ownsDiscovery = false;
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
