// The orbit scene: screens hidden behind windows, planets, physics (Cover.js, Orbit.js, Physics.js).
// Run from the plugin root: gjs tests/scene.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Cover = load("Cover.js", ["covered"]);
const Orbit = load("Orbit.js", ["pick", "plan", "changes"]);
const Physics = load("Physics.js", ["spring", "norm", "ringSlot", "beltSlot", "beltRadius", "dragTarget", "dragArm", "dropRadius", "dropOnto", "separate", "moving"]);

// Ambient motion pauses on a screen hidden behind windows (P123).
// Made-up layout: three screens, sizes in logical pixels.
const spaces = {
    1: { id: 1, output: "OUT-1", is_active: true },
    2: { id: 2, output: "OUT-1", is_active: false },
    3: { id: 3, output: "OUT-2", is_active: true },
    4: { id: 4, output: "OUT-3", is_active: true }
};
const tile = (ws, col, w, h, floating) => ({ workspace_id: ws, is_floating: !!floating, layout: { tile_size: [w, h], pos_in_scrolling_layout: [col, 1] } });
const W = 2560, H = 1440;
eq("fullscreen window covers its screen", Cover.covered(spaces, [tile(1, 1, W, H)], "OUT-1", W, H, false), true);
eq("maximized column (gaps, bar) covers", Cover.covered(spaces, [tile(1, 1, 2528, 1388)], "OUT-1", W, H, false), true);
eq("two columns side by side fill the screen", Cover.covered(spaces, [tile(1, 1, 846, 1388), tile(1, 2, 1697, 1388)], "OUT-1", W, H, false), true);
eq("two stacked windows make one full-height column", Cover.covered(spaces, [tile(1, 1, 2528, 690), { workspace_id: 1, layout: { tile_size: [2528, 690], pos_in_scrolling_layout: [1, 2] } }], "OUT-1", W, H, false), true);
eq("one narrow column leaves the desktop visible", Cover.covered(spaces, [tile(1, 1, 846, 1388)], "OUT-1", W, H, false), false);
eq("a half-height window does not hide it", Cover.covered(spaces, [tile(1, 1, W, 700)], "OUT-1", W, H, false), false);
eq("an empty workspace is not covered", Cover.covered(spaces, [], "OUT-3", W, H, false), false);
eq("windows of another screen do not count", Cover.covered(spaces, [tile(1, 1, W, H)], "OUT-2", W, H, false), false);
eq("an inactive workspace does not count", Cover.covered(spaces, [tile(2, 1, W, H)], "OUT-1", W, H, false), false);
eq("the overview shows the desktop", Cover.covered(spaces, [tile(1, 1, W, H)], "OUT-1", W, H, true), false);
eq("a floating window never counts", Cover.covered(spaces, [tile(1, 1, W, H, true)], "OUT-1", W, H, false), false);
eq("unknown screen or no niri: never covered", [Cover.covered(spaces, [tile(1, 1, W, H)], "", W, H, false), Cover.covered({}, [], "OUT-1", W, H, false), Cover.covered(spaces, [tile(1, 1, W, H)], "OUT-1", 0, 0, false)], [false, false, false]);
eq("a window without layout yet does not count", Cover.covered(spaces, [{ workspace_id: 1 }], "OUT-1", W, H, false), false);

// Which devices get a planet, from made-up devices (no RSSI, as Quickshell)
{
    const dev = (address, name, more) => Object.assign({ address: address, name: name }, more);
    const unnamed = d => !d.name;
    const opts = (more) => Object.assign({ isHidden: a => a === "hid", isUnnamed: unnamed, showUnnamed: false, maxDevices: 2 }, more);
    const addresses = list => list.map(d => d.address);
    const all = [
        dev("far", "Speaker", { signalStrength: 20 }),
        dev("near", "Mouse", { signalStrength: 80 }),
        dev("anon", ""),
        dev("pair", "Keyboard", { paired: true }),
        dev("bond", "Pad", { bonded: true }),
        dev("on", "Headset", { connected: true, paired: true }),
        dev("hid", "Hidden", { connected: true }),
        dev("block", "Blocked", { blocked: true }),
        dev("gone", "Gone", { signalStrength: 0 }),
        null
    ];
    eq("connected first, then paired, up to maxDevices in all", addresses(Orbit.pick(all, opts())), ["on", "pair"]);
    eq("named before unnamed, then the strongest signal", addresses(Orbit.pick(all, opts({ maxDevices: 9, showUnnamed: true }))), ["on", "pair", "bond", "near", "far", "anon"]);
    eq("unnamed devices stay out unless asked", Orbit.pick(all, opts({ maxDevices: 9 })).some(d => d.address === "anon"), false);
    eq("an unnamed connected device always shows", addresses(Orbit.pick([dev("x", "", { connected: true })], opts())), ["x"]);
    eq("connected devices never count against the cap", addresses(Orbit.pick(all, opts({ maxDevices: 0 }))), ["on"]);

    const a = { address: "a" }, b = { address: "b" }, c = { address: "c" };
    const entries = [{ address: "a", leaving: false }, { address: "b", leaving: false }, { address: "c", leaving: true }];
    const step = Orbit.plan(entries, { a: a, c: c, d: { address: "d" } }, { a: a, b: b, c: c });
    eq("a device that went away starts leaving, one back stops", step.marks, [[1, true], [2, false]]);
    eq("a new device gets a body", step.added, ["d"]);
    eq("a leaving device stays resolvable", Object.keys(step.devices), ["a", "c", "d", "b"]);
    eq("nothing changes, nothing to do", Orbit.plan([{ address: "a", leaving: false }], { a: a }, { a: a }), { marks: [], added: [], devices: { a: a } });
    eq("an unknown leaving entry is not resolved", Object.keys(Orbit.plan([{ address: "z", leaving: true }], {}, {}).devices), []);
    eq("changes: what to start and stop, in order", Orbit.changes(["a", "b", "c"], ["d", "c", "a", "e"]), { added: ["d", "e"], removed: ["b"] });
    eq("changes: same set in another order, nothing", Orbit.changes(["a", "b"], ["b", "a"]), { added: [], removed: [] });
}

// Orbit physics: a 200x100 scene, ring at 0.5, black hole far away
{
    const g = { cx: 100, cy: 50, rx: 80, ry: 40, ringCy: 50, ringRy: 20, innerNorm: 0.5, snapNorm: 0.7, detachNorm: 0.8, outerMinNorm: 0.8,
        bodySize: 20, coreSize: 20, holeX: 1000, holeY: 1000, holeHorizon: 5 };
    const r = v => Math.round(v * 100) / 100;
    eq("norm: center 0, belt edge 1", [Physics.norm(g, 100, 50), Physics.norm(g, 180, 50), Physics.norm(g, 100, 90)], [0, 1, 1]);
    eq("first ring slot at the phase angle", (s => [r(s.x), r(s.y), r(s.depth)])(Physics.ringSlot(g, 0, 4, 0)), [140, 50, 0]);
    eq("ring slots split the turn evenly", (s => [r(s.x), r(s.y), r(s.depth)])(Physics.ringSlot(g, 1, 4, 0)), [100, 70, 1]);
    eq("an empty ring does not divide by zero", r(Physics.ringSlot(g, 0, 0, 0).x), 140);
    eq("belt radius: stronger signal, closer (clamped)", [Physics.beltRadius(g, 0), Physics.beltRadius(g, 1), Physics.beltRadius(g, 5)].map(r), [1, 0.8, 0.8]);
    eq("belt slot without float: on the ellipse", (s => [r(s.x), r(s.y)])(Physics.beltSlot(g, 0, 2, 0, 0.5, 1, 0, 0)), [100, 90]);
    eq("float stays within its amplitude", Math.abs(Physics.beltSlot(g, 0, 2, 0, 0.5, 1, 3.7, 4).x - 100) <= 4, true);

    const b = { px: 0, py: 0, vx: 0, vy: 0 };
    for (let i = 0; i < 300; i++)
        Physics.spring(b, 10, -5, 70, 0.58, 1 / 60);
    eq("the spring settles on its target", [r(b.px), r(b.py)], [10, -5]);
    eq("a settled body is not moving", Physics.moving(b, 10, -5), false);
    const c = { px: 0, py: 0, vx: 0, vy: 0 };
    let over = 0;
    for (let i = 0; i < 300; i++) {
        Physics.spring(c, 10, 0, 70, 1, 1 / 60);
        over = Math.max(over, c.px);
    }
    eq("critical damping (Reduce motion) never overshoots", over <= 10.001, true);

    eq("a free drag follows the pointer", Physics.dragTarget(g, {}, 30, 20), { x: 30, y: 20, k: 700, zeta: 0.85 });
    const magnet = Physics.dragTarget(g, { armed: true }, 145, 50);
    eq("the ring's magnet pulls a new device in", [magnet.x < 145, magnet.k, magnet.zeta], [true, 380, 0.62]);
    // Pulled 10 px off its ring (norm 0.625): held back by a third
    const held = Physics.dragTarget(g, { holding: true }, 150, 50);
    eq("a connected device resists leaving its ring", [r(held.x), r(held.y)], [146.75, 50]);
    eq("past the tear point it follows freely", r(Physics.dragTarget(g, { holding: true }, 180, 50).x), 180);
    eq("armed to disconnect, the ring barely holds", r(Physics.dragTarget(g, { holding: true, armed: true }, 150, 50).x), 149.2);
    const hidden = Physics.dragTarget(Object.assign({}, g, { holeX: 0, holeY: 0 }), { hideArmed: true }, 100, 100);
    eq("aimed at the black hole, it is pulled in", [r(hidden.x), r(hidden.y), hidden.k], [45, 45, 420]);

    // Off the exact center, so the core's push has a direction
    const me = { px: 105, py: 50, inSlot: false }, other = { px: 110, py: 50 };
    const t = { x: 105, y: 50 };
    Physics.separate(g, me, t, [me, other], false);
    eq("neighbours push apart, the core pushes out", [r(t.x), r(t.y)], [79, 50]);
    const alone = { x: 105, y: 50 };
    Physics.separate(g, me, alone, [me], false);
    eq("too close to the core, it is put on its edge", [r(alone.x), r(alone.y)], [121, 50]);
    const card = { x: 105, y: 50 };
    Physics.separate(g, me, card, [me], true);
    eq("with a card open, the center is allowed", card, { x: 105, y: 50 });
    const slotted = { px: 105, py: 50, inSlot: true }, slot = { x: 105, y: 50 };
    Physics.separate(g, slotted, slot, [slotted], false);
    eq("a body in its ring slot keeps it", slot, { x: 105, y: 50 });
    // The host away at the back (a Listen together took the centre): it is the keep-out disc that moves
    const away = { x: 20, y: 50, r: 10 };
    const atCentre = { x: 105, y: 50 }, atHost = { x: 22, y: 50 };
    Physics.separate(g, me, atCentre, [me], false, away);
    Physics.separate(g, me, atHost, [me], false, away);
    eq("the centre is free once the host is away, the host's own spot is not", [atCentre, r(atHost.x)], [{ x: 105, y: 50 }, r(away.x + away.r + g.bodySize * 0.55)]);
    const nearHole = { x: 140, y: 50 };
    Physics.separate(Object.assign({}, g, { holeX: 150, holeY: 50 }), { px: 0, py: 0 }, nearHole, [], false);
    eq("nothing settles in the black hole's reach", [r(nearHole.x), r(nearHole.y)], [127, 50]);
    const far = { px: 150, py: 50 }, dragged = { x: 150, y: 50 }, still = { x: 150, y: 50 };
    Physics.separate(g, far, dragged, [far, { px: 170, py: 50, dragging: true }], false);
    Physics.separate(g, far, still, [far, { px: 170, py: 50 }], false);
    eq("a dragged body clears a wider path", [r(dragged.x), r(still.x)], [134.29, 149.43]);
    eq("drag: a free body arms inside the magnet", [Physics.dragArm(g, false, 150, 50).armed, Physics.dragArm(g, false, 160, 50).armed], [true, false]);
    eq("drag: a connected body arms past the tear point", [Physics.dragArm(g, true, 160, 50).armed, Physics.dragArm(g, true, 170, 50).armed], [false, true]);
    eq("drag: far from the hole, no hide and no glow", Physics.dragArm(g, false, 150, 50), { hide: false, armed: true, feed: 0 });
    const hole = Object.assign({}, g, { holeX: 150, holeY: 50 });
    eq("drag: over the hole it hides, never connects", Physics.dragArm(hole, true, 160, 50), { hide: true, armed: false, feed: 1 });
    eq("drag: the glow fades with distance", r(Physics.dragArm(hole, false, 150, 90).feed), 0.13);
    eq("drag: the hide reach is at least 3/4 of a body", [Physics.dragArm(hole, false, 164, 50).hide, Physics.dragArm(hole, false, 166, 50).hide], [true, false]);
    // Listen together: a connected body dropped on another connected one
    const mate = { px: 100, py: 50, diameter: 40, baseScale: 1, connected: true };
    const mate2 = { px: 110, py: 50, diameter: 40, baseScale: 1, connected: true };
    const mover = { px: 0, py: 0, connected: true };
    // A disc of 40 px is small: the drop radius is its floor (60), not twice its radius (40)
    eq("drop: the pointer within the drop radius of a connected body", [Physics.dropOnto(mover, [mover, mate], 115, 50) === mate, Physics.dropOnto(mover, [mover, mate], 155, 50) === mate, Physics.dropOnto(mover, [mover, mate], 165, 50)], [true, true, null]);
    eq("drop: the nearest centre wins", Physics.dropOnto(mover, [mate, mate2], 108, 50) === mate2, true);
    eq("drop: never on itself, a leaving or an unconnected body", [Physics.dropOnto(mate, [mate], 100, 50), Physics.dropOnto(mover, [Object.assign({}, mate, { leaving: true })], 100, 50), Physics.dropOnto(mover, [Object.assign({}, mate, { connected: false })], 100, 50)], [null, null, null]);
    eq("drop: an unconnected dragged body listens to nobody", Physics.dropOnto({ connected: false }, [mate], 100, 50), null);
    eq("drop: with `anyone`, an unconnected dragged body is over the member", Physics.dropOnto({ connected: false }, [mate], 100, 50, true) === mate, true);
    eq("drop: even with `anyone`, only a connected body can be dropped onto", Physics.dropOnto({ connected: false }, [Object.assign({}, mate, { connected: false })], 100, 50, true), null);
    // Past the floor the radius is twice the disc's: 200 px wide gives 200, half-scaled 100
    const big = Object.assign({}, mate, { diameter: 200 });
    eq("drop: twice the disc's radius once past the floor", [Physics.dropRadius(big), Physics.dropRadius(Object.assign({}, big, { baseScale: 0.5 }))], [200, 100]);
    eq("drop: a smaller body (far in the ring) has a smaller zone", [Physics.dropOnto(mover, [big], 240, 50) === big, Physics.dropOnto(mover, [Object.assign({}, big, { baseScale: 0.5 })], 240, 50)], [true, null]);
    eq("drop: a tiny planet keeps the 60 px floor", [Physics.dropRadius(Object.assign({}, mate, { diameter: 10 })), Physics.dropRadius(Object.assign({}, mate, { diameter: 10, baseScale: 0.2 }))], [60, 60]);
}

done();
