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

    function getItems(query) {
        const table = Words.resolve(pluginService ? pluginService.loadPluginData("orbitBluetooth", "launcherWords", ({})) : null);
        const phrase = Phrase.parse(query, table);
        if (!phrase.ok)
            return [];
        const list = Bluetooth.devices.values;
        const connected = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                connected.push({
                    "address": list[i].address,
                    "name": list[i].name || ""
                });
        }
        const found = Phrase.findDevice(phrase.query, connected);
        if (!found.ok)
            return [];
        const name = connected.find(d => d.address === found.address).name;
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

    function executeItem(item) {
        const parts = String(item && item.action || "").split(":");
        // The address is a fixed-shape token: validated again before it is a command argument
        if (parts[0] !== "disconnectIn" || parts.length !== 8 || !/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/i.test(parts.slice(1, 7).join(":")))
            return;
        run.command = ["dms", "ipc", "call", "orbitBluetooth", "disconnectIn", "--", parts.slice(1, 7).join(":"), parts[7]];
        run.running = true;
    }

    Process {
        id: run
    }
}
