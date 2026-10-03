import QtQuick
import "Polar.js" as Polar

// What the vectorscope shows of the sound, in one of three styles
// (Settings → Sound → Visualizer), drawn on a single Canvas with additive
// light, so dense places glow brighter, like iZotope Ozone's imager:
//  - points: a dense cloud, each dot born from one band of the latest
//    frame (Polar.spawn), fading as it drifts outward like phosphor;
//  - rays:   the spectrum as a fan of rays with falling peak marks;
//  - waves:  the spectrum as one live curve, nothing left behind.
// Moved by PolarScope's clock (advance), which stops once `alive` is 0.
Item {
    id: vis

    property string style: "points"
    property real centerX: 0
    property real centerY: 0
    property real radius: 0
    // The outer color, and the one the center blends toward
    property color color: "white"
    property color color2: "white"
    // Muted: the picture dims instead of vanishing, the sound still flows
    property bool quiet: false

    // The volume heard (0..1): the picture is drawn that big (Polar.scaleFor),
    // eased on the clock so a volume step makes it grow, not jump
    property real gain: 1
    property real _gain: gain
    readonly property real _r: radius * Polar.scaleFor(_gain)

    // Something is still on screen: the clock keeps running
    property int alive: 0

    // --- Points ---------------------------------------------------------------
    readonly property int pool: 720
    readonly property real lifetime: 0.6 // seconds
    readonly property real rate: 1900 // dots per second at full loudness
    property var _dots: []
    property real _carry: 0
    property int _band: 0

    // --- Rays and waves: meter-like levels ----------------------------------------
    readonly property int raysPerSide: 16
    readonly property int waveSteps: 72
    property var _levels: ({ "l": [], "r": [] })
    property var _peaks: []

    function advance(dt, frame) {
        _gain = Polar.ease(_gain, gain, dt, 9);
        if (style === "points")
            _advanceDots(dt, frame);
        else if (style === "rays" || style === "waves")
            _advanceLevels(dt, frame);
        else
            alive = 0;
        canvas.requestPaint();
    }

    function _advanceDots(dt, frame) {
        const kept = [];
        for (let i = 0; i < _dots.length; i++) {
            const p = _dots[i];
            p.life += dt / lifetime;
            if (p.life < 1)
                kept.push(p);
        }
        if (frame) {
            _carry += rate * dt * (0.2 + 0.8 * Polar.loudness(frame));
            const bands = frame.l.length;
            // A silent band spawns nothing: a bounded number of tries
            for (let tries = 0; _carry >= 1 && kept.length < pool && tries < pool; tries++) {
                // Bands in turn, so every part of the sound gets its dots
                _band = (_band + 1) % bands;
                _carry -= 1;
                const p = Polar.spawn(frame, _band, _r, Math.random(), Math.random(), Math.random());
                if (p)
                    kept.push(p);
            }
            _carry = Math.min(_carry, 8);
        }
        _dots = kept;
        alive = kept.length;
    }

    function _advanceLevels(dt, frame) {
        const n = frame ? frame.l.length : _levels.l.length;
        let live = 0;
        const next = { "l": [], "r": [] };
        for (let i = 0; i < n; i++) {
            next.l.push(Polar.follow(_levels.l[i] || 0, frame ? frame.l[i] : 0, dt));
            next.r.push(Polar.follow(_levels.r[i] || 0, frame ? frame.r[i] : 0, dt));
            if (next.l[i] > 0.004 || next.r[i] > 0.004)
                live++;
        }
        _levels = next;
        if (style === "rays") {
            // Peak marks hold, then fall slower than the rays
            const angles = Polar.rayAngles(raysPerSide);
            const peaks = [];
            for (let k = 0; k < angles.length; k++) {
                const v = Polar.levelAt(next, angles[k]);
                const old = (_peaks[k] || 0) - dt * 0.45;
                peaks.push(Math.max(v, old, 0));
                if (peaks[k] > 0.004)
                    live++;
            }
            _peaks = peaks;
        }
        alive = live;
    }

    // The wave's outline: one reach per step, from left to right
    function _shape(levels) {
        const out = [];
        for (let s = 0; s <= waveSteps; s++) {
            const deg = Polar.LEFT + 2 + s * (176 / waveSteps);
            out.push(Polar.reach(Polar.levelAt(levels, deg), _r));
        }
        return out;
    }

    function clear() {
        _dots = [];
        _carry = 0;
        _levels = { "l": [], "r": [] };
        _peaks = [];
        _gain = gain;
        alive = 0;
        canvas.requestPaint();
    }
    onStyleChanged: clear()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        function rgba(c, a) {
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a.toFixed(3) + ")";
        }
        function mix(a, b, t) {
            return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
        }
        function xy(deg, d) {
            const a = deg * Math.PI / 180;
            return [vis.centerX + Math.cos(a) * d, vis.centerY + Math.sin(a) * d];
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (vis.alive === 0 || vis.radius <= 0)
                return;
            ctx.globalCompositeOperation = "lighter";
            const dim = vis.quiet ? 0.32 : 1;
            if (vis.style === "points")
                drawDots(ctx, dim);
            else if (vis.style === "rays")
                drawRays(ctx, dim);
            else if (vis.style === "waves")
                drawWaves(ctx, dim);
        }

        // Dots grouped by color and brightness: a few fills, not one per dot
        function drawDots(ctx, dim) {
            const groups = 5, tones = 3;
            const paths = [];
            for (let g = 0; g < groups * tones; g++)
                paths.push([]);
            for (let i = 0; i < vis._dots.length; i++) {
                const p = vis._dots[i];
                const fade = (1 - p.life) * (1 - p.life);
                const g = Math.min(groups - 1, Math.floor(fade * groups));
                const tone = Math.min(tones - 1, Math.floor(p.dist / Math.max(1, vis._r) * tones));
                paths[tone * groups + g].push(p);
            }
            for (let tone = 0; tone < tones; tone++) {
                const c = mix(vis.color2, vis.color, tone / (tones - 1));
                for (let g = 0; g < groups; g++) {
                    const list = paths[tone * groups + g];
                    if (!list.length)
                        continue;
                    const a = (g + 0.5) / groups * dim;
                    // A soft halo first, then the bright core
                    for (let pass = 0; pass < 2; pass++) {
                        ctx.beginPath();
                        for (let i = 0; i < list.length; i++) {
                            const p = list[i];
                            const at = xy(p.deg, p.dist * (1 + 0.14 * p.life));
                            const r = pass === 0 ? p.size * 1.9 : p.size * 0.62;
                            ctx.moveTo(at[0] + r, at[1]);
                            ctx.arc(at[0], at[1], r, 0, Math.PI * 2);
                        }
                        ctx.fillStyle = rgba(c, pass === 0 ? a * 0.16 : a);
                        ctx.fill();
                    }
                }
            }
        }

        function drawRays(ctx, dim) {
            const angles = Polar.rayAngles(vis.raysPerSide);
            const R = vis._r;
            const base = Polar.reach(0, R);
            const w = Math.max(1.5, R * 87 / vis.raysPerSide * Math.PI / 180 * 0.22);
            ctx.lineCap = "round";
            for (let k = 0; k < angles.length; k++) {
                const v = Polar.levelAt(vis._levels, angles[k]);
                const end = Polar.reach(v, R);
                const from = xy(angles[k], base), to = xy(angles[k], end);
                const grad = ctx.createLinearGradient(from[0], from[1], to[0], to[1]);
                grad.addColorStop(0, rgba(vis.color2, 0.25 * dim));
                grad.addColorStop(1, rgba(mix(vis.color2, vis.color, v), 0.95 * dim));
                for (let pass = 0; pass < 2; pass++) {
                    ctx.beginPath();
                    ctx.moveTo(from[0], from[1]);
                    ctx.lineTo(to[0], to[1]);
                    ctx.lineWidth = pass === 0 ? w * 2.6 : w;
                    ctx.strokeStyle = pass === 0 ? rgba(vis.color, 0.07 * dim * (0.3 + v)) : grad;
                    ctx.stroke();
                }
                // The peak mark, a short tick across the ray
                const pk = Polar.reach(vis._peaks[k] || 0, R) + w * 1.6;
                const at = xy(angles[k], pk);
                ctx.beginPath();
                ctx.arc(at[0], at[1], w * 0.5, 0, Math.PI * 2);
                ctx.fillStyle = rgba(vis.color, 0.9 * dim);
                ctx.fill();
            }
        }

        // Through the outline's points on curves (each corner rounded to the
        // middle of its neighbours), so the wave has no sharp edge
        function outline(ctx, shape, grow) {
            const pts = [];
            for (let s = 0; s < shape.length; s++)
                pts.push(xy(Polar.LEFT + 2 + s * (176 / (shape.length - 1)), shape[s] * grow));
            ctx.beginPath();
            ctx.moveTo(pts[0][0], pts[0][1]);
            for (let s = 1; s < pts.length - 1; s++)
                ctx.quadraticCurveTo(pts[s][0], pts[s][1], (pts[s][0] + pts[s + 1][0]) / 2, (pts[s][1] + pts[s + 1][1]) / 2);
            const last = pts[pts.length - 1];
            ctx.lineTo(last[0], last[1]);
        }
        function drawWaves(ctx, dim) {
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            // The live wave: a soft fill down to the center, a glow, a line
            const shape = vis._shape(vis._levels);
            outline(ctx, shape, 1);
            ctx.lineTo(vis.centerX, vis.centerY);
            ctx.closePath();
            const fill = ctx.createRadialGradient(vis.centerX, vis.centerY, 0, vis.centerX, vis.centerY, Math.max(1, vis._r));
            fill.addColorStop(0, rgba(vis.color2, 0.22 * dim));
            fill.addColorStop(1, rgba(vis.color, 0.04 * dim));
            ctx.fillStyle = fill;
            ctx.fill();
            for (let pass = 0; pass < 2; pass++) {
                outline(ctx, shape, 1);
                // A thin line over a faint, wider glow
                ctx.lineWidth = pass === 0 ? Math.max(3, vis._r * 0.035) : 1.25;
                ctx.strokeStyle = rgba(vis.color, (pass === 0 ? 0.08 : 0.9) * dim);
                ctx.stroke();
            }
        }
    }
}
