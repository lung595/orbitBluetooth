import QtQuick
import "../pairing"

// What floats above the world: the contextual hint, the offer to connect a
// new device, the scan chip, the note on what did not work and the notice
// when Bluetooth is off. Each one only exists on screen while it has
// something to say.
Item {
    id: chrome
    required property var scene
    required property int bodyCount

    anchors.fill: parent

    OrbitHint {
        scene: chrome.scene
        bodyCount: chrome.bodyCount
    }
    OfferCard {
        scene: chrome.scene
    }
    // On glass it is centered, carries its own smoky pill so it reads on any
    // wallpaper, and only shows while the widget is in use
    ScanChip {
        scene: chrome.scene
    }
    // With a link to the guide
    OrbitNote {
        scene: chrome.scene
    }
    AdapterNotice {
        scene: chrome.scene
    }
}
