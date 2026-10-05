.pragma library
.import "Member.js" as Member
.import "Together.js" as Together

// What the user listens to together, remembered so that the ghost group can
// propose the group they actually use (D299). This is its pure logic: how a
// group is stored, what a use is worth, and which learned group fits what is
// available now. The QML (HabitLog, OrbitGhost) only records and asks.
// Privacy first (value 5): a member is kept only as a short hash, never an
// address or a name, a group is a sorted set of hashes with a use count and
// the day (days since 1970, no clock time) of its last use, and at most
// MAX_SETS groups are kept. The memory never leaves the machine and is
// erased by one call (forget). Tested by tests/habits.test.js.

// Groups kept: the one with the lowest score makes room for a new one
var MAX_SETS = 8;
// Uses counted for one group: a bound, so that old habits can still fade
var MAX_USES = 999;
// A group counts as used once it has stayed unchanged this long (ms): setting
// one up and taking a member out again straight away teaches nothing
var MIN_USE_MS = 60000;
// A use is worth half as much every this many days
var HALF_LIFE_DAYS = 30;
var DAY_MS = 86400000;
// Seed of the hash, unrelated to the two of Member.key so that what is stored
// never matches a name in PipeWire's graph
var SEED = 2654435761;
var TAG = /^[0-9a-f]{8}$/;

// Days since 1970 of a time in ms
function dayOf(ms) {
    return Number.isFinite(ms) && ms > 0 ? Math.floor(ms / DAY_MS) : 0;
}

// The only form of a member that is stored: 8 hex digits, "" for anything
// that is not a member
function tag(who) {
    const token = Member.clean(who);
    return token ? Member.hash(token, SEED) : "";
}

// A group as it is stored: its members' hashes, sorted, joined by commas; ""
// when fewer than two members are valid
function keyOf(members) {
    const seen = {};
    for (const who of Array.isArray(members) ? members.slice(0, Together.MAX_MEMBERS * 2) : []) {
        const t = tag(who);
        if (t)
            seen[t] = true;
    }
    const tags = Object.keys(seen).sort();
    return tags.length >= 2 && tags.length <= Together.MAX_MEMBERS ? tags.join(",") : "";
}

// The hashes of a stored key, or null when it is not one this module wrote
function tagsOf(key) {
    if (typeof key !== "string")
        return null;
    const tags = key.split(",");
    const ok = tags.length >= 2 && tags.length <= Together.MAX_MEMBERS && tags.every(t => TAG.test(t));
    return ok && tags.join(",") === tags.slice().sort().join(",") ? tags : null;
}

// What a group is worth on `today`: its uses, halved for every
// HALF_LIFE_DAYS since the last one
function score(entry, today) {
    const age = Math.max(0, today - entry.d);
    return entry.n * Math.pow(0.5, age / HALF_LIFE_DAYS);
}

// A copy of the stored groups with only what this module could have written:
// a malformed key or figure is dropped, never trusted
function sets(habits) {
    const out = {};
    const source = habits && typeof habits === "object" && !Array.isArray(habits) ? habits : {};
    for (const key of Object.keys(source).slice(0, MAX_SETS * 4)) {
        const e = source[key];
        if (tagsOf(key) && e && Number.isInteger(e.n) && Number.isInteger(e.d) && e.n > 0 && e.d >= 0)
            out[key] = { "n": Math.min(e.n, MAX_USES), "d": e.d };
    }
    return out;
}

// The groups worth most first: [{ key, tags, score }], equal scores by key so
// that the same memory always gives the same order
function ranked(habits, today) {
    const all = sets(habits);
    return Object.keys(all).map(key => ({ "key": key, "tags": tagsOf(key), "score": score(all[key], today) })).sort((a, b) => b.score - a.score || (a.key < b.key ? -1 : 1));
}

function count(habits) {
    return Object.keys(sets(habits)).length;
}

// The memory with one more use of `members` at `nowMs`. Past MAX_SETS the
// groups worth least are dropped, the new one never first.
function record(habits, members, nowMs) {
    const today = dayOf(nowMs);
    const next = sets(habits);
    const key = keyOf(members);
    if (!key)
        return next;
    next[key] = { "n": Math.min(MAX_USES, (next[key] ? next[key].n : 0) + 1), "d": today };
    for (const old of ranked(next, today).filter(s => s.key !== key).slice(Math.max(0, MAX_SETS - 1)))
        delete next[old.key];
    return next;
}

// The empty memory: what "Forget what Orbit learned" and switching learning
// off put in place of it
function forget() {
    return {};
}

// The best learned group that is all there now and holds `output`, as the
// output in use first and the others in a fixed order, or null. `pool` is
// every output that could be in it; `accept(members)` has the last word (the
// session's own rules, a refusal the user made).
function choose(habits, today, output, pool, accept) {
    const mine = tag(output);
    const known = {};
    for (const who of [output].concat(Array.isArray(pool) ? pool : [])) {
        const t = tag(who);
        if (t)
            known[t] = Member.clean(who);
    }
    for (const set of ranked(habits, today)) {
        if (set.tags.indexOf(mine) < 0 || !set.tags.every(t => known[t]))
            continue;
        const members = [known[mine]].concat(set.tags.filter(t => t !== mine).map(t => known[t]).sort());
        if (accept(members))
            return members;
    }
    return null;
}

// What each other output is worth as a partner of `output`: the scores of the
// learned groups they share with it, by hash
function partners(habits, today, output) {
    const mine = tag(output);
    const out = {};
    for (const set of ranked(habits, today))
        if (set.tags.indexOf(mine) >= 0)
            for (const t of set.tags)
                if (t !== mine)
                    out[t] = (out[t] || 0) + set.score;
    return out;
}

// The candidates, the best partner of `output` first and the rest in the order
// they came in (the caller's fixed order)
function bestFirst(habits, today, output, candidates) {
    const worth = partners(habits, today, output);
    const list = (Array.isArray(candidates) ? candidates : []).map((who, i) => ({ "who": who, "worth": worth[tag(who)] || 0, "i": i }));
    return list.sort((a, b) => b.worth - a.worth || a.i - b.i).map(e => e.who);
}

// Whether a learned group holds an output that `known` does not cover: it may
// be a wired output that has to be looked for
function reaches(habits, known) {
    const have = {};
    for (const who of Array.isArray(known) ? known : [])
        have[tag(who)] = true;
    return Object.keys(sets(habits)).some(key => tagsOf(key).some(t => !have[t]));
}
