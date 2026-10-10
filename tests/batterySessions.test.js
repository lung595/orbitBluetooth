// Battery sessions, low-battery decision, autonomy estimate and history file
// content (components/battery/BatterySessions.js). Run: gjs tests/batterySessions.test.js
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { eq, done } = imports.lib;
const GLib = imports.gi.GLib;

// The shared loader only knows the older feature folders; this module is loaded the same way
const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
const [, bytes] = GLib.file_get_contents(dir + "/components/battery/BatterySessions.js");
const src = new TextDecoder().decode(bytes).replace(".pragma library", "");
const S = new Function(src + "; return { feed, disconnect, usable, estimate, thresholdOf, newTracker, newAlert, lowBattery, sha256, deviceKey, newHistory, parse, serialize, prune, record, touch, lastSeen, sessionsOf, writeCommand, eraseCommand, KEEP_MS, MAX_GAP_MS };")();

const H = 3600000, T0 = Date.UTC(2026, 8, 1, 8, 0, 0);
const rnd = () => 0.5;

// Plays readings [[hours, level, charging?]] and collects the ended sessions
function play(rows, base) {
    let tracker = S.newTracker();
    const ended = [];
    rows.forEach(r => {
        const out = S.feed(tracker, { at: (base || T0) + r[0] * H, level: r[1], charging: !!r[2] });
        tracker = out.tracker;
        if (out.ended)
            ended.push(out.ended);
    });
    return { tracker, ended };
}

// Session cutting
let p = play([[0, 100], [1, 90], [2, 80], [3, 70, true]]);
eq("charging cuts the session at the last discharge reading", p.ended, [{ start: T0, end: T0 + 2 * H, from: 100, to: 80 }]);
eq("charging leaves no open session", p.tracker.open, null);
p = play([[0, 100], [1, 90]]);
eq("a running session is not ended", p.ended, []);
eq("disconnect ends it at the last reading", S.disconnect(p.tracker).ended, { start: T0, end: T0 + H, from: 100, to: 90 });
eq("disconnect with nothing open", S.disconnect(S.newTracker()).ended, null);

// Charging in the middle: two sessions, the charge in between belongs to neither
p = play([[0, 100], [2, 80], [3, 80, true], [4, 95, true], [5, 90], [7, 70]]);
eq("one session before the charge", p.ended.length, 1);
eq("the next starts after the charge", p.tracker.open.start, T0 + 5 * H);
// A level that rises while "not charging" is a charge the system did not report
p = play([[0, 50], [1, 40], [2, 90], [3, 85]]);
eq("a rise cuts the session", p.ended, [{ start: T0, end: T0 + H, from: 50, to: 40 }]);
eq("and a new one starts at the new level", p.tracker.open.from, 90);

// Missing readings
p = play([[0, 100], [1, null], [1.5, undefined], [2, 90]]);
eq("missing readings are skipped, session goes on", [p.ended.length, p.tracker.open.lastLevel], [0, 90]);
p = play([[0, 100], [1, 95], [5, 60]]);
eq("a long silence cuts the session", p.ended, [{ start: T0, end: T0 + H, from: 100, to: 95 }]);
eq("out-of-range levels ignored", play([[0, 120], [1, -3]]).tracker.open, null);

// Clock going backwards
p = play([[0, 100], [2, 90], [1, 85]]);
eq("clock back cuts, never a negative duration", p.ended, [{ start: T0, end: T0 + 2 * H, from: 100, to: 90 }]);
eq("a one-reading session is dropped", play([[0, 100], [3, 99]]).ended, []);

// Usable sessions and the estimate
const sess = (n, drop, hours) => Array.from({ length: n }, (_, i) => ({ start: T0 + i * 20 * H, end: T0 + i * 20 * H + hours * H, from: 100, to: 100 - drop }));
eq("usable", S.usable({ start: 0, end: H, from: 100, to: 90 }), true);
eq("too short is not usable", S.usable({ start: 0, end: 10 * 60000, from: 100, to: 90 }), false);
eq("tiny drop is not usable", S.usable({ start: 0, end: 5 * H, from: 100, to: 98 }), false);
eq("two sessions: unknown", S.estimate(sess(2, 30, 10), 80), { known: false });
eq("unusable sessions do not count", S.estimate(sess(2, 30, 10).concat(sess(5, 1, 10)), 80), { known: false });
eq("no sessions: unknown", S.estimate([], 80), { known: false });
eq("three sessions at 10%/h: 80% lasts 8 h", S.estimate(sess(3, 50, 5), 80), { known: true, minutes: 480, sessions: 3 });
eq("level 0: unknown", S.estimate(sess(3, 50, 5), 0), { known: false });

// Low battery: once per discharge, threshold crossed twice, charge re-arms
let a = S.newAlert(), fired = 0;
const step = (level, charging, dnd) => { const r = S.lowBattery(a, level, charging, 20, dnd); a = r.alert; fired += r.fire ? 1 : 0; };
step(50); step(21); eq("above threshold: quiet", fired, 0);
step(20); eq("fires at the threshold", fired, 1);
step(19); step(22); step(18); step(20); eq("crossed twice: still one", fired, 1);
step(30, true); step(25); eq("not re-armed above threshold after charge", fired, 1);
step(19); eq("re-armed by a charge", fired, 2);
a = S.newAlert(); fired = 0;
step(15); step(100); step(15); eq("back at full without a charge report: re-armed", fired, 2);
step(22); step(18); eq("jitter within the margin: no second alert", fired, 2);
a = S.newAlert(); fired = 0;
step(10, false, true); eq("DND: no alert", fired, 0);
step(10, false, false); eq("DND off while still low: alert comes", fired, 1);
eq("threshold list", [S.thresholdOf(15), S.thresholdOf(17), S.thresholdOf(undefined)], [15, 20, 20]);
eq("threshold 30", S.lowBattery(S.newAlert(), 30, false, 30, false).fire, true);
eq("unknown level never fires", S.lowBattery(S.newAlert(), null, false, 20, false).fire, false);

// Device key: salted, no address
eq("sha256 empty", S.sha256(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
eq("sha256 abc", S.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
eq("sha256 two blocks", S.sha256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"), "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
const k = S.deviceKey("a".repeat(32), "aa:bb:cc:dd:ee:ff");
eq("key shape", /^[0-9a-f]{16}$/.test(k), true);
eq("key is case-insensitive on the address", k, S.deviceKey("a".repeat(32), "AA:BB:CC:DD:EE:FF"));
eq("another salt, another key", k === S.deviceKey("b".repeat(32), "AA:BB:CC:DD:EE:FF"), false);

// History file
const now = T0 + 400 * 24 * H;
let h = S.newHistory(rnd);
eq("salt is 32 hex", /^[0-9a-f]{32}$/.test(h.salt), true);
const key = S.deviceKey(h.salt, "AA:BB:CC:DD:EE:FF");
h = S.record(h, key, { start: now - 5 * H, end: now - H, from: 90, to: 60 }, now);
eq("recorded", S.sessionsOf(h, key), [{ start: now - 5 * H, end: now - H, from: 90, to: 60 }]);
eq("last seen is the session end", S.lastSeen(h, key), now - H);
const text = S.serialize(h);
eq("no address or name in the file", /AA:BB|aa:bb/i.test(text), false);
eq("round trip", S.parse(text, rnd), h);
eq("unknown device last seen", S.lastSeen(h, "0".repeat(16)), 0);
h = S.touch(h, key, now, now);
eq("touch moves last seen", S.lastSeen(h, key), now);
h = S.touch(h, key, now - 10 * H, now);
eq("touch never goes back", S.lastSeen(h, key), now);
eq("a future time is not believed", S.lastSeen(S.touch(h, key, now + 400 * H, now), key), now);
h = S.record(h, key, { start: now + 100 * H, end: now + 90 * H, from: 90, to: 60 }, now);
eq("clock back: session refused", S.sessionsOf(h, key).length, 1);

// 12-month cap
let old = S.newHistory(rnd);
const oldKey = S.deviceKey(old.salt, "11:22:33:44:55:66");
old = S.record(old, oldKey, { start: now - 500 * 24 * H, end: now - 499 * 24 * H, from: 90, to: 50 }, now - 499 * 24 * H);
old = S.record(old, key, { start: now - 370 * 24 * H, end: now - 369 * 24 * H, from: 90, to: 50 }, now - 369 * 24 * H);
old = S.record(old, key, { start: now - 5 * H, end: now - 4 * H, from: 90, to: 80 }, now);
eq("device unseen for 12 months is gone", old.devices[oldKey], undefined);
eq("sessions older than 12 months are gone", S.sessionsOf(old, key).length, 1);
eq("prune keeps the edge", S.prune(h, now + S.KEEP_MS - 10 * H).devices[key] !== undefined, true);

// Corrupted file: starts clean, no crash
["", "{", "null", "[]", "42", '{"v":2}', '{"v":1,"salt":"x","devices":{}}', '{"v":1,"salt":"' + "a".repeat(32) + '","devices":[]}'].forEach(t => {
    const c = S.parse(t, rnd);
    eq("corrupted file starts clean: " + JSON.stringify(t), [c.v, Object.keys(c.devices).length, /^[0-9a-f]{32}$/.test(c.salt)], [1, 0, true]);
});
const partly = S.parse(JSON.stringify({ v: 1, salt: "c".repeat(32), devices: { [key]: { seen: 5, sessions: [[1, 2, 90, 80], [5, 1, 90, 80], "x", [1, 2, 50, 80]] }, "bad key": { seen: 1, sessions: [] }, ["f".repeat(16)]: { seen: "no" } } }), rnd);
eq("bad rows and devices are dropped, good ones kept", [Object.keys(partly.devices), partly.devices[key].sessions], [[key], [[1, 2, 90, 80]]]);
eq("parse keeps the salt", partly.salt, "c".repeat(32));

done();
