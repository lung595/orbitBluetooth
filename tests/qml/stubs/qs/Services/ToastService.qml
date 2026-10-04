pragma Singleton
import QtQuick

// Records the warnings instead of showing them
QtObject {
    property var log: []
    function showWarning(text, url) {
        log = log.concat([url]);
    }
}
