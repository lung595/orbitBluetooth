pragma Singleton
import QtQuick

// Same names and numbers as Quickshell's enum (QML properties cannot start
// with a capital, an enum can)
QtObject {
    enum State {
        Stopped,
        Playing,
        Paused
    }
}
