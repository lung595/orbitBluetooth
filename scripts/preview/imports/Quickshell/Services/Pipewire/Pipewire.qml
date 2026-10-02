pragma Singleton
import QtQuick

// Mock of Quickshell's Pipewire service for offscreen renders: no audio
// node, so the volume row draws its "no sink" state.
QtObject {
    readonly property QtObject nodes: QtObject {
        readonly property var values: []
    }
}
