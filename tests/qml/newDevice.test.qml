import QtQuick
import Quickshell.Bluetooth
import Quickshell.Wayland
import qs.Services
import Quickshell.Services.UPower

// Scenario test of NewDeviceWatch: devices appear, are offered, connected,
// snoozed, ignored, held during full screen; the background scan obeys the
// audio and battery rules. One step every 600 ms. Run with tests/qml/run.sh.
Item {
    id: h
    QtObject {
        id: prefs
        property bool offerNew: true
        property bool offerPopup: true
        property bool offerScan: true
        property int offerEvery: 60
        property int offerMinBattery: 30
        property bool realPictures: false
        property bool reduceMotion: false
        property var ignoredDevices: ({})
        function setIgnored(a, n, on) { const x = Object.assign({}, ignoredDevices); x[a] = n; ignoredDevices = x; }
    }
    Component { id: dev; Device {} }
    // AncService stand-in: records which headsets the sheet asked about
    QtObject {
        id: anc
        property var states: ({})
        property var watched: []
        property var sent: []
        function watch(a, on) { watched = watched.concat([a + (on ? "+" : "-")]); }
        function send(a, k, v) { sent = sent.concat([a + " " + k + " " + v]); }
    }
    NewDeviceWatch { id: w; prefs: prefs; anc: anc }

    property int failures: 0
    property int calls: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok) failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function add(addr, name, icon, extra) {
        const d = dev.createObject(h, Object.assign({ address: addr, name: name, deviceName: name, icon: icon }, extra || {}));
        const a = Bluetooth.list.slice(); a.push(d);
        Bluetooth.list = a; Bluetooth.devices = a;
        return d;
    }
    function remove(addr) {
        const a = Bluetooth.list.filter(d => d.address !== addr);
        Bluetooth.list = a; Bluetooth.devices = a;
    }
    property var steps: [
        () => { add("00:00:00:00:00:01", "Old Buds", "audio-headset"); },
        () => { check("cache at start is not offered", w.current, ""); },
        () => { BluetoothService.adapter.discovering = true; add("00:00:00:00:00:02", "Pixel 8", "phone"); add("00:00:00:00:00:03", "WH-1000XM6", "audio-headphones"); },
        () => { check("new headphones offered", w.current, "00:00:00:00:00:03"); check("shown", w.shown, true); check("phase", w.phase, "offer"); check("phone not queued", w._queue, []); },
        () => { remove("00:00:00:00:00:01"); add("00:00:00:00:00:01", "Old Buds", "audio-headset"); },
        () => { check("startup device still snoozed", w._queue, []); w.pendingName = "Office headset"; w.connect(); check("pairing", w.phase, "pairing"); },
        () => {},
        () => {
            check("done", w.phase, "done");
            check("calls", BluetoothService.log, ["pair WH-1000XM6", "connect WH-1000XM6"]);
            check("typed name becomes the alias", w.device.name, "Office headset");
            check("asks the headset for its modes", anc.watched, ["00:00:00:00:00:03+"]);
            w.setMode("ambient");
            check("mode from the sheet", anc.sent, ["00:00:00:00:00:03 mode ambient"]);
            w.close();
            check("stops asking once closed", anc.watched, ["00:00:00:00:00:03+", "00:00:00:00:00:03-"]);
        },
        () => {},
        () => { check("closed", w.current, ""); BluetoothService.adapter.discovering = false; w.scanOnce(); check("audio connected blocks scan", w.lastSkip, "audio device connected"); },
        () => { Bluetooth.list.forEach(d => d.connected = false); w.scanOnce(); check("scan runs", w.lastSkip, ""); check("discovering", BluetoothService.adapter.discovering, true); },
        () => { add("00:00:00:00:00:04", "Galaxy Buds3", "audio-headset"); },
        () => { check("buds offered", w.current, "00:00:00:00:00:04"); w.later(); },
        () => {},
        () => { check("later closes", w.current, ""); remove("00:00:00:00:00:04"); add("00:00:00:00:00:04", "Galaxy Buds3", "audio-headset"); },
        () => { check("snoozed after later", w.current, ""); ToplevelManager.activeToplevel = { fullscreen: true, screens: ["s1"] }; add("00:00:00:00:00:05", "JBL Flip 6", "audio-speaker"); },
        () => { check("held during fullscreen", w.current, ""); check("queued", w._queue, ["00:00:00:00:00:05"]); ToplevelManager.activeToplevel = { fullscreen: false, screens: ["s1"] }; },
        () => { check("shown after fullscreen", w.current, "00:00:00:00:00:05"); check("screen of active window", w._screen, "s1"); w.ignore(); },
        () => {},
        () => { check("ignored saved", Object.keys(prefs.ignoredDevices), ["00:00:00:00:00:05"]); remove("00:00:00:00:00:05"); add("00:00:00:00:00:05", "JBL Flip 6", "audio-speaker"); },
        () => { check("ignored never offered", w.current, ""); BluetoothService.failPair = true; add("00:00:00:00:00:06", "Sony WF-1000XM5", "audio-headset"); },
        () => { w.connect(); },
        () => { check("pair failure", w.phase, "failed"); BluetoothService.adapter.discovering = false; UPower.onBattery = true; UPower.displayDevice = { isLaptopBattery: true, percentage: 0.2 }; w.scanOnce(); check("low battery blocks", w.lastSkip, "battery below 30%"); },
        () => { BluetoothService.failPair = false; w.later(); },
        // P115: a name is not a class, and a "headset" that can type is refused
        () => { BluetoothService.adapter.discovering = true; add("00:00:00:00:00:07", "AirPods Pro", ""); },
        () => { check("headset name without audio class not offered", w.current, ""); h.calls = BluetoothService.log.length; add("00:00:00:00:00:08", "Bose QC45", "audio-headset", { uuids: ["0000110b-0000-1000-8000-00805f9b34fb", "00001124-0000-1000-8000-00805f9b34fb"] }); },
        () => { check("fake headset offered", w.current, "00:00:00:00:00:08"); w.connect(); },
        () => {},
        () => {
            check("keyboard profile asks first", w.phase, "confirm");
            check("blocked while asking", w.device.blocked, true);
            check("never connected nor trusted", BluetoothService.log.slice(h.calls), ["pair Bose QC45"]);
            w.cancel();
            check("cancel forgets it", [w.device.forgotten, w.device.blocked, w.device.trusted], [true, false, false]);
        },
        () => {},
        // A real headset that sends its buttons as keys: "Pair anyway"
        () => { h.calls = BluetoothService.log.length; add("00:00:00:00:00:09", "Jabra Elite", "audio-headset", { uuids: ["00001124-0000-1000-8000-00805f9b34fb"] }); },
        () => { check("second headset offered", w.current, "00:00:00:00:00:09"); w.connect(); },
        () => {},
        () => { check("asks", w.phase, "confirm"); w.confirmInput(); check("unblocked", w.device.blocked, false); },
        () => {},
        () => { check("pair anyway connects", w.phase, "done"); check("calls", BluetoothService.log.slice(h.calls), ["pair Jabra Elite", "connect Jabra Elite"]); check("not forgotten", w.device.forgotten, false); w.close(); },
        () => {},
        () => { BluetoothService.adapter.discovering = false; },
        () => { h.calls = BluetoothService.log.length; check("demo starts", w.demo(), "OK"); check("demo device", w.device.name, "WH-1000XM6"); },
        () => { w.connect(); check("demo pairing", w.phase, "pairing"); },
        () => {},
        () => {},
        () => {},
        () => { check("demo done", w.phase, "done"); check("demo paired nothing", BluetoothService.log.length, h.calls); w.close(); },
        () => {},
        () => { check("demo over", [w.current, w._demo], ["", false]); },
        // P103: with the background scan off (the default), Orbit never scans
        // by itself, yet still offers what another tool's scan finds
        () => { prefs.offerScan = false; w.scanOnce(); check("no scan of its own", BluetoothService.adapter.discovering, false); check("says why", w.lastSkip !== "", true); },
        () => { BluetoothService.adapter.discovering = true; add("00:00:00:00:00:0A", "Momentum 4", "audio-headphones"); },
        () => { check("offered from another tool's scan", w.current, "00:00:00:00:00:0A"); w.later(); BluetoothService.adapter.discovering = false; },
        // The pop-up switch alone is enough: "Offer new devices" off (the
        // in-view card) must not hide it
        () => { check("previous pop-up gone", w.current, ""); },
        () => { prefs.offerNew = false; BluetoothService.adapter.discovering = true; add("00:00:00:00:00:0B", "WH-1000XM6", "audio-headset"); },
        () => { check("pop-up without Offer new devices", w.current, "00:00:00:00:00:0B"); w.close(); BluetoothService.adapter.discovering = false; },
        () => { print(h.failures ? h.failures + " failures" : "all passed"); Qt.exit(h.failures ? 1 : 0); }
    ]
    property int i: 0
    Timer {
        interval: 600; repeat: true; running: true
        // New devices only count once the start-up cache is primed
        onTriggered: { if (h.i === 2 && !w._primed) return; h.steps[h.i++](); }
    }
}
