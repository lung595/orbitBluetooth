.pragma library

// Charge analysis for one device. Pure: fed by the daemon's battery log
// ([[epochMs, percent], ...] since connection) and, when the system knows it,
// the UPower record ({ state, timeToFull, timeToEmpty, changeRate, health }).
//
// BlueZ only reports a percentage, so without UPower state the charging flag
// is inferred from a rising level; times are then estimates (source
// "estimated") and account for the usual Li-ion slowdown past 80%.

const UP_CHARGING = 1, UP_DISCHARGING = 2, UP_EMPTY = 3, UP_FULL = 4, UP_PENDING_CHARGE = 5, UP_PENDING_DISCHARGE = 6;

// A rise is only trusted as "still charging" for this long without a new step
const STALE_MS = 25 * 60000;
const TAPER_FROM = 80;      // percent
const TAPER_FACTOR = 0.55;  // speed above TAPER_FROM relative to below

function _minutesToFull(level, perMin) {
    if (!(perMin > 0) || level >= 100)
        return 0;
    // perMin is measured on the current segment; convert it to the base rate
    const base = level >= TAPER_FROM ? perMin / TAPER_FACTOR : perMin;
    const low = Math.max(0, TAPER_FROM - level);
    const high = 100 - Math.max(level, TAPER_FROM);
    return low / base + high / (base * TAPER_FACTOR);
}

// Trailing run of non-decreasing samples that contains at least one rise
function _risingRun(samples) {
    let i = samples.length - 1;
    while (i > 0 && samples[i - 1][1] <= samples[i][1])
        i--;
    const run = samples.slice(i);
    return run.length >= 2 && run[run.length - 1][1] > run[0][1] ? run : null;
}

// `ratedHours` (optional): the device's rated life on a full charge, used
// for a first time-left estimate until the real drain can be measured.
function analyze(samples, level, up, now, ratedHours) {
    const out = {
        state: "unknown",       // "charging" | "full" | "discharging" | "unknown"
        source: "none",         // "system" | "estimated" | "rated" | "none"
        minutesToFull: 0,
        minutesLeft: 0,
        fullAt: 0,              // epoch ms
        ratePerHour: 0,         // percent per hour, signed
        watts: 0,
        since: 0,               // start of the current charge (epoch ms)
        gained: 0,              // percent gained during this charge
        health: -1
    };
    samples = samples || [];
    if (up) {
        if (up.health > 0)
            out.health = Math.round(up.health);
        if (up.changeRate > 0)
            out.watts = up.changeRate;
    }

    const run = _risingRun(samples);
    if (run) {
        const a = run[0], b = run[run.length - 1];
        const minutes = (b[0] - a[0]) / 60000;
        out.since = a[0];
        out.gained = b[1] - a[1];
        if (minutes >= 1)
            out.ratePerHour = out.gained / minutes * 60;
    }

    const upState = up ? up.state : 0;
    if (upState === UP_CHARGING || upState === UP_PENDING_CHARGE) {
        out.state = "charging";
        out.source = "system";
    } else if (upState === UP_FULL) {
        out.state = "full";
        out.source = "system";
    } else if (upState === UP_DISCHARGING || upState === UP_PENDING_DISCHARGE || upState === UP_EMPTY) {
        out.state = "discharging";
        out.source = "system";
    } else if (run && level >= 0) {
        const last = run[run.length - 1];
        if (level >= 100) {
            out.state = "full";
            out.source = "estimated";
        } else if (now - last[0] < STALE_MS) {
            out.state = "charging";
            out.source = "estimated";
        }
    }

    if (out.state === "charging") {
        if (up && up.timeToFull > 0)
            out.minutesToFull = up.timeToFull / 60;
        else if (out.ratePerHour > 0) {
            const last = samples[samples.length - 1];
            const elapsed = last ? (now - last[0]) / 60000 : 0;
            out.minutesToFull = Math.max(1, _minutesToFull(level, out.ratePerHour / 60) - elapsed);
        }
        if (out.minutesToFull > 0)
            out.fullAt = now + out.minutesToFull * 60000;
        if (!out.since && samples.length)
            out.since = samples[0][0];
    } else if (out.state !== "full") {
        out.gained = 0;
        out.since = 0;
        out.ratePerHour = 0;
        if (up && up.timeToEmpty > 0)
            out.minutesLeft = up.timeToEmpty / 60;
        else if (samples.length >= 2 && level > 0) {
            const a = samples[0], b = samples[samples.length - 1];
            const minutes = (b[0] - a[0]) / 60000;
            const drop = a[1] - b[1];
            if (drop >= 2 && minutes >= 3) {
                out.ratePerHour = -drop / minutes * 60;
                out.minutesLeft = level / (drop / minutes);
                // Coarse steps (10% on many headsets) make a short measure
                // unreliable: lean on the rated life for the first 90 min
                if (ratedHours > 0) {
                    const w = Math.min(1, minutes / 90);
                    out.minutesLeft = w * out.minutesLeft + (1 - w) * level / 100 * ratedHours * 60;
                }
                if (out.source === "none") {
                    out.source = "estimated";
                    out.state = "discharging";
                }
            }
        }
        // Nothing measured yet: level x rated life (always shown with "≈")
        if (!(out.minutesLeft > 0) && ratedHours > 0 && level > 0 && out.state !== "charging") {
            out.minutesLeft = level / 100 * ratedHours * 60;
            if (out.source === "none")
                out.source = "rated";
        }
    }
    return out;
}

function formatMinutes(m) {
    if (!(m > 0) || !isFinite(m))
        return "";
    if (m < 1)
        return "< 1 min";
    if (m < 60)
        return Math.round(m) + " min";
    const h = Math.floor(m / 60), r = Math.round(m % 60);
    return r > 0 ? h + " h " + (r < 10 ? "0" : "") + r : h + " h";
}

function formatShort(m) {
    if (!(m > 0) || !isFinite(m))
        return "";
    // Days for long-lasting devices (mice, controllers): "3d"
    if (m >= 48 * 60)
        return Math.round(m / 1440) + "d";
    if (m < 60)
        return Math.max(1, Math.round(m)) + "m";
    const h = Math.floor(m / 60), r = Math.round(m % 60);
    return h + "h" + (r < 10 ? "0" : "") + r;
}

function formatClock(ms) {
    if (!(ms > 0))
        return "";
    const d = new Date(ms);
    const p = v => (v < 10 ? "0" : "") + v;
    return p(d.getHours()) + ":" + p(d.getMinutes());
}

// Aurora ramp shared by every battery visual: red when critical, through
// amber and gold, to lime and a cool aqua when full.
const RAMP = [[0, [255, 84, 104]], [15, [255, 84, 104]], [30, [255, 159, 67]], [50, [255, 214, 92]], [72, [184, 240, 106]], [100, [92, 242, 196]]];

function levelColor(level) {
    const l = Math.max(0, Math.min(100, level));
    for (let i = 1; i < RAMP.length; i++) {
        if (l <= RAMP[i][0]) {
            const a = RAMP[i - 1], b = RAMP[i];
            const t = b[0] === a[0] ? 0 : (l - a[0]) / (b[0] - a[0]);
            const c = a[1].map((v, k) => Math.round(v + (b[1][k] - v) * t));
            return "#" + c.map(v => (v < 16 ? "0" : "") + v.toString(16)).join("");
        }
    }
    return "#5cf2c4";
}
