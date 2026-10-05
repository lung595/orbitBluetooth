.pragma library
.import "Member.js" as Member
.import "Together.js" as Together

// The group the scene proposes (D298): while the sound goes to a wired output
// and a Bluetooth device is connected, or the other way round, a ghost planet
// offers to make them listen together. This is its pure logic: which outputs
// it would put together, the key a refusal is remembered by, and what a new
// reading of the plugged outputs depends on. The QML only reads and draws.
// Tested by tests/ghost.test.js.

// How many refusals are kept in memory: plugging and unplugging all day never
// gets near it, and a bound is what keeps a shell that runs for weeks small
var MAX_DECLINED = 64;
// Candidates looked at, and PipeWire nodes read: anything beyond is noise
var MAX_POOL = 64;
var MAX_NODES = 4096;

// The outputs of `pool` that could join `output`: the other kind only (a wired
// output is offered Bluetooth devices, a Bluetooth device wired outputs), each
// once, in a fixed order, so that the same state always makes the same proposal
function others(output, pool) {
    const kind = Member.kind(output);
    const seen = {};
    const out = [];
    for (const item of Array.isArray(pool) ? pool.slice(0, MAX_POOL) : []) {
        const who = Member.clean(item);
        if (who && Member.kind(who) !== kind && !seen[who]) {
            seen[who] = true;
            out.push(who);
        }
    }
    return out.sort();
}

// What a refusal is remembered by: the proposed members as a set, whatever
// their order. "" when there is none.
function key(members) {
    return (Array.isArray(members) ? members : []).map(Member.clean).filter(a => !!a).sort().join(",");
}

// The group to propose, or null: { members, key }. `facts` is { output, bluetooth,
// wired }: the member that is the output in use (a Bluetooth address, or a
// wired output's node name; "" when it is neither), the Bluetooth devices
// connected with a sound output, the wired outputs plugged in. The output in
// use comes first, then the candidates of the other kind in a fixed order, at
// most Together.MAX_MEMBERS in all. `check(list)` is the session's own
// (TogetherSession.check: null when the list could start): a candidate it
// would refuse (a headset in call mode, an output that has gone quiet) is left
// out, so what is proposed is what a click can do.
function proposal(facts, check) {
    const f = facts && typeof facts === "object" ? facts : {};
    const output = Member.clean(f.output);
    if (!output || typeof check !== "function")
        return null;
    const members = [output];
    for (const who of others(output, Member.isWired(output) ? f.bluetooth : f.wired)) {
        if (members.length >= Together.MAX_MEMBERS)
            break;
        if (!check([output, who]))
            members.push(who);
    }
    if (members.length < 2 || check(members))
        return null;
    return { "members": members, "key": key(members) };
}

// --- The refusals ----------------------------------------------------------------------
// Kept as { key: true } by the daemon's session, so that they outlive the views
// and end with the shell; nothing is written to disk (value 5)

function isDeclined(declined, who) {
    return !!who && !!declined && declined[who] === true;
}

// `declined` with `who` added: a new object, the oldest ones dropped past
// MAX_DECLINED, and anything that is not a key of a proposal ignored
function withDeclined(declined, who) {
    const base = declined && typeof declined === "object" ? declined : {};
    if (typeof who !== "string" || !who || who.length > Together.MAX_LIST_LENGTH)
        return base;
    const next = Object.assign({}, base);
    // Deleted first, so that asking again makes it the newest
    delete next[who];
    next[who] = true;
    const all = Object.keys(next);
    for (const old of all.slice(0, Math.max(0, all.length - MAX_DECLINED)))
        delete next[old];
    return next;
}

// --- When to read the plugged outputs again --------------------------------------------------
// pactl is asked only when something that could change the answer did

// The names of the wired outputs among PipeWire's nodes (sinks, never streams), sorted
function wiredSinks(nodes) {
    const out = [];
    const count = nodes && nodes.length > 0 ? Math.min(nodes.length, MAX_NODES) : 0;
    for (let i = 0; i < count; i++) {
        const n = nodes[i];
        if (n && n.isSink && !n.isStream && Member.isWired(n.name))
            out.push(n.name);
    }
    return out.sort();
}

// One text that changes when the plugged outputs may have: the output in use,
// the Bluetooth devices there, and the wired sinks PipeWire lists (a cable
// plugged in makes a node appear, one pulled out makes it go)
function signature(output, bluetooth, nodes) {
    const devices = Array.isArray(bluetooth) ? bluetooth.map(Member.clean).filter(a => !!a).sort() : [];
    return [Member.clean(output), devices.join(","), wiredSinks(nodes).join(",")].join("|");
}
