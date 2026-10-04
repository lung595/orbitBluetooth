.pragma library

// Motion maths of the orbit scene: where each body wants to be, and the
// damped spring that takes it there. Pure functions of a geometry `g` (the
// scene itself: cx, cy, rx, ry, ringCy, ringRy, innerNorm, snapNorm,
// detachNorm, outerMinNorm, bodySize, coreSize, holeX, holeY, holeHorizon); they
// change only the body handed to spring() and the target handed to
// separate(). Tested by tests/*.test.js.

// Critically-tuned spring step: k is the stiffness, zeta the damping ratio
// (1 = no overshoot, used with Reduce motion)
function spring(b, tx, ty, k, zeta, dt) {
    const c = 2 * zeta * Math.sqrt(k);
    b.vx += (k * (tx - b.px) - c * b.vx) * dt;
    b.vy += (k * (ty - b.py) - c * b.vy) * dt;
    b.px += b.vx * dt;
    b.py += b.vy * dt;
}

// Normalised elliptic distance from the scene center (1 = the outer belt)
function norm(g, x, y) {
    return Math.hypot((x - g.cx) / g.rx, (y - g.cy) / g.ry);
}

// Slot i of n on the connected ring; depth > 0 on the near side
function ringSlot(g, i, n, phase) {
    const a = phase + (i / Math.max(1, n)) * Math.PI * 2;
    return {
        "x": g.cx + Math.cos(a) * g.rx * g.innerNorm,
        "y": g.ringCy + Math.sin(a) * g.ringRy,
        "depth": Math.sin(a)
    };
}

// Slot i of n in the outer belt at radius r (normalised), skewed by the
// body's own hash and floating by `amp` px on the time-driven clock
function beltSlot(g, i, n, phase, hash, r, clock, amp) {
    const a = phase + ((i + 0.5) / Math.max(1, n)) * Math.PI * 2 + (hash - 0.5) * 0.35;
    const ph = hash * 40;
    return {
        "x": g.cx + Math.cos(a) * g.rx * r + Math.sin(clock * 0.8 + ph) * amp,
        "y": g.cy + Math.sin(a) * g.ry * r + Math.cos(clock * 0.63 + ph) * amp * 0.8
    };
}

// Belt radius for a signal strength (0..1): the stronger, the closer
function beltRadius(g, signal) {
    return 1 - (1 - g.outerMinNorm) * Math.min(1, signal);
}

// A dragged body follows the pointer, pulled toward the connected ring
// (elastic while it tears a connected device free, a magnet when it brings
// a new one in) and, over that, into the black hole when aimed at it
function dragTarget(g, b, x, y) {
    const t = {
        "x": x,
        "y": y,
        "k": 700,
        "zeta": 0.85
    };
    const nrm = norm(g, x, y);
    // Nearest point on the connected ring, at the pointer's angle
    const ang = Math.atan2((y - g.ringCy) / g.ringRy, (x - g.cx) / (g.rx * g.innerNorm));
    const sx = g.cx + Math.cos(ang) * g.rx * g.innerNorm;
    const sy = g.ringCy + Math.sin(ang) * g.ringRy;
    let pull = 0;
    if (b.holding) {
        // Elastic resistance: gravity holds it until it tears free
        pull = b.armed ? 0.08 : Math.max(0, 0.5 - (nrm - g.innerNorm) * 1.4);
    } else if (b.armed) {
        // Magnet: the closer it gets, the harder the ring pulls
        const s = Math.min(1, Math.max(0, (g.snapNorm - nrm) / (g.snapNorm - g.innerNorm * 0.6)));
        pull = 0.45 + 0.4 * s * s * (3 - 2 * s);
        t.k = 380;
        t.zeta = 0.62;
    }
    t.x += (sx - t.x) * pull;
    t.y += (sy - t.y) * pull;
    if (b.hideArmed) {
        t.x += (g.holeX - t.x) * 0.55;
        t.y += (g.holeY - t.y) * 0.55;
        t.k = 420;
        t.zeta = 0.7;
    }
    return t;
}

// What dropping a body held at (x, y) would do. Over the black hole it
// wins over connecting or disconnecting (hide); otherwise a connected body
// (holding) arms past the tear point and a free one inside the magnet.
// feed (0..1) is how much the hole glows as the body nears it.
function dragArm(g, holding, x, y) {
    const hd = Math.hypot(x - g.holeX, y - g.holeY);
    const hide = hd < Math.max(g.holeHorizon * 2.4, g.bodySize * 0.75);
    const n = norm(g, x, y);
    return {
        "hide": hide,
        "armed": hide ? false : holding ? n > g.detachNorm : n < g.snapNorm,
        "feed": Math.max(0, Math.min(1, 1 - (hd - g.bodySize * 0.6) / (g.bodySize * 1.6)))
    };
}

// Pushes target t away from the other bodies (harder from the dragged one),
// out of the host core (unless the body rides the ring, which passes behind
// it) and out of the black hole, which only takes what is dropped in.
// `focusOpen`: a detail card is open, bodies may overlap the center.
function separate(g, b, t, all, focusOpen) {
    for (const o of all) {
        if (o === b || o.leaving)
            continue;
        const dx = b.px - o.px, dy = b.py - o.py;
        const d = Math.max(0.001, Math.hypot(dx, dy));
        const R = o.dragging ? g.bodySize * 2.1 : g.bodySize * 1.05;
        if (d < R) {
            const push = (R - d) / R * (o.dragging ? 30 : 12);
            t.x += dx / d * push;
            t.y += dy / d * push;
        }
    }
    if (focusOpen)
        return;
    const cd = Math.max(0.001, Math.hypot(t.x - g.cx, t.y - g.cy));
    const minD = g.coreSize * 0.5 + g.bodySize * 0.55;
    if (cd < minD && !b.inSlot) {
        t.x = g.cx + (t.x - g.cx) / cd * minD;
        t.y = g.cy + (t.y - g.cy) / cd * minD;
    }
    const hd = Math.max(0.001, Math.hypot(t.x - g.holeX, t.y - g.holeY));
    const holeD = g.holeHorizon * 2.2 + g.bodySize * 0.6;
    if (hd < holeD) {
        t.x = g.holeX + (t.x - g.holeX) / hd * holeD;
        t.y = g.holeY + (t.y - g.holeY) / hd * holeD;
    }
}

// True while a body is still visibly on its way (speed or distance > 0.6 px)
function moving(b, tx, ty) {
    return Math.abs(b.vx) + Math.abs(b.vy) > 0.6 || Math.abs(tx - b.px) + Math.abs(ty - b.py) > 0.6;
}
