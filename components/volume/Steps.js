.pragma library

// Smart volume steps (D264), tuned on a real recording of the user's
// presses and wheel notches: a slow notch moves by 1 %, a quick run by
// more, up to a ceiling. Two things keep it precise:
// - momentum: a run must build up (1, 1, 2, 3...), so two or three quick
//   notches to nudge the level never jump;
// - hunting: turning back within a second means the user overshot and is
//   looking for a spot, so the next run stops one step below the ceiling.
// The time between notches is smoothed, so an uneven rhythm does not make
// the step swing. Quiet levels always move by 1 %: a percent there is a
// big change in loudness. Pure: the caller keeps `state` between notches.

// max: the step (percent) at full speed; fast / slow: the time between
// notches (ms) giving the biggest step / back to 1 %; build: how much the
// step may grow per notch of a run
var SPEEDS = {
    "gentle": { "max": 3, "fast": 25, "slow": 300, "build": 0.4 },
    "balanced": { "max": 4, "fast": 25, "slow": 300, "build": 0.5 },
    "fast": { "max": 6, "fast": 20, "slow": 250, "build": 0.7 }
};
var FINE = 1;
// Under this level, steps stay fine
var QUIET = 0.1;
// Turning back sooner than this (ms) is hunting for a spot
var HUNT_MS = 1200;

function speedOf(name) {
    return SPEEDS[name] ? name : "balanced";
}

// The step (percent, unrounded) for a smoothed time between notches `gap`
// (ms): from the ceiling when fast to FINE when slow, evenly on a log scale
function stepAt(gap, speed) {
    const s = SPEEDS[speedOf(speed)];
    const t = Math.max(0, Math.min(1, (gap - s.fast) / (s.slow - s.fast)));
    return s.max * Math.pow(FINE / s.max, t);
}

// The step (in percent) for a notch at `now` (ms) going `dir` (+1 / -1),
// and the state to keep for the next one
function next(state, now, dir, speed, level) {
    const s = SPEEDS[speedOf(speed)];
    const st = state || {};
    const since = isFinite(st.last) && now >= st.last ? now - st.last : Infinity;
    const same = st.dir === dir && since < s.slow * 2;
    // Turning back quickly starts a hunt, which lasts until a pause
    const turned = st.dir === -dir && since < HUNT_MS;
    const hunting = turned || (same && st.hunting === true);
    const gap = same ? st.gap * 0.5 + since * 0.5 : s.slow * 2;
    const run = same ? st.run + 1 : 1;
    const ceiling = hunting ? Math.max(FINE, s.max - 1) : s.max;
    let step = Math.min(stepAt(gap, speed), ceiling, FINE + (run - 1) * s.build);
    step = Math.max(FINE, Math.round(step));
    const lv = Math.max(0, Math.min(1, Number(level) || 0));
    if (lv < QUIET || (dir < 0 && lv - step / 100 < QUIET))
        step = FINE;
    return { "step": step, "state": { "last": now, "dir": dir, "gap": gap, "run": run, "hunting": hunting } };
}

// The new level after a step, landing on whole percents, inside 0..1
function apply(level, dir, step) {
    const now = Math.round(Math.max(0, Math.min(1, Number(level) || 0)) * 100);
    return Math.max(0, Math.min(100, now + dir * step)) / 100;
}

// A fixed step from the settings, 1..10 percent
function fixedStep(value) {
    const n = parseInt(value, 10);
    return isNaN(n) ? 5 : Math.max(1, Math.min(10, n));
}
