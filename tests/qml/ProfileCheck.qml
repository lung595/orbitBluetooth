import QtQuick
import "Guard.js" as Guard

// Test stand-in for components/pairing/ProfileCheck.qml: same decision (Guard.js),
// but reads the profiles from the fake device instead of calling busctl.
QtObject {
    property var log: []
    function check(device, family, done) {
        log = log.concat([device.name]);
        Qt.callLater(() => {
            if (!Guard.refused(family, device.uuids)) {
                done("ok");
                return;
            }
            device.trusted = false;
            device.blocked = true;
            done("input");
        });
    }
    function allow(device) { device.blocked = false; }
    function deny(device) { device.trusted = false; device.forget(); device.blocked = false; }
}
