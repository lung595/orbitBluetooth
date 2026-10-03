import QtQuick
import "Polar.js" as Polar

// One screen's painting of a ScopeModel (the sound as points, rays or
// waves), on a single Canvas with additive light, so dense places glow
// brighter, like iZotope Ozone's imager. It computes nothing: the model is
// shared by every screen, this only paints it at its own size, when the
// model has something new.
Item {
    id: vis

    required property var model
    property real centerX: 0
    property real centerY: 0
    property real radius: 0
    // The outer color, and the one the center blends toward
    property color color: "white"
    property color color2: "white"
    // Muted: the picture dims instead of vanishing, the sound still flows
    property bool quiet: false
    // Additive light (dark screen), or plain paint (light screen)
    property bool additive: true

    readonly property real _r: radius * Polar.scaleFor(model.heard)
    readonly property int waveSteps: 72

    Connections {
        target: vis.model
        function onUpdated() {
            if (vis.visible)
                canvas.requestPaint();
        }
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
            const dim = vis.quiet ? 0.32 : 1;
            if (vis.model.style === "points")
                drawDots(ctx, dim);
            else if (vis.model.style === "rays")
                drawRays(ctx, dim);
            else if (vis.model.style === "waves")
                drawWaves(ctx, dim);
        }

        // Dots grouped by color and brightness: a few fills, not one per dot
        function drawDots(ctx, dim) {
            const groups = 5, tones = 3;
            const paths = [];
            for (let g = 0; g < groups * tones; g++)
                paths.push([]);
            for (let i = 0; i < vis.model.dots.length; i++) {
                const p = vis.model.dots[i];
                const fade = (1 - p.life) * (1 - p.life);
                const g = Math.min(groups - 1, Math.floor(fade * groups));
                const tone = Math.min(tones - 1, Math.floor(p.dist / Math.max(0.001, vis.model.radiusFor(1)) * tones));
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
                            const at = xy(p.deg, p.dist * vis.radius * (1 + 0.14 * p.life));
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
            const angles = Polar.rayAngles(vis.model.raysPerSide);
            const R = vis._r;
            const base = Polar.reach(0, R);
            const w = Math.max(1.5, R * 87 / vis.model.raysPerSide * Math.PI / 180 * 0.22);
            ctx.lineCap = "round";
            for (let k = 0; k < angles.length; k++) {
                const v = Polar.levelAt(vis.model.levels, angles[k]);
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
                const pk = Polar.reach(vis.model.peaks[k] || 0, R) + w * 1.6;
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
            const shape = vis._shape(vis.model.levels);
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
