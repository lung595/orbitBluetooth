import QtQuick

// Mock of Quickshell's PwNodeLinkTracker. By default one running link while
// the mock Pipewire says sound plays, none otherwise (the Listen together
// center watches that); a test may set `linkGroups` by hand instead (the
// pause-on-removal streams).
QtObject {
    property var node: null
    property var linkGroups: Pipewire.playing ? [{
            "state": PwLinkState.Active
        }] : []
}
