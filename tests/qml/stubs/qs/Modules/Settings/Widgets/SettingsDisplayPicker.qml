import QtQuick

// Stands in for DMS's display picker offscreen: no desktop widget instance is
// made up, so it never shows.
Item {
    property var displayPreferences: ["all"]
    // DMS 2.1: a callback property, the old preferencesChanged signal is gone
    property var preferencesHandler: null
    height: 0
}
