import QtQuick

// Preview stand-in: no process runs, so no line ever arrives
QtObject {
    signal read(string data)
}
