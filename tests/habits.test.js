// The memory of the groups the user listens to (D299): what is stored (hashes only, a use count and a
// day number), how a use is counted, the bound, the fading with age, which learned group fits, and the
// erasing. The proposal that uses it is in tests/ghost.test.js.
// Run from the plugin root: gjs tests/habits.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Habits = load("Habits.js");
const Member = load("Member.js");
const Together = load("Together.js");

// Made-up outputs: three headsets or speakers and two wired outputs
const A = "AA:BB:CC:DD:EE:01", B = "AA:BB:CC:DD:EE:02", C = "AA:BB:CC:DD:EE:03", D = "AA:BB:CC:DD:EE:04";
const W1 = "alsa_output.usb-Acme_Studio-00.analog-stereo", W2 = "alsa_output.usb-Acme_Dongle-00.analog-stereo";
const DAY = 20000, at = day => day * Habits.DAY_MS + 3600000;
const used = (habits, members, day) => Habits.record(habits, members, at(day));
const all = () => true;

// --- What is stored: hashes, never a name ----------------------------------------------------------------------------
const one = used({}, [A, W1], DAY);
const key = Object.keys(one)[0];
eq("one group, kept by its members' hashes", [Object.keys(one).length, key.split(",").length, key.split(",").every(t => /^[0-9a-f]{8}$/.test(t))], [1, 2, true]);
eq("nothing readable is in it: no address, no node name, no part of one", JSON.stringify(one).match(/AA:BB|alsa|usb|Acme|Studio|Dongle|EE|bluez/i), null);
eq("a use count and the day of the last use, nothing else (no clock time)", one[key], { "n": 1, "d": DAY });
eq("the same group in any order is the same group", Object.keys(used({}, [W1, A], DAY)), [key]);
eq("a hash is the same every time and differs for every output", [Habits.tag(A) === Habits.tag(A), Habits.tag(A) !== Habits.tag(B), Habits.tag(W1) !== Habits.tag(W2)], [true, true, true]);
eq("it is not the hash PipeWire's node names carry", Habits.tag(W1) !== Member.hash(W1, 2166136261) && Habits.tag(W1) !== Member.hash(W1, 305419896), true);
eq("what is not an output has no hash", [Habits.tag("x"), Habits.tag(""), Habits.tag(null), Habits.tag(7), Habits.tag("alsa_output..x")], ["", "", "", "", ""]);
eq("a group needs two outputs", [used({}, [A], DAY), used({}, [], DAY), used({}, [A, A], DAY), used({}, null, DAY), used({}, [A, "x"], DAY)], [{}, {}, {}, {}, {}]);
eq("and at most four", [Habits.keyOf([A, B, C, D, W1]) === "", Habits.keyOf([A, B, C, D]) !== ""], [true, true]);

// --- Uses, the cap and the bound --------------------------------------------------------------------------------------
let many = {};
for (let i = 0; i < 3; i++)
    many = used(many, [A, B], DAY + i);
eq("each use adds one and moves the day", Object.values(many), [{ "n": 3, "d": DAY + 2 }]);
for (let i = 0; i < Habits.MAX_USES + 20; i++)
    many = used(many, [A, B], DAY);
eq("the count stops at its cap of 999", [Habits.MAX_USES, Object.values(many)[0].n], [999, 999]);
const sets = n => Array.from({ "length": n }, (_, i) => [A, "AA:BB:CC:DD:FF:" + ("0" + i).slice(-2).toUpperCase()]);
let bounded = {};
for (const pair of sets(Habits.MAX_SETS + 5))
    bounded = used(bounded, pair, DAY);
eq("at most eight groups are kept", [Habits.MAX_SETS, Object.keys(bounded).length], [8, 8]);
let full = {};
for (const pair of sets(Habits.MAX_SETS))
    full = used(used(full, pair, DAY), pair, DAY);
const strong = Habits.keyOf(sets(1)[0]);
full = used(full, [B, C], DAY);
eq("the new group makes room by dropping one of the lowest score, never itself", [Object.keys(full).length, !!full[Habits.keyOf([B, C])]], [8, true]);
const old = used(used({}, [A, B], DAY - 200), [A, B], DAY - 200);
let crowd = Object.assign({}, old);
for (const pair of sets(Habits.MAX_SETS - 1))
    crowd = used(crowd, pair, DAY);
crowd = used(crowd, [C, W2], DAY);
eq("the lowest score goes: an old, rarely used group before the recent ones", [!!crowd[Habits.keyOf([A, B])], Object.keys(crowd).length], [false, 8]);

// --- The fading --------------------------------------------------------------------------------------------------------------
eq("a minute is what makes a use", [Habits.MIN_USE_MS, Habits.HALF_LIFE_DAYS], [60000, 30]);
eq("a use is worth half as much after 30 days", [Habits.score({ "n": 4, "d": DAY }, DAY), Habits.score({ "n": 4, "d": DAY }, DAY + 30), Habits.score({ "n": 4, "d": DAY }, DAY + 60)], [4, 2, 1]);
eq("a day in the future is no bonus", Habits.score({ "n": 4, "d": DAY + 5 }, DAY), 4);
const rank = habits => Habits.ranked(habits, DAY).map(s => s.key);
const fresh = used({}, [A, B], DAY), stale = used(used(used({}, [C, D], DAY - 60), [C, D], DAY - 60), [C, D], DAY - 60);
eq("a fresh group beats an older one used more often (three uses 60 days ago are worth 0.75)", rank(Object.assign({}, stale, fresh)), [Habits.keyOf([A, B]), Habits.keyOf([C, D])]);
eq("counter-proof: three uses the same day beat one", rank(Object.assign({}, used(used(used({}, [C, D], DAY), [C, D], DAY), [C, D], DAY), fresh))[0], Habits.keyOf([C, D]));

// --- Which learned group fits -------------------------------------------------------------------------------------------------
const habits = used(used(used({}, [W1, A, B], DAY), [W1, A, B], DAY), [W1, C], DAY);
eq("the best group that is all there, the output in use first, the others in a fixed order", Habits.choose(habits, DAY, W1, [B, A, C], all), [W1, A, B]);
eq("the output in use can be any member", Habits.choose(habits, DAY, B, [W1, A], all), [B, A, W1]);
eq("a member missing: the next group", Habits.choose(habits, DAY, W1, [A, C], all), [W1, C]);
eq("nothing fits: null", [Habits.choose(habits, DAY, W1, [D], all), Habits.choose(habits, DAY, D, [A, B, W1], all), Habits.choose({}, DAY, W1, [A], all)], [null, null, null]);
eq("the caller has the last word on each group, best first", (seen => (Habits.choose(habits, DAY, W1, [A, B, C], g => (seen.push(g), g.length === 2)), seen))([]), [[W1, A, B], [W1, C]]);
eq("a pool that is not a list", [Habits.choose(habits, DAY, W1, null, all), Habits.choose(habits, DAY, W1, "x", all)], [null, null]);
eq("the partners of an output, by what they are worth", Habits.partners(habits, DAY, W1), { [Habits.tag(A)]: 2, [Habits.tag(B)]: 2, [Habits.tag(C)]: 1 });
eq("the best partner first, the others as they came", Habits.bestFirst(habits, DAY, W1, [D, C, A]), [A, C, D]);
eq("no memory: as they came", Habits.bestFirst({}, DAY, W1, [D, C, A]), [D, C, A]);
eq("a group holding an output that is not known may need the plugged outputs read", [Habits.reaches(habits, [W1, A, B, C]), Habits.reaches(habits, [W1, A]), Habits.reaches({}, [A])], [false, true, false]);

// --- What is not ours is not trusted -----------------------------------------------------------------------------------------------
const good = Habits.keyOf([A, B]);
const hostile = { [good]: { "n": 2, "d": DAY }, "x": { "n": 1, "d": 1 }, "aaaaaaaa": { "n": 1, "d": 1 }, "bbbbbbbb,aaaaaaaa": { "n": 1, "d": 1 }, "AAAAAAAA,BBBBBBBB": { "n": 1, "d": 1 }, "aaaaaaaa,bbbbbbbb,cccccccc,dddddddd,eeeeeeee": { "n": 1, "d": 1 } };
eq("keys that are not sorted hashes are dropped", Object.keys(Habits.sets(hostile)), [good]);
eq("so are figures that are not whole, positive numbers", Object.keys(Habits.sets({ [good]: { "n": "2", "d": 1 }, "aaaaaaaa,bbbbbbbb": { "n": 0, "d": 1 }, "aaaaaaaa,cccccccc": { "n": 1, "d": -1 }, "aaaaaaaa,dddddddd": null, "bbbbbbbb,cccccccc": { "n": 1.5, "d": 1 } })), []);
eq("a count past the cap is brought back to it", Habits.sets({ [good]: { "n": 99999, "d": 1 } })[good].n, 999);
eq("something that is not a memory is an empty one", [null, undefined, "x", 7, []].map(h => Habits.count(h)), [0, 0, 0, 0, 0]);
eq("recording over junk keeps only what is valid", Object.keys(used(hostile, [C, D], DAY)).sort(), [good, Habits.keyOf([C, D])].sort());

// --- Forgetting ----------------------------------------------------------------------------------------------------------------------------
eq("forgetting leaves nothing, and counts none", [Habits.forget(), Habits.count(Habits.forget()), Habits.count(habits)], [{}, 0, 2]);
eq("what was forgotten proposes nothing", Habits.choose(Habits.forget(), DAY, W1, [A, B, C], all), null);
eq("a use after it starts afresh", Object.values(used(Habits.forget(), [A, B], DAY)), [{ "n": 1, "d": DAY }]);

// --- Days ---------------------------------------------------------------------------------------------------------------------------------------
eq("a day is days since 1970, whatever the hour", [Habits.dayOf(0), Habits.dayOf(Habits.DAY_MS - 1), Habits.dayOf(Habits.DAY_MS), Habits.dayOf(at(DAY))], [0, 0, 1, DAY]);
eq("not a time: day 0", [Habits.dayOf(NaN), Habits.dayOf(-5), Habits.dayOf(undefined), Habits.dayOf("x")], [0, 0, 0, 0]);
eq("the group size it keeps is the session's", Together.MAX_MEMBERS, 4);

done();
