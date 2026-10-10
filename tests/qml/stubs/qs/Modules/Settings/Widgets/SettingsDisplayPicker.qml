import QtQuick

// Stands in for DMS's display picker offscreen: no desktop widget instance is
// made up, so it never shows.
Item {
    property var displayPreferences: ["all"]
    signal preferencesChanged(var prefs)
    height: 0
}
