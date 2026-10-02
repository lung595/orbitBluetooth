import QtQuick
import qs.Common
import "VolumeFx.js" as Fx

// Sound waves leaving the planet at each 5 % step: a ring of light that
// widens and fades, wider and brighter the louder it gets. Reaching 100 %
// sends a corona instead, a stronger flare. Three waves at most at once;
// they are moved by the ring's clock (advance), nothing runs between steps.
Item {
    id: waves

    property real centerX: 0
    property real centerY: 0
    property real planetRadius: 0

    readonly property int pool: 3
    readonly property NightColors night: NightColors {}

    property var live: []
    property int frame: 0
    readonly property int alive: live.length

    function ping(volume, corona) {
        const next = live.slice(-(pool - 1));
        next.push({
            t: 0,
            volume: volume,
            corona: corona,
            life: corona ? 0.9 : 0.6
        });
        live = next;
        frame++;
    }

    function advance(dt) {
        const next = [];
        for (const w of live) {
            w.t += dt / w.life;
            if (w.t < 1)
                next.push(w);
        }
        live = next;
        frame++;
    }

    function clear() {
        live = [];
    }

    Repeater {
        model: waves.pool
        Rectangle {
            required property int index
            readonly property var w: waves.frame >= 0 && index < waves.live.length ? waves.live[index] : null
            readonly property var g: w ? Fx.wave(waves.planetRadius, w.volume, w.corona, w.t) : null
            visible: g !== null
            width: g ? g.radius * 2 : 0
            height: width
            radius: width / 2
            x: waves.centerX - width / 2
            y: waves.centerY - height / 2
            color: "transparent"
            border.width: g ? g.width : 0
            border.color: w && w.corona ? Qt.lighter(waves.night.ringAccent, 1.4) : waves.night.ringAccent
            opacity: g ? Math.min(1, g.alpha) : 0
        }
    }
}
