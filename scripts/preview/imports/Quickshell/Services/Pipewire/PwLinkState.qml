pragma Singleton
import QtQuick

// Mock of Quickshell's PwLinkState: the one value the plugin compares with
QtObject {
    enum State {
        Paused = 5,
        Active = 6
    }
}
