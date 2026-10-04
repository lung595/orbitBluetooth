import QtQuick

// Mock of Quickshell's link tracker: no stream is ever linked offscreen,
// a test sets `linkGroups` by hand.
QtObject {
    property var node: null
    property var linkGroups: []
}
