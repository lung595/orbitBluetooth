pragma Singleton
import QtQuick

// Counts the times DMS's own volume pop-up was asked to keep quiet
QtObject {
    property int quiet: 0
    function suppressOSDTemporarily() {
        quiet++;
    }
}
