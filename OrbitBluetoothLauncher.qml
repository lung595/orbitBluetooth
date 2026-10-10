import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import "components/delay/DisconnectPhrase.js" as Phrase
import "components/delay/LauncherWords.js" as Words

// The launcher entry of "deco xm6 30": it only understands the phrase and hands
// the work to `dms ipc call orbitBluetooth disconnectIn`, so the delay engine
// stays in the daemon. The action words come from the plugin settings key
// `launcherWords` (D424), never from here.
Item {
    id: root

    property var pluginService: null
    // No trigger: the entry shows whenever a phrase starts with one of the words
    property string trigger: ""
    signal itemsChanged

    // One entry per phrase that starts with an action word. A phrase that cannot
    // be run (no device, a bad delay) still gets a plain entry saying why, never
    // a silent nothing (value 10); its action is empty, so it runs nothing.
    function getItems(query) {
        const table = Words.resolve(pluginService ? pluginService.loadPluginData("orbitBluetooth", "launcherWords", ({})) : null);
        const phrase = Phrase.parse(query, table);
        if (!phrase.ok)
            return phrase.why === "noWord" || phrase.why === "empty" ? [] : [_refusal(phrase.why)];
        const connected = Phrase.connectedOf(Bluetooth.devices.values);
        const found = Phrase.findDevice(phrase.query, connected);
        if (!found.ok)
            return [_refusal(found.why)];
        const name = Phrase.plain(connected.find(d => d.address === found.address).name);
        return [
            {
                "name": "Disconnect " + name + " in " + phrase.minutes + " min",
                "icon": "material:bluetooth_disabled",
                "comment": "Orbit counts the delay; it is dropped if the device leaves first",
                "action": "disconnectIn:" + found.address + ":" + phrase.minutes,
                "categories": ["OrbitBluetooth"]
            }
        ];
    }

    function _refusal(why) {
        return {
            "name": Phrase.note(why),
            "icon": "material:info",
            "comment": "Disconnect after a delay",
            "action": "",
            "categories": ["OrbitBluetooth"]
        };
    }

    // The command line a chosen entry runs, or [] when it is not a valid
    // "disconnectIn:<address>:<minutes>". The address and the minutes are
    // re-checked here: they become command arguments.
    function commandOf(item) {
        const m = /^disconnectIn:((?:[0-9A-F]{2}:){5}[0-9A-F]{2}):(\d{1,4})$/i.exec(String(item && item.action || ""));
        return m ? ["dms", "ipc", "call", "orbitBluetooth", "disconnectIn", m[1], m[2]] : [];
    }

    function executeItem(item) {
        const command = commandOf(item);
        if (command.length === 0)
            return;
        run.command = command;
        run.running = true;
    }

    Process {
        id: run
    }
}
