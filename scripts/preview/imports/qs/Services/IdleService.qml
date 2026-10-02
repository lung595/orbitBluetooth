pragma Singleton
import QtQuick

// Preview stand-in: screens always awake in a screenshot
QtObject {
    property bool isShellLocked: false
    property bool monitorsOff: false
}
