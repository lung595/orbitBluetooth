import QtQuick
import "Members.js" as Members
import "Polar.js" as Polar

// One screen's painting of a ScopeModel (the sound as points, rays or
// waves), on a single Canvas with additive light, so dense places glow
// brighter, like iZotope Ozone's imager. It computes nothing: the model is
// shared by every screen, this only paints it at its own size, when the
// model has something new. The half circle is cut into sectors, one per arc
// of the scope (listening together, D277): each in its own color, as big as
// that output is heard, blending into its neighbour's size where they meet.
Item {
    id: vis

    required property var model
    property real centerX: 0
    property real centerY: 0
    property real radius: 0
    // The sectors, left to right, at least one (each { color, scale, quiet }):
    // its color, its size next to the loudest (1), and whether it is muted,
    // where the picture dims instead of vanishing, the sound still flows
    property var sectors: [
        {
            "color": "white",
            "scale": 1,
            "quiet": false
        }
    ]
    // The color the center blends toward
    property color color2: "white"
    // Additive light (dark screen), or plain paint (light screen)
    property bool additive: true

    readonly property real _r: radius * Polar.scaleFor(model.heard)
    readonly property int waveSteps: 72

    // Hidden, nothing is painted; shown again, the latest picture at once
    Connections {
        target: vis.model
        function onUpdated() {
            if (vis.visible)
                canvas.requestPaint();
        }
    }
    onVisibleChanged: if (visible)
        canvas.requestPaint()

    readonly property var _scales: sectors.map(t => t.scale)
    onSectorsChanged: if (visible)
        canvas.requestPaint()

    // A muted sector keeps a faint picture
    function _dim(sector) {
        return sector.quiet ? 0.32 : 1;
    }
    // The sector an angle falls in, and how far the picture reaches there
    function _sector(deg) {
        return sectors[Polar.sliceAt(deg, sectors.length)];
    }
    function _reachAt(deg) {
        return _r * Members.scaleAt(_scales, (deg - Polar.LEFT) / 180);
    }

    // The wave's outline: the angle and the reach of each step, from left to right
    function _shape(levels) {
        const out = [];
        for (let s = 0; s <= waveSteps; s++) {
            const deg = Polar.LEFT + 2 + s * (176 / waveSteps);
            out.push({
                "deg": deg,
                "dist": Polar.reach(Polar.levelAt(levels, deg), _reachAt(deg))
            });
        }
        return out;
    }

    // Only the half disc the sound can reach, its halos included: every
    // frame clears, paints and uploads this rectangle, not the whole scope
    readonly property real _reach: Math.ceil(radius * 1.15 + 12)

    Canvas {
        id: canvas
        x: Math.floor(vis.centerX - vis._reach)
        y: Math.floor(vis.centerY - vis._reach)
        width: 2 * vis._reach + 1
        height: vis._reach + 13
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
            if (vis.model.alive === 0 || vis.radius <= 0)
                return;
            // Drawn in the scope's coordinates
            ctx.translate(-x, -y);
            ctx.globalCompositeOperation = vis.additive ? "lighter" : "source-over";
            if (vis.model.style === "points")
                drawDots(ctx);
            else if (vis.model.style === "rays")
                drawRays(ctx);
            else if (vis.model.style === "waves")
                drawWaves(ctx);
        }

        // Dots grouped by sector, tone and brightness: a few fills, not one per dot
        function drawDots(ctx) {
            const groups = 5, tones = 3, n = vis.sectors.length;
            const paths = [];
            for (let g = 0; g < n * tones * groups; g++)
                paths.push([]);
            const full = Math.max(0.001, vis.model.radiusFor(1));
            for (let i = 0; i < vis.model.dots.length; i++) {
                const p = vis.model.dots[i];
                const fade = (1 - p.life) * (1 - p.life);
                const g = Math.min(groups - 1, Math.floor(fade * groups));
                const tone = Math.min(tones - 1, Math.floor(p.dist / full * tones));
                paths[(Polar.sliceAt(p.deg, n) * tones + tone) * groups + g].push(p);
            }
            for (let k = 0; k < n; k++) {
                const dim = vis._dim(vis.sectors[k]);
                for (let tone = 0; tone < tones; tone++) {
                    const c = mix(vis.color2, vis.sectors[k].color, tone / (tones - 1));
                    for (let g = 0; g < groups; g++)
                        fillDots(ctx, paths[(k * tones + tone) * groups + g], c, (g + 0.5) / groups * dim);
                }
            }
        }
        // One group of dots: a soft halo first, then the bright core
        function fillDots(ctx, list, c, a) {
            if (!list.length)
                return;
            for (let pass = 0; pass < 2; pass++) {
                ctx.beginPath();
                for (let i = 0; i < list.length; i++) {
                    const p = list[i];
                    const at = xy(p.deg, p.dist * vis.radius * Members.scaleAt(vis._scales, (p.deg - Polar.LEFT) / 180) * (1 + 0.14 * p.life));
                    const r = pass === 0 ? p.size * 1.9 : p.size * 0.62;
                    ctx.moveTo(at[0] + r, at[1]);
                    ctx.arc(at[0], at[1], r, 0, Math.PI * 2);
                }
                ctx.fillStyle = rgba(c, pass === 0 ? a * 0.16 : a);
                ctx.fill();
            }
        }

        function drawRays(ctx) {
            const angles = Polar.rayAngles(vis.model.raysPerSide);
            ctx.lineCap = "round";
            for (let k = 0; k < angles.length; k++) {
                const R = vis._reachAt(angles[k]);
                const base = Polar.reach(0, R);
                const w = Math.max(1.5, R * 87 / vis.model.raysPerSide * Math.PI / 180 * 0.22);
                const sector = vis._sector(angles[k]);
                const dim = vis._dim(sector);
                const v = Polar.levelAt(vis.model.levels, angles[k]);
                const end = Polar.reach(v, R);
                const from = xy(angles[k], base), to = xy(angles[k], end);
                const grad = ctx.createLinearGradient(from[0], from[1], to[0], to[1]);
                grad.addColorStop(0, rgba(vis.color2, 0.25 * dim));
                const tint = sector.color;
                grad.addColorStop(1, rgba(mix(vis.color2, tint, v), 0.95 * dim));
                for (let pass = 0; pass < 2; pass++) {
                    ctx.beginPath();
                    ctx.moveTo(from[0], from[1]);
                    ctx.lineTo(to[0], to[1]);
                    ctx.lineWidth = pass === 0 ? w * 2.6 : w;
                    ctx.strokeStyle = pass === 0 ? rgba(tint, 0.07 * dim * (0.3 + v)) : grad;
                    ctx.stroke();
                }
                // The peak mark, a dot past the ray
                const pk = Polar.reach(vis.model.peaks[k] || 0, R) + w * 1.6;
                const at = xy(angles[k], pk);
                ctx.beginPath();
                ctx.arc(at[0], at[1], w * 0.5, 0, Math.PI * 2);
                ctx.fillStyle = rgba(tint, 0.9 * dim);
                ctx.fill();
            }
        }

        // Through the points on curves (each corner rounded to the middle of
        // its neighbours), so the wave has no sharp edge
        function outline(ctx, pts) {
            ctx.beginPath();
            ctx.moveTo(pts[0][0], pts[0][1]);
            for (let s = 1; s < pts.length - 1; s++)
                ctx.quadraticCurveTo(pts[s][0], pts[s][1], (pts[s][0] + pts[s + 1][0]) / 2, (pts[s][1] + pts[s + 1][1]) / 2);
            const last = pts[pts.length - 1];
            ctx.lineTo(last[0], last[1]);
        }
        // The live wave, sector by sector so each has its own color: a soft
        // fill down to the center, a glow, a line. A sector's outline ends on
        // the first point of the next, so they meet without a gap.
        function drawWaves(ctx) {
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            const shape = vis._shape(vis.model.levels);
            const pts = shape.map(q => xy(q.deg, q.dist));
            const n = vis.sectors.length;
            for (let k = 0; k < n; k++) {
                const own = shape.map((q, i) => Polar.sliceAt(q.deg, n) === k ? i : -1).filter(i => i >= 0);
                if (!own.length)
                    continue;
                const part = pts.slice(own[0], Math.min(pts.length, own[own.length - 1] + 2));
                if (part.length < 2)
                    continue;
                const sector = vis.sectors[k];
                const dim = vis._dim(sector);
                outline(ctx, part);
                ctx.lineTo(vis.centerX, vis.centerY);
                ctx.closePath();
                const fill = ctx.createRadialGradient(vis.centerX, vis.centerY, 0, vis.centerX, vis.centerY, Math.max(1, vis._r));
                fill.addColorStop(0, rgba(vis.color2, 0.22 * dim));
                fill.addColorStop(1, rgba(sector.color, 0.04 * dim));
                ctx.fillStyle = fill;
                ctx.fill();
                for (let pass = 0; pass < 2; pass++) {
                    outline(ctx, part);
                    // A thin line over a faint, wider glow
                    ctx.lineWidth = pass === 0 ? Math.max(3, vis._r * 0.035) : 1.25;
                    ctx.strokeStyle = rgba(sector.color, (pass === 0 ? 0.08 : 0.9) * dim);
                    ctx.stroke();
                }
            }
        }
    }
}
