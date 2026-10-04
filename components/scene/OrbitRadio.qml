pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire
import "../common/Guide.js" as Guide
import "../radio"
import "../radio/Radio.js" as Radio

// Tells, once per pair of outputs and per session, that two Bluetooth
// outputs playing at once share one radio and may lose quality or cut (D293,
// P170): never a silent limit (value 10), and never a quality traded away
// (Orbit does not touch any device's codec). Said under the core while the
// orbit is open, with the GitHub mark to the guide; nothing is stored.
// The watch exists only while two outputs of the adapter do.
Item {
    id: radio

    required property var scene

    // The adapter's own devices by address: another adapter has its own radio
    readonly property var known: {
        const map = {};
        for (const d of scene.adapter?.devices?.values ?? [])
            map[d.address] = true;
        return map;
    }
    readonly property bool watching: Radio.outputCount(Pipewire.nodes.values, known) >= 2

    // The pairs already told about, this session only
    property var told: []
    readonly property string pair: radioWatch.item ? radioWatch.item.key : ""
    function tell() {
        if (!Radio.due(pair, told, scene.active))
            return;
        told = told.concat([pair]);
        scene.explain(Guide.radioNote());
    }
    onPairChanged: tell()
    // The orbit opens on a pair that shares the radio: say it now
    Connections {
        target: radio.scene
        function onActiveChanged() {
            radio.tell();
        }
    }

    Loader {
        id: radioWatch
        active: radio.watching
        sourceComponent: RadioWatch {
            known: radio.known
        }
    }
}
