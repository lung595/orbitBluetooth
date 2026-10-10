import QtQuick
import Quickshell.Bluetooth
import "."

// Test of the launcher entry: a phrase that starts with an action word gives
// one entry, a refusal gives a plain entry that runs nothing, and the command
// an entry runs is the same address and minutes. Run with tests/qml/run.sh.
Item {
    id: h

    property int failures: 0
    function check(what, got, expected) {
        if (JSON.stringify(got) === JSON.stringify(expected))
            return;
        failures++;
        print("FAIL " + what + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(got));
    }

    Device {
        id: xm6
        address: "AA:BB:CC:DD:EE:01"
        name: "WH-1000XM6"
        connected: true
    }
    Device {
        id: pods
        address: "AA:BB:CC:DD:EE:02"
        name: "Pods Demo"
        connected: true
    }
    Device {
        id: pods2
        address: "AA:BB:CC:DD:EE:03"
        name: "Pods Two"
        connected: true
    }
    Device {
        id: dash
        address: "AA:BB:CC:DD:EE:09"
        name: "Kate \u2014 buds"
        connected: true
    }
    OrbitBluetoothLauncher {
        id: launcher
    }

    Component.onCompleted: {
        Bluetooth.list = Bluetooth.devices = [xm6, pods, pods2, dash];
        const items = launcher.getItems("dans 5 min deco xm6");
        check("one entry", items.length, 1);
        check("it says what it does", items[0].name, "Disconnect WH-1000XM6 in 5 min");
        check("the command", launcher.commandOf(items[0]), ["dms", "ipc", "call", "orbitBluetooth", "disconnectIn", xm6.address, "5"]);
        check("another word of the defaults", launcher.getItems("off xm6 30")[0].action, "disconnectIn:" + xm6.address + ":30");
        check("not a phrase of ours: nothing", [launcher.getItems("firefox"), launcher.getItems("")], [[], []]);
        const none = launcher.getItems("deco zzz 5");
        check("no long dash on screen", launcher.getItems("deco kate 5")[0].name, "Disconnect Kate - buds in 5 min");
        check("an unknown device is said, not silent", [none.length, none[0].name, launcher.commandOf(none[0])], [1, "No connected device matches that name", []]);
        check("an ambiguous one too", launcher.getItems("deco pods 5")[0].name, "Several connected devices match, type more of the name");
        check("a bad delay too", launcher.getItems("deco xm6 2000")[0].name, "Use a whole number of minutes, 1 to 1440");
        check("no delay", launcher.getItems("deco xm6")[0].name, "Add a delay in minutes, like 30");
        check("a forged action runs nothing", [launcher.commandOf({
                "action": "disconnectIn:--help:5"
            }), launcher.commandOf({
                "action": "disconnectIn:AA:BB:CC:DD:EE:01:5; ls"
            }), launcher.commandOf({
                "action": "disconnectIn:AA:BB:CC:DD:EE:01:99999"
            }), launcher.commandOf(null)], [[], [], [], []]);
        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
