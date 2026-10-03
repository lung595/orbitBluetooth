import QtQuick
import "Polar.js" as Polar

// The vectorscope's cloud: a fixed pool of dots, each born from one band
// of the latest sound frame (Polar.spawn) and fading out as it drifts a
// little outward, like phosphor on an old scope. Moved by PolarScope's
// clock; dots are written to their items directly, only living ones.
Item {
    id: cloud

    property real centerX: 0
    property real centerY: 0
    property real radius: 0
    property color color: "white"
    // Muted: the cloud dims instead of vanishing, the sound still flows
    property bool quiet: false

    readonly property int pool: 140
    readonly property real lifetime: 0.55 // seconds
    readonly property real rate: 260 // dots per second at full loudness

    property var slots: []
    property real carry: 0
    property int alive: 0
    property int _band: 0

    function advance(dt, frame) {
        let count = 0;
        for (let i = 0; i < slots.length; i++) {
            const p = slots[i];
            if (!p)
                continue;
            const r = items.itemAt(i);
            p.life += dt / lifetime;
            if (p.life >= 1) {
                slots[i] = null;
                r.visible = false;
                continue;
            }
            count++;
            place(r, p);
        }
        if (frame) {
            carry += rate * dt * (0.25 + 0.75 * Polar.loudness(frame));
            const bands = frame.l.length;
            for (let i = 0; i < pool && carry >= 1; i++) {
                if (slots[i])
                    continue;
                // Bands in turn, so every part of the sound gets its dots
                _band = (_band + 1) % bands;
                carry -= 1;
                const p = Polar.spawn(frame, _band, radius, Math.random(), Math.random(), Math.random());
                if (!p)
                    continue;
                slots[i] = p;
                const r = items.itemAt(i);
                r.width = p.size;
                r.height = p.size;
                r.radius = p.size / 2;
                r.visible = true;
                place(r, p);
                count++;
            }
            carry = Math.min(carry, 4);
        }
        alive = count;
    }

    function place(r, p) {
        const d = p.dist * (1 + 0.12 * p.life);
        const a = p.deg * Math.PI / 180;
        r.x = centerX + Math.cos(a) * d - r.width / 2;
        r.y = centerY + Math.sin(a) * d - r.height / 2;
        r.opacity = (quiet ? 0.3 : 0.85) * (1 - p.life) * (1 - p.life);
    }

    function clear() {
        for (let i = 0; i < slots.length; i++)
            if (slots[i])
                items.itemAt(i).visible = false;
        slots = new Array(pool).fill(null);
        carry = 0;
        alive = 0;
    }
    Component.onCompleted: slots = new Array(pool).fill(null)

    Repeater {
        id: items
        model: cloud.pool
        Rectangle {
            visible: false
            color: cloud.color
        }
    }
}
