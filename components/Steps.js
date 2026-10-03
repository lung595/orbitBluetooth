.pragma library

// Smart volume steps (D264): the step follows the time between presses,
// on a continuous curve. Presses far apart move by 1 % (the longer the
// pause, the finer, down to 1 %); presses close together, or a held key
// (which repeats), move by more, up to a ceiling. The curve is exponential
// (each bit faster multiplies the step, it never jumps from 1 to 8), and
// the time between presses is smoothed, so an uneven rhythm does not
// make the step swing. Quiet levels always move by 1 %: a percent there
// is a big change in loudness.
// Pure: the caller keeps `state` between presses.

// max: the step (percent) at full speed; fast / slow: the time between
// presses (ms) giving the biggest step / back to 1 %
var SPEEDS = {
    "gentle": { "max": 4, "fast": 60, "slow": 600 },
    "balanced": { "max": 6, "fast": 50, "slow": 450 },
    "fast": { "max": 10, "fast": 40, "slow": 350 }
};
var FINE = 1;
// Under this level, steps stay fine
var QUIET = 0.1;

function speedOf(name) {
    return SPEEDS[name] ? name : "balanced";
}

// The step (percent) for a time between presses `gap` (ms), smoothed
function stepAt(gap, speed) {
    const s = SPEEDS[speedOf(speed)];
    const t = Math.max(0, Math.min(1, (gap - s.fast) / (s.slow - s.fast)));
    // From max (t = 0) to FINE (t = 1), evenly on a log scale
    return Math.max(FINE, Math.round(s.max * Math.pow(FINE / s.max, t)));
}

// The step (in percent) for a press at `now` (ms) going `dir` (+1 / -1),
// and the state to keep for the next press
function next(state, now, dir, speed, level) {
    const s = SPEEDS[speedOf(speed)];
    const raw = state && state.dir === dir && now >= state.last ? now - state.last : Infinity;
    // A pause, or turning back: start over, finely
    const gap = raw > s.slow * 2 ? s.slow * 2 : (state && isFinite(state.gap) ? state.gap * 0.4 + raw * 0.6 : raw);
    let step = raw > s.slow * 2 ? FINE : stepAt(gap, speed);
    const lv = Math.max(0, Math.min(1, Number(level) || 0));
    if (lv < QUIET || (dir < 0 && lv - step / 100 < QUIET))
        step = FINE;
    return { "step": step, "state": { "last": now, "dir": dir, "gap": gap } };
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
