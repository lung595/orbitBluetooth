import QtQuick
import "../device/DeviceCatalog.js" as Catalog

// Offer to connect a new device: a named, unpaired device that shows up
// while scanning is offered right in the view (a small card with Connect),
// like a nearby-device prompt. Devices already around when the view opens
// are not news: they are marked as seen after a short settling delay.
// Nothing leaves the machine and nothing is remembered between sessions.
Item {
    id: offer
    required property var scene
    required property Repeater bodies   // the device bodies
    property string address: ""
    property var _seen: ({})
    property bool _primed: false

    // Called with every fresh device list (OrbitDevices.listed)
    function update(list) {
        const s = offer.scene;
        // The pop-up under the bar offers it instead (it sees the same discovery)
        if (!_primed || !s.prefs.offerNew || s.prefs.offerPopup)
            return;
        for (const d of list) {
            if (_seen[d.address])
                continue;
            _seen[d.address] = true;
            if (s.discovering && !d.connected && !(d.paired || d.bonded) && !Catalog.isUnnamed(d)) {
                address = d.address;
                offerTimer.restart();
            }
        }
    }
    function dismiss() {
        address = "";
        offerTimer.stop();
    }
    function accept() {
        const wanted = address;
        dismiss();
        for (let i = 0; i < offer.bodies.count; i++) {
            const b = offer.bodies.itemAt(i);
            if (b && b.address === wanted) {
                offer.scene.startConnect(b);
                return;
            }
        }
    }
    Timer {
        id: primeTimer
        interval: 3000
        running: offer.scene.active
        onTriggered: {
            for (const a in offer.scene.deviceMap)
                offer._seen[a] = true;
            offer._primed = true;
        }
    }
    Timer {
        id: offerTimer
        interval: 12000
        onTriggered: offer.address = ""
    }
}
