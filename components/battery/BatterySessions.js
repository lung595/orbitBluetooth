.pragma library

// Battery sessions, the low-battery decision, the autonomy estimate and the
// history file's content. Pure functions, no clock and no I/O of their own:
// every time is passed in, so nothing here runs unless a reading arrives
// (value 6). BatteryHistoryStore.qml is the only code that touches the disk.

var THRESHOLDS = [10, 15, 20, 30];
var DEFAULT_THRESHOLD = 20;
// Fewer usable sessions than this and the answer is "unknown", never a guess
var MIN_SESSIONS = 3;
// Only the latest sessions count: a worn battery drains faster than an old one
var RECENT_SESSIONS = 10;
var KEEP_MS = 365 * 24 * 3600 * 1000;
// A discharge with no reading for this long is cut, since what happened in between is unknown
var MAX_GAP_MS = 2 * 3600 * 1000;
// A session is usable for the estimate only if it lasted and dropped enough to measure a rate
var MIN_USABLE_MS = 30 * 60 * 1000;
var MIN_USABLE_DROP = 5;
// Bounds the file whatever a device does
var MAX_SESSIONS_PER_DEVICE = 200;
var MAX_DEVICES = 64;
// A clock set slightly ahead is tolerated; further than this a time is not believed
var FUTURE_SLACK_MS = 24 * 3600 * 1000;

// ---- Sessions ------------------------------------------------------------

function newTracker() {
    return { open: null };
}

function _close(open) {
    var s = { start: open.start, end: open.lastAt, from: open.from, to: open.lastLevel };
    return s.end > s.start ? s : null;
}

function _begin(r) {
    return { start: r.at, lastAt: r.at, from: r.level, lastLevel: r.level };
}

// Feeds one reading { at: ms, level: 0..100 or null when unknown, charging: bool }.
// Returns { tracker, ended } where `ended` is a finished session or null.
// A session is one stretch of discharge: it ends on charging, on a gap with no
// reading, on a level that went up while not charging, on a clock that went
// backwards, or on disconnect().
function feed(tracker, reading) {
    var open = tracker.open;
    var at = reading.at;
    var level = reading.level;
    if (typeof at !== "number" || !isFinite(at))
        return { tracker: tracker, ended: null };
    // Missing reading: say nothing, keep waiting (the gap rule cuts it later)
    if (typeof level !== "number" || !isFinite(level) || level < 0 || level > 100)
        return { tracker: tracker, ended: null };

    var ended = null;
    if (open) {
        var cut = reading.charging || at < open.lastAt || at - open.lastAt > MAX_GAP_MS || level > open.lastLevel;
        if (cut) {
            ended = _close(open);
            open = null;
        }
    }
    if (reading.charging)
        return { tracker: { open: null }, ended: ended };
    if (!open)
        return { tracker: { open: _begin(reading) }, ended: ended };
    return { tracker: { open: { start: open.start, from: open.from, lastAt: at, lastLevel: level } }, ended: ended };
}

// The device went away: its session ends at the last reading
function disconnect(tracker) {
    return { tracker: { open: null }, ended: tracker.open ? _close(tracker.open) : null };
}

function usable(s) {
    return !!s && s.end - s.start >= MIN_USABLE_MS && s.from - s.to >= MIN_USABLE_DROP;
}

// ---- Autonomy ------------------------------------------------------------

// Remaining time from the device's own sessions: the pooled drain rate of the
// latest usable ones. { known: false } below MIN_SESSIONS usable sessions.
function estimate(sessions, level) {
    var good = (sessions || []).filter(usable).slice(-RECENT_SESSIONS);
    if (good.length < MIN_SESSIONS || typeof level !== "number" || level <= 0)
        return { known: false };
    var drop = 0, ms = 0;
    good.forEach(function (s) {
        drop += s.from - s.to;
        ms += s.end - s.start;
    });
    var perHour = drop / (ms / 3600000);
    return { known: true, minutes: Math.round(level / perHour * 60), sessions: good.length };
}

// ---- Low battery ---------------------------------------------------------

// Percent above the threshold at which a discharge counts as over
var REARM_MARGIN = 5;

function thresholdOf(value) {
    return THRESHOLDS.indexOf(value) >= 0 ? value : DEFAULT_THRESHOLD;
}

function newAlert() {
    return { armed: true };
}

// One decision per discharge: { alert, fire }. It fires once when the level
// reaches the threshold while discharging, then stays quiet however many times
// the level crosses it again; a charge re-arms it, and so does a level well
// above the threshold (a headset charged in its case never reports charging,
// while a 19 -> 22 -> 18 jitter around the threshold stays one alert). With Do not disturb on
// it neither fires nor disarms, so the warning still comes once DND is off.
// The notification itself is silent (the caller sends it without a sound).
function lowBattery(alert, level, charging, threshold, dnd) {
    var limit = thresholdOf(threshold);
    if (charging || (typeof level === "number" && level >= limit + REARM_MARGIN))
        return { alert: { armed: true }, fire: false };
    if (typeof level !== "number" || !alert.armed || level > limit || dnd)
        return { alert: alert, fire: false };
    return { alert: { armed: false }, fire: true };
}

// ---- Device key ----------------------------------------------------------

function _rotr(x, n) {
    return (x >>> n) | (x << (32 - n));
}

var _K = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];

// SHA-256 of an string encoded to UTF-8 bytes (BMP only); QML has no crypto module
function sha256(text) {
    var bytes = [];
    for (var i = 0; i < text.length; i++) {
        var c = text.charCodeAt(i);
        if (c < 128) {
            bytes.push(c);
        } else {
            bytes.push(0xc0 | (c >> 6), 0x80 | (c & 63));
            if (c > 0x7ff)
                bytes.splice(bytes.length - 2, 2, 0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
        }
    }
    var bits = bytes.length * 8;
    bytes.push(0x80);
    while (bytes.length % 64 !== 56)
        bytes.push(0);
    for (var b = 7; b >= 0; b--)
        bytes.push(b > 3 ? 0 : (bits >>> (b * 8)) & 255);
    var h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    for (var o = 0; o < bytes.length; o += 64) {
        var w = [];
        for (var t = 0; t < 16; t++)
            w[t] = (bytes[o + t * 4] << 24) | (bytes[o + t * 4 + 1] << 16) | (bytes[o + t * 4 + 2] << 8) | bytes[o + t * 4 + 3];
        for (t = 16; t < 64; t++) {
            var s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
            var s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
            w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0;
        }
        var v = h.slice();
        for (t = 0; t < 64; t++) {
            var S1 = _rotr(v[4], 6) ^ _rotr(v[4], 11) ^ _rotr(v[4], 25);
            var t1 = (v[7] + S1 + ((v[4] & v[5]) ^ (~v[4] & v[6])) + _K[t] + w[t]) | 0;
            var S0 = _rotr(v[0], 2) ^ _rotr(v[0], 13) ^ _rotr(v[0], 22);
            var t2 = (S0 + ((v[0] & v[1]) ^ (v[0] & v[2]) ^ (v[1] & v[2]))) | 0;
            v = [(t1 + t2) | 0, v[0], v[1], v[2], (v[3] + t1) | 0, v[4], v[5], v[6]];
        }
        for (t = 0; t < 8; t++)
            h[t] = (h[t] + v[t]) | 0;
    }
    return h.map(function (x) {
        return ("00000000" + (x >>> 0).toString(16)).slice(-8);
    }).join("");
}

// A device's key in the file: the address never appears, only this digest
// (first 16 hex digits), which the per-install salt makes useless elsewhere.
function deviceKey(salt, address) {
    return sha256(salt + "|" + String(address).toUpperCase()).slice(0, 16);
}

// ---- History file --------------------------------------------------------

// `random` is a function returning [0, 1), passed in to keep this module pure
function newHistory(random) {
    var salt = "";
    for (var i = 0; i < 4; i++)
        salt += ("00000000" + Math.floor(random() * 4294967296).toString(16)).slice(-8);
    return { v: 1, salt: salt, devices: {} };
}

function _num(x) {
    return typeof x === "number" && isFinite(x);
}

function _cleanSession(s) {
    return Array.isArray(s) && s.length === 4 && s.every(_num) && s[1] > s[0] && s[2] >= s[3] && s[2] <= 100 && s[3] >= 0;
}

// Reads the file's text. Anything wrong (empty, truncated, edited by hand)
// starts a clean history: nothing here may crash the plugin.
function parse(text, random) {
    var data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return newHistory(random);
    }
    if (!data || data.v !== 1 || typeof data.salt !== "string" || !/^[0-9a-f]{32}$/.test(data.salt)
            || !data.devices || typeof data.devices !== "object" || Array.isArray(data.devices))
        return newHistory(random);
    var clean = { v: 1, salt: data.salt, devices: {} };
    Object.keys(data.devices).slice(0, MAX_DEVICES).forEach(function (key) {
        var d = data.devices[key];
        if (!/^[0-9a-f]{16}$/.test(key) || !d || !_num(d.seen))
            return;
        clean.devices[key] = { seen: d.seen, sessions: Array.isArray(d.sessions) ? d.sessions.filter(_cleanSession).slice(-MAX_SESSIONS_PER_DEVICE) : [] };
    });
    return clean;
}

// The command that stores serialized history on its standard input: umask 077
// makes the folder 0700 and the file 0600; paths are positional parameters,
// never part of the shell string, and the rename keeps the old file whole
// until the new one is complete.
function writeCommand(folder, file) {
    return ["sh", "-c", "umask 077; mkdir -p -- \"$1\" && cat > \"$2.tmp\" && mv -f -- \"$2.tmp\" \"$2\"", "sh", folder, file];
}

function eraseCommand(file) {
    return ["rm", "-f", "--", file, file + ".tmp"];
}

function serialize(history) {
    return JSON.stringify(history);
}

// Drops what is older than 12 months, devices not seen for 12 months included
function prune(history, now) {
    var cutoff = now - KEEP_MS;
    var devices = {};
    Object.keys(history.devices).forEach(function (key) {
        var d = history.devices[key];
        if (d.seen < cutoff)
            return;
        devices[key] = { seen: d.seen, sessions: d.sessions.filter(function (s) {
            return s[1] >= cutoff;
        }) };
    });
    return { v: 1, salt: history.salt, devices: devices };
}

// Adds a finished session ([start, end, from, to] in the file) and marks the
// device seen. A time from the future, or a session that ends before it
// starts (clock set back), is not stored. Returns a new history, pruned.
function record(history, key, session, now) {
    var seen = history.devices[key] ? history.devices[key].seen : 0;
    var sessions = history.devices[key] ? history.devices[key].sessions.slice() : [];
    var row = [session.start, session.end, session.from, session.to];
    if (_cleanSession(row) && session.end <= now + FUTURE_SLACK_MS) {
        sessions.push(row);
        seen = Math.max(seen, session.end);
    }
    var devices = {};
    Object.keys(history.devices).forEach(function (k) {
        devices[k] = history.devices[k];
    });
    if (!devices[key] && Object.keys(devices).length >= MAX_DEVICES)
        return prune(history, now);
    devices[key] = { seen: seen, sessions: sessions.slice(-MAX_SESSIONS_PER_DEVICE) };
    return prune({ v: 1, salt: history.salt, devices: devices }, now);
}

// The device was just seen (connected or last reading); `at` in the future is ignored
function touch(history, key, at, now) {
    if (!_num(at) || at > now + FUTURE_SLACK_MS)
        return history;
    var d = history.devices[key] || { seen: 0, sessions: [] };
    if (!history.devices[key] && Object.keys(history.devices).length >= MAX_DEVICES)
        return history;
    var devices = {};
    Object.keys(history.devices).forEach(function (k) {
        devices[k] = history.devices[k];
    });
    devices[key] = { seen: Math.max(d.seen, at), sessions: d.sessions };
    return { v: 1, salt: history.salt, devices: devices };
}

function lastSeen(history, key) {
    return history.devices[key] ? history.devices[key].seen : 0;
}

// The device's sessions in the shape feed() and estimate() use
function sessionsOf(history, key) {
    return history.devices[key] ? history.devices[key].sessions.map(function (r) {
        return { start: r[0], end: r[1], from: r[2], to: r[3] };
    }) : [];
}
