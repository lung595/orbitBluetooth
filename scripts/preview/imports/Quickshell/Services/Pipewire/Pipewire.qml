pragma Singleton
import QtQuick

// Mock of Quickshell's Pipewire service for offscreen renders: one output
// sink for the made-up headset (02:00:00:00:10:06), so its volume ring shows.
QtObject {
    // The current default output (a node), null for none
    property var defaultAudioSink: null
    // Whether sound is playing (the beams of a Listen together pulse then)
    property bool playing: true
    readonly property QtObject headset: QtObject {
        readonly property string name: "bluez_output.02_00_00_00_10_06.1"
        readonly property bool isSink: true
        readonly property bool isStream: false
        readonly property QtObject audio: QtObject {
            property real volume: 0.62
            property bool muted: false
        }
    }
    // Further Bluetooth output sinks and link groups a test may set: the
    // shared-radio note watches which outputs are fed sound
    property var extraSinks: []
    property var links: []
    readonly property QtObject nodes: QtObject {
        readonly property var values: [headset].concat(extraSinks)
    }
    readonly property QtObject linkGroups: QtObject {
        readonly property var values: links
    }
}
