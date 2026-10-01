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
        property int offerEvery: 60
        property int offerMinBattery: 30
        property bool realPictures: false
        property bool reduceMotion: false
        property var ignoredDevices: ({})
        function setIgnored(a, n, on) { const x = Object.assign({}, ignoredDevices); x[a] = n; ignoredDevices = x; }
    }
    Component { id: dev; Device {} }
    NewDeviceWatch { id: w; prefs: prefs }

    property int failures: 0
    property int calls: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok) failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function add(addr, name, icon, extra) {
        const d = dev.createObject(h, Object.assign({ address: addr, name: name, icon: icon }, extra || {}));
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
        () => { check("startup device still snoozed", w._queue, []); w.connect(); check("pairing", w.phase, "pairing"); },
        () => {},
        () => { check("done", w.phase, "done"); check("calls", BluetoothService.log, ["pair WH-1000XM6", "connect WH-1000XM6"]); w.close(); },
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
        () => { h.calls = BluetoothService.log.length; check("demo starts", w.demo(), "OK"); check("demo device", w.device.name, "WH-1000XM6"); },
        () => { w.connect(); check("demo pairing", w.phase, "pairing"); },
        () => {},
        () => {},
        () => {},
        () => { check("demo done", w.phase, "done"); check("demo paired nothing", BluetoothService.log.length, h.calls); w.close(); },
        () => {},
        () => { check("demo over", [w.current, w._demo], ["", false]); },
        () => { print(h.failures ? h.failures + " failures" : "all passed"); Qt.exit(h.failures ? 1 : 0); }
    ]
    property int i: 0
    Timer {
        interval: 600; repeat: true; running: true
        // New devices only count once the start-up cache is primed
        onTriggered: { if (h.i === 2 && !w._primed) return; h.steps[h.i++](); }
    }
}
