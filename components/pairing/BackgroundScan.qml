import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.Services
import "../device/DeviceCatalog.js" as Catalog
import "Offer.js" as Offer

// The short background Bluetooth scan behind the "new device" pop-up. It is
// opt-in (P103) and only runs while it is cheap and harmless: Bluetooth on,
// screen awake, no Bluetooth audio playing (discovery makes it stutter),
// battery above the chosen level (Offer.scanBlocker). It listens to nothing
// else: scans started by someone else cost nothing and are left alone.
Item {
    id: scan

    required property var prefs
    // The pop-up's own switch ("Offer new devices" is only the card in the
    // Orbit view), plus the state the scan depends on
    required property bool offering
    required property bool btOn
    required property bool asleep
    property var adapter: null

    // Why the last background scan was skipped ("" when it ran), shown by the newDeviceStatus IPC call
    property string lastSkip: ""

    property bool _owns: false
    // Orbit views that are scanning: a background scan must not stop theirs
    property int _viewScans: 0

    function holdScan(on) {
        _viewScans = Math.max(0, _viewScans + (on ? 1 : -1));
        // A view took over: its own timer decides when discovery ends
        if (on)
            _owns = false;
    }

    function _audioConnected() {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected && Catalog.families[Catalog.resolve(list[i], ({}))] === "audio")
                return true;
        return false;
    }

    function scanOnce() {
        const display = UPower.displayDevice;
        const hasBattery = !!display && display.isLaptopBattery;
        lastSkip = Offer.scanBlocker({
            "enabled": offering && prefs.offerScan,
            "btOn": btOn && !!adapter,
            "asleep": asleep,
            "busy": !!adapter && adapter.discovering,
            "audioConnected": _audioConnected(),
            "onBattery": UPower.onBattery,
            "level": hasBattery ? Math.round(display.percentage * 100) : -1,
            "minLevel": prefs.offerMinBattery
        });
        if (lastSkip)
            return;
        adapter.discovering = true;
        _owns = true;
        scanStop.restart();
    }

    // Ends our own discovery, never a view's
    function stop() {
        scanStop.stop();
        if (_owns && _viewScans === 0 && adapter && adapter.discovering)
            adapter.discovering = false;
        _owns = false;
    }

    Timer {
        interval: Math.max(30, scan.prefs.offerEvery) * 1000
        repeat: true
        running: scan.offering && scan.prefs.offerScan && scan.btOn && !scan.asleep
        onTriggered: scan.scanOnce()
    }

    // Long enough for a headset in pairing mode to answer an inquiry
    Timer {
        id: scanStop
        interval: 8000
        onTriggered: scan.stop()
    }
}
