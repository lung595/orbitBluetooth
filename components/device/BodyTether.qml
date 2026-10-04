import QtQuick
import qs.Common

// The line from the host core to a device. It lives in the scene's tether
// layer (under the host and every device) and turns toward the device; its
// angle and length are reused by the charging beam, and the owning body's
// lock animation briefly thickens it when a connection lands.
Item {
    id: tether
    required property var body

    parent: body.scene.tetherLayer
    visible: opacity > 0.01
    readonly property var host: body.scene.centre.host
    x: host.x
    y: host.y
    rotation: Math.atan2(body.py - host.y, body.px - host.x) * 180 / Math.PI
    opacity: body.leaving || body.focused || body.swallowing ? 0 : tetherAlpha * (body.scene.focusBody || body.scene.hiddenOpen ? 0.15 : 1)

    readonly property real dist: Math.hypot(body.px - host.x, body.py - host.y)
    readonly property real tetherAlpha: {
        // The members of a Listen together have no tether: they are the center
        if (body.scene.centre.tetherless(body.address))
            return 0;
        if (body.dragging && body.holding)
            return body.armed ? 0.25 : 0.7;
        // Connecting: steady here, the pulse is on the line below (a
        // per-step value under this Behavior would restart it every step,
        // a never-ending animation that redraws the whole shell)
        if (body.phase === "connecting")
            return 0.7;
        if (body.connected)
            return body.charging ? 0 : 0.4;   // the energy beam replaces it
        return 0;
    }
    property real reach: 1   // animated to retract / extend
    property real thickness: 1.5

    Behavior on opacity {
        NumberAnimation {
            duration: 260
        }
    }

    Rectangle {
        x: tether.body.scene.coreSize / 2 * tether.host.scale
        y: -height / 2
        // Connecting: pulses between half and full (0.35 to 0.7 overall)
        opacity: tether.body.phase === "connecting" ? 0.5 + 0.5 * Math.abs(Math.sin(tether.body.scene.clock * 4)) : 1
        height: tether.thickness * (tether.body.dragging && tether.body.holding ? Math.max(0.4, 1.4 - (tether.dist / (tether.body.scene.rx * tether.body.scene.innerNorm * tether.host.scale) - 1) * 1.2) : 1)
        width: Math.max(0, (tether.dist - tether.body.scene.coreSize / 2 * tether.host.scale - tether.body.diameter * tether.body.baseScale / 2) * tether.reach)
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: tether.body.armed && tether.body.holding ? Theme.withAlpha(tether.body.night.error, 0.9) : Theme.withAlpha(tether.body.night.primary, 0.9)
            }
            GradientStop {
                position: 1
                color: tether.body.armed && tether.body.holding ? Theme.withAlpha(tether.body.night.error, 0.15) : Theme.withAlpha(tether.body.night.primary, 0.2)
            }
        }
    }
}
