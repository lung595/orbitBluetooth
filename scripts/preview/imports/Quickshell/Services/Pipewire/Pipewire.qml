pragma Singleton
import QtQuick

// Mock of Quickshell's Pipewire service for offscreen renders: one output
// sink for the made-up headset (02:00:00:00:10:06), so its volume ring shows.
QtObject {
    // The current default output (a node), null for none
    property var defaultAudioSink: null
    readonly property QtObject headset: QtObject {
        readonly property string name: "bluez_output.02_00_00_00_10_06.1"
        readonly property bool isSink: true
        readonly property bool isStream: false
        readonly property QtObject audio: QtObject {
            property real volume: 0.62
            property bool muted: false
        }
    }
    readonly property QtObject nodes: QtObject {
        readonly property var values: [headset]
    }
}
