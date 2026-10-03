.pragma library

// Smart volume steps (D264): one press on its own moves the level by a
// fine step, for precision; presses close together (or a held key, which
// repeats) make the step grow exponentially up to a ceiling, so a big
// change takes a second, not twenty presses. Quiet levels always move
// finely: a percent there is a big change in loudness.
// Pure: the caller keeps `state` between presses.

// How fast the step grows. fine: the first step (percent); max: the
// ceiling; ramp: presses in a row for the step to double
var SPEEDS = {
    "gentle": { "fine": 1, "max": 4, "ramp": 6 },
    "balanced": { "fine": 1, "max": 8, "ramp": 4 },
    "fast": { "fine": 2, "max": 12, "ramp": 3 }
};
// Presses further apart than this start over from the fine step
var WINDOW_MS = 350;
// Under this level, steps stay fine
var QUIET = 0.1;

function speedOf(name) {
    return SPEEDS[name] ? name : "balanced";
}

// The step (in percent) for a press at `now` (ms) going `dir` (+1 / -1),
// and the state to keep for the next press
function next(state, now, dir, speed, level) {
    const s = SPEEDS[speedOf(speed)];
    const close = state && state.dir === dir && now - state.last >= 0 && now - state.last <= WINDOW_MS;
    const streak = close ? state.streak + 1 : 0;
    let step = Math.min(s.max, Math.round(s.fine * Math.pow(2, streak / s.ramp)));
    // Going down into the quiet part, or moving inside it: fine
    const lv = Math.max(0, Math.min(1, Number(level) || 0));
    if (lv < QUIET || (dir < 0 && lv - step / 100 < QUIET))
        step = Math.min(step, s.fine);
    return { "step": step, "state": { "last": now, "dir": dir, "streak": streak } };
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
