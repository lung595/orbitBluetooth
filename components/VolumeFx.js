.pragma library

// Pure geometry and physics of the volume ring's effects: the aurora band,
// the stardust and the sound waves. No QML here, so it is tested with gjs
// (tests/anc.test.js). Angles are in degrees, clockwise on screen (y down),
// like Volume.start and Volume.sweep.

function clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

function point(cx, cy, r, deg) {
    const a = deg * Math.PI / 180;
    return { x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r };
}

// Ripple of the aurora at an angle: two slow waves that drift with `phase`,
// so the edge looks like a curtain of light, never like a regular sine.
// Long waves (about 80° and 33°) so the edge stays smooth, never jagged.
function ripple(deg, phase) {
    return Math.sin(deg * 0.08 + phase) + 0.45 * Math.sin(deg * 0.19 - phase * 1.3);
}

// The aurora band: a filled ribbon from `startDeg` along `sweepDeg * level`.
// Its outer and inner edges ripple by up to `amp` px, and both ends taper,
// so it reads as light rather than a solid bar. Returns a closed polygon:
// the outer edge forward, then the inner edge back. Empty below half a
// degree (nothing to draw at 0 %).
function band(cx, cy, radius, thickness, startDeg, sweepDeg, level, phase, amp) {
    const span = sweepDeg * clamp01(level);
    if (span < 0.5)
        return [];
    const n = Math.max(2, Math.ceil(span / 2)); // a point every 2 degrees
    const outer = [];
    const inner = [];
    for (let i = 0; i <= n; i++) {
        const f = i / n;
        const deg = startDeg + span * f;
        // Thin at the start, full along the way, rounded into the moon
        const taper = Math.min(1, 0.35 + f * 4, 0.55 + (1 - f) * 12);
        const half = thickness / 2 * taper;
        outer.push(point(cx, cy, radius + half + ripple(deg, phase) * amp, deg));
        inner.push(point(cx, cy, radius - half + ripple(deg + 40, phase * 0.8) * amp * 0.5, deg));
    }
    return outer.concat(inner.reverse());
}

// The bright filament in the middle of the band
function filament(cx, cy, radius, startDeg, sweepDeg, level, phase, amp) {
    const span = sweepDeg * clamp01(level);
    if (span < 0.5)
        return [];
    const n = Math.max(2, Math.ceil(span / 2));
    const pts = [];
    for (let i = 0; i <= n; i++) {
        const deg = startDeg + span * i / n;
        pts.push(point(cx, cy, radius + ripple(deg + 20, phase * 1.2) * amp * 0.6, deg));
    }
    return pts;
}

// --- Stardust -----------------------------------------------------------------

// How many grains leave the moon this frame: proportional to how fast it
// moves (degrees per second), capped so a wild drag stays light. `carry`
// keeps the fraction for the next frame, so slow moves still emit.
function emission(speedDeg, dt, carry) {
    const rate = Math.min(120, speedDeg * 0.8); // grains per second
    const total = carry + rate * dt;
    const count = Math.floor(total);
    return { count: count, carry: total - count };
}

// A new grain at the moon (angle `deg` on the ring), thrown ahead along the
// way the volume went (`dir` = +1 up, -1 down) and outward, so it leaves the
// band's light before the planet's pull brings it back. `r1`..`r4` are random numbers
// in 0..1, passed in so this stays testable.
function spawn(cx, cy, radius, deg, dir, r1, r2, r3, r4) {
    const p = point(cx, cy, radius, deg);
    const heading = (deg + dir * (55 + (r1 - 0.5) * 60)) * Math.PI / 180;
    const speed = 34 + r2 * 60;
    return {
        x: p.x,
        y: p.y,
        vx: Math.cos(heading) * speed,
        vy: Math.sin(heading) * speed,
        age: 0,
        life: 0.55 + r3 * 0.5, // seconds
        size: 1.1 + r4 * 1.5, // fine dust, not confetti
        twinkle: r1 * 6.28
    };
}

// Moves a grain by `dt` seconds: pulled toward the planet (cx, cy) like a
// small body in its gravity, slowed a little by the planet's thin haze.
// Returns false once it has faded out.
function step(p, dt, cx, cy, gravity) {
    const dx = cx - p.x;
    const dy = cy - p.y;
    const d = Math.max(1, Math.sqrt(dx * dx + dy * dy));
    p.vx += dx / d * gravity * dt;
    p.vy += dy / d * gravity * dt;
    const drag = Math.pow(0.35, dt);
    p.vx *= drag;
    p.vy *= drag;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.age += dt;
    return p.age < p.life;
}

// 0 at birth, 1 at death
function lifeT(p) {
    return clamp01(p.age / p.life);
}

// --- Comet tail ----------------------------------------------------------------

// Where the tail's end is after `dt` seconds: it chases the moon (`target`)
// and closes most of the gap in about a quarter of a second, whatever the
// frame rate, so a fast move leaves a long tail and a still moon none.
function follow(from, to, dt, rate) {
    return to + (from - to) * Math.exp(-rate * dt);
}

// --- Sound waves --------------------------------------------------------------

// A wave leaving the planet: radius and strength after `t` (0..1) of its
// life. Louder volume = wider, brighter wave; the corona (100 %) goes
// further still.
function wave(planetRadius, volume, corona, t) {
    const reach = 8 + 22 * clamp01(volume) + (corona ? 18 : 0);
    const ease = 1 - Math.pow(1 - clamp01(t), 3);
    return {
        radius: planetRadius + reach * ease,
        alpha: (0.25 + 0.55 * clamp01(volume)) * (1 - clamp01(t)) * (corona ? 1.3 : 1),
        width: 1 + 2 * clamp01(volume) * (1 - clamp01(t)) + (corona ? 1.5 : 0)
    };
}
