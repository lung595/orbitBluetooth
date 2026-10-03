import QtQuick
import qs.Common
import qs.Services
import "../common/Guide.js" as Guide
import "../device/DeviceCatalog.js" as Catalog

// Over the focused glyph on the detail card: a click mutes (D251: with one
// audio device connected this PC, with several that device), the wheel
// takes a smart step on the level the user hears move first. A device with
// no sound to drive (keyboard, mouse, audio not up yet) says why on the
// wheel, with the guide's link, instead of doing nothing (value 10).
Item {
    id: planet

    required property var scene
    readonly property var body: scene.focusBody
    readonly property var route: scene.audioRoute
    readonly property string address: body && body.connected ? body.address : ""
    readonly property bool hasSound: !!route && !!address && !!route.find(address)

    // Only once the glyph has landed on the card
    readonly property real size: scene.focusGlyphSize
    width: size
    height: size
    x: body ? body.x + body.width / 2 - size / 2 : 0
    y: body ? body.y + body.height / 2 - size / 2 : 0
    visible: !!address && body.focusScale > scene.focusGlyphScale * 0.92

    MouseArea {
        anchors.fill: parent
        enabled: planet.hasSound
        cursorShape: Qt.PointingHandCursor
        // The round planet only: the card's buttons next to it stay reachable
        containmentMask: QtObject {
            function contains(point: point): bool {
                const dx = point.x - planet.size / 2;
                const dy = point.y - planet.size / 2;
                return dx * dx + dy * dy <= planet.size * planet.size / 4;
            }
        }
        onClicked: {
            SessionData.suppressOSDTemporarily();
            planet.route.toggleMute(planet.address);
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: e => {
            if (!planet.hasSound) {
                if (!planet.scene.note || planet.scene.note.anchor !== "the-two-volumes")
                    planet.scene.explain(Guide.noVolumeNote(planet.body.device ? Catalog.deviceName(planet.body.device) : ""));
                return;
            }
            // Touchpads send small deltas: add them up to whole notches
            acc += e.angleDelta.y;
            const notches = Math.trunc(acc / 120);
            if (notches === 0)
                return;
            acc -= notches * 120;
            SessionData.suppressOSDTemporarily();
            planet.route.setLevel(planet.route.mainPart(planet.address), notches > 0 ? "up" : "down", planet.address);
        }
    }
}
