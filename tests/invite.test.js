// The invitation to listen together (Invite.js): halo breath, thread strength, light dots, thread geometry.
// Run from the plugin root: gjs tests/invite.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Invite = load("Invite.js", ["DOTS", "RUN", "breath", "strength", "dotAt", "dotAlpha", "thread", "nearest"]);

// A halo breathes between 0 and 1, and two targets are not in step
eq("breath stays within 0..1", [0, 0.3, 1.7, 9].every(t => [0, 1, 2].every(i => Invite.breath(t, i) >= 0 && Invite.breath(t, i) <= 1)), true);
eq("two targets do not breathe in step", Invite.breath(0.4, 0) !== Invite.breath(0.4, 1), true);

// The thread shows from the start of the drag and is whole when the edges touch
eq("afar it is still seen", Invite.strength(1000, 40), 0.35);
eq("touching it is whole", Invite.strength(0, 40), 1);
eq("it grows as they near", Invite.strength(60, 40) < Invite.strength(30, 40), true);

// The light dots run from the carried device to the target, and stay put with Reduce motion
eq("a dot is on the thread", [0, 0.5, 1.1].every(t => [...Array(Invite.DOTS).keys()].every(i => { const u = Invite.dotAt(t, i, true); return u >= 0 && u < 1; })), true);
eq("dots run with the clock", Invite.dotAt(0.1, 0, true) < Invite.dotAt(0.4, 0, true), true);
eq("a dot runs a full turn in RUN seconds", Math.abs(Invite.dotAt(0.3, 2, true) - Invite.dotAt(0.3 + Invite.RUN, 2, true)) < 1e-9, true);
eq("Reduce motion: the clock moves nothing", Invite.dotAt(0.1, 3, false), Invite.dotAt(5, 3, false));
eq("Reduce motion: dots are spread evenly", [0, 1, 2].map(i => Invite.dotAt(0, i, false)), [0.5 / 6, 1.5 / 6, 2.5 / 6]);
eq("a dot is unseen at both ends", [Invite.dotAlpha(0), Math.round(Invite.dotAlpha(1) * 1e6)], [0, 0]);
eq("and full in the middle", Invite.dotAlpha(0.5), 1);

// The thread leaves the carried device's edge and stops at the target's
const a = { px: 100, py: 100 }, b = { px: 100, py: 200 };
eq("thread from edge to edge", Invite.thread(a, 20, b, 30), { x: 100, y: 120, angle: 90, length: 50 });
eq("overlapping edges leave no thread", Invite.thread(a, 60, b, 60).length, 0);
eq("two bodies at one point do not divide by zero", Number.isFinite(Invite.thread(a, 10, a, 10).x), true);

// The nearest target, or none
eq("nearest of several", Invite.nearest(a, [{ px: 300, py: 100 }, { px: 100, py: 150 }, { px: 100, py: 400 }]), 1);
eq("none when there are no targets", Invite.nearest(a, []), -1);

done();
