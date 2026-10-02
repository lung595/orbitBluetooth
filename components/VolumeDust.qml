import QtQuick
import qs.Common
import "VolumeFx.js" as Fx

// Fine stardust shed by the volume ring's moon while it moves: the faster
// it goes, the more grains (VolumeFx.emission). Each grain is thrown along
// the moon's path, pulled back by the planet's gravity and fades out; it is
// drawn as a short streak along its speed, so motion reads as motion.
// The grains live in a fixed pool and are moved by the ring's clock
// (advance), so nothing runs once the last one has faded.
Item {
    id: dust

    property real centerX: 0
    property real centerY: 0
    property real radius: 0

    readonly property int pool: 48
    readonly property real gravity: 60 // px/s², toward the planet
    readonly property NightColors night: NightColors {}

    property var grains: []
    property real carry: 0
    // Bumped each frame so the grains below re-read the pool
    property int frame: 0
    readonly property int alive: grains.length

    // One frame: move the living grains, then shed new ones at the moon
    // (angle `deg`) according to its speed (degrees per second) and way
    function advance(dt, deg, speed, dir) {
        const next = [];
        for (const p of grains)
            if (Fx.step(p, dt, centerX, centerY, gravity))
                next.push(p);
        const e = Fx.emission(speed, dt, carry);
        carry = e.carry;
        for (let i = 0; i < e.count && next.length < pool; i++)
            next.push(Fx.spawn(centerX, centerY, radius, deg, dir, Math.random(), Math.random(), Math.random(), Math.random()));
        grains = next;
        frame++;
    }

    function clear() {
        grains = [];
        carry = 0;
        frame++;
    }

    Repeater {
        model: dust.pool
        Rectangle {
            required property int index
            readonly property var p: dust.frame >= 0 && index < dust.grains.length ? dust.grains[index] : null
            readonly property real t: p ? Fx.lifeT(p) : 1
            readonly property real speed: p ? Math.sqrt(p.vx * p.vx + p.vy * p.vy) : 0
            visible: p !== null
            // A streak: as thick as the grain, stretched by its speed
            height: p ? p.size : 0
            width: p ? p.size + Math.min(7, speed * 0.06) : 0
            radius: height / 2
            x: p ? p.x - width / 2 : 0
            y: p ? p.y - height / 2 : 0
            rotation: p ? Math.atan2(p.vy, p.vx) * 180 / Math.PI : 0
            // Born white hot, cools to the theme's color, twinkles on the way
            color: t < 0.35 ? Qt.lighter(dust.night.ringAccent, 1.6) : dust.night.ringAccent
            opacity: p ? (1 - t) * (0.75 + 0.25 * Math.sin(p.twinkle + p.age * 22)) : 0
            // A soft glow around the grain, so fine dust still catches the eye
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 4
                height: parent.height + 4
                radius: height / 2
                color: Theme.withAlpha(dust.night.ringAccent, 0.22)
            }
        }
    }
}
