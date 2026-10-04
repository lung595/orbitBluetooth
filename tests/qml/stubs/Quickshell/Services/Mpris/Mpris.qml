pragma Singleton
import QtQuick

// Stand-in for Quickshell's media player list: the test sets `values`
QtObject {
    readonly property QtObject players: QtObject {
        property var values: []
    }
}
