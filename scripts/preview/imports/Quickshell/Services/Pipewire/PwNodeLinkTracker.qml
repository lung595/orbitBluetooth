import QtQuick

// Mock of Quickshell's PwNodeLinkTracker: one running link while the mock
// Pipewire says sound plays, none otherwise
QtObject {
    property var node: null
    readonly property var linkGroups: Pipewire.playing ? [{
            "state": PwLinkState.Active
        }] : []
}
