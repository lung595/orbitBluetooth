pragma Singleton
import QtQuick

// Preview and test stand-in: the processes that exist right now, so a test
// can count what a component started and see that stopping it removes them
QtObject {
    property var live: []

    function born(process) {
        live = live.concat([process]);
    }
    function died(process) {
        live = live.filter(p => p !== process);
    }
}
