import QtQuick
import qs.Common
import qs.Services
import "../device"

// The host at the orbit's center: this computer's glyph on a soft glow. It
// breathes with the scene clock, pulses when a device connects, and its
// inner part starts a scan. While a Listen together has the center it sits
// small and dimmed at the back, and a click brings it back for a moment.
Item {
    id: core
    required property var scene
    // The world this core sits in: it tells which device is under a point
    required property var world

    // A short bump of the core when a device connects
    function pulse() {
        corePulseAnim.restart();
    }

    readonly property var centre: core.scene.centre
    x: centre.host.x - width / 2
    y: centre.host.y - height / 2
    width: core.scene.coreSize
    height: width
    opacity: (core.scene.focusBody || core.scene.hiddenOpen ? 0.15 : core.scene.btOn ? 1 : 0.45) * (centre.hostAway ? 0.6 : 1)
    scale: (core.scene.motion ? 1 + 0.018 * Math.sin(core.scene.clock * 1.3) : 1) * corePulse.value * centre.host.scale

    Behavior on opacity {
        NumberAnimation {
            duration: 400
        }
    }

    QtObject {
        id: corePulse
        property real value: 1
    }

    SequentialAnimation {
        id: corePulseAnim
        NumberAnimation {
            target: corePulse
            property: "value"
            to: 1.08
            duration: 140
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: corePulse
            property: "value"
            to: 1
            duration: 520
            easing.type: Easing.OutBack
            easing.overshoot: 2
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 1.9
        height: width
        radius: width / 2
        color: Theme.withAlpha(core.scene.night.primary, core.scene.btOn ? 0.05 : 0.0)
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 1.4
        height: width
        radius: width / 2
        color: Theme.withAlpha(core.scene.night.primary, core.scene.btOn ? 0.08 : 0.02)
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: core.scene.night.whiteBodies ? Qt.tint("#FFFFFF", Theme.withAlpha(Theme.primary, 0.08)) : Qt.tint("#1a1c22", Theme.withAlpha(core.scene.night.primary, 0.22))
            }
            GradientStop {
                position: 1
                color: core.scene.night.whiteBodies ? Qt.tint("#E6ECF2", Theme.withAlpha(Theme.primary, 0.16)) : Qt.tint("#0b0c10", Theme.withAlpha(core.scene.night.primary, 0.1))
            }
        }
        border.width: 1
        border.color: Theme.withAlpha(core.scene.night.primary, core.scene.btOn ? 0.4 : 0.12)
    }
    DeviceGlyph {
        anchors.centerIn: parent
        width: parent.width * 0.5
        height: width
        kind: core.scene.prefs.hostGlyph !== "auto" ? core.scene.prefs.hostGlyph : (BatteryService.batteryAvailable ? "laptop" : "desktop")
        color: core.scene.btOn ? (core.scene.night.whiteBodies ? core.scene.night.bodyInk : Qt.lighter(core.scene.night.primary, 1.2)) : (core.scene.night.whiteBodies ? core.scene.night.bodyMuted : core.scene.night.ink(0.4))
        stroke: 1.4
    }

    // Only the inner 70% starts a scan, and never over a device. Small at
    // the back it is all one target: a click brings it to the center.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: core.scene.btOn && !core.scene.focusBody
        onPressed: mouse => {
            const inner = Math.hypot(mouse.x - width / 2, mouse.y - height / 2) < width * (core.centre.hostAway ? 0.5 : 0.35);
            const p = mapToItem(core.scene, mouse.x, mouse.y);
            mouse.accepted = inner && !core.world.bodyAt(p.x, p.y);
        }
        onClicked: {
            if (core.centre.hostAway) {
                core.centre.recall();
                return;
            }
            core.scene.startScan();
            core.scene.emitWave(true);
        }
    }
}
