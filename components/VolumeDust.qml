import QtQuick
import qs.Common
import "VolumeFx.js" as Fx

// Fine stardust shed by the volume ring's moon while it moves: the faster
// it goes, the more grains (VolumeFx.emission). Each grain is thrown ahead
// and outward, pulled back by the planet's gravity and fades out; it is
// drawn as a short streak along its speed, so motion reads as motion.
// The grains live in a fixed pool moved by the ring's clock (advance).
// They are written to their items directly instead of through bindings:
// only living grains are touched, which keeps a busy frame cheap
// (measured: half the cost of bindings).
Item {
    id: dust

    property real centerX: 0
    property real centerY: 0
    property real radius: 0

    readonly property int pool: 24
    readonly property real gravity: 60 // px/s², toward the planet
    readonly property NightColors night: NightColors {}
    readonly property color hot: Qt.lighter(night.ringAccent, 1.6)
    readonly property color cool: night.ringAccent

    // One slot per item, so a grain keeps its item for life: its size and
    // color are written once, a frame only moves it
    property var slots: []
    property real carry: 0
    property int alive: 0

    // One frame: move the living grains, then shed new ones at the moon
    // (angle `deg`) according to its speed (degrees per second) and way
    function advance(dt, deg, speed, dir) {
        let count = 0;
        for (let i = 0; i < slots.length; i++) {
            const p = slots[i];
            if (!p)
                continue;
            const r = items.itemAt(i);
            if (!Fx.step(p, dt, centerX, centerY, gravity)) {
                slots[i] = null;
                r.visible = false;
                continue;
            }
            count++;
            move(r, p);
        }
        const e = Fx.emission(speed, dt, carry);
        carry = e.carry;
        for (let i = 0, n = 0; i < pool && n < e.count; i++) {
            if (slots[i])
                continue;
            const p = Fx.spawn(centerX, centerY, radius, deg, dir, Math.random(), Math.random(), Math.random(), Math.random());
            slots[i] = p;
            const r = items.itemAt(i);
            r.height = p.size;
            r.radius = p.size / 2;
            r.color = hot; // born white hot
            r.visible = true;
            move(r, p);
            n++;
            count++;
        }
        alive = count;
    }

    function move(r, p) {
        const t = Fx.lifeT(p);
        const speed = Math.sqrt(p.vx * p.vx + p.vy * p.vy);
        // A streak: as thick as the grain, stretched by its speed
        const w = p.size + Math.min(7, speed * 0.06);
        r.width = w;
        r.x = p.x - w / 2;
        r.y = p.y - p.size / 2;
        r.rotation = Math.atan2(p.vy, p.vx) * 180 / Math.PI;
        // Cools to the theme's color, twinkles on the way
        if (t >= 0.35 && !p.cooled) {
            p.cooled = true;
            r.color = cool;
        }
        r.opacity = 0.8 * (1 - t) * (0.75 + 0.25 * Math.sin(p.twinkle + p.age * 22));
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
        model: dust.pool
        Rectangle {
            visible: false
        }
    }
}
