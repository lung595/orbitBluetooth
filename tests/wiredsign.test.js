// A wired member inside a Listen together (D298): its picture by kind of output, the rounded square
// it is drawn and clicked in, the loose cable going taut, the rows that follow the group's wired
// members, and the one rule that puts it on the orbit with the Bluetooth ones.
// Run from the plugin root: gjs tests/wiredsign.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const S = load("WiredSign.js");
const C = load("Centre.js", ["TILT", "sizes", "copySlot", "depthSize", "place", "phaseAt"]);
const G = load("Glyphs.js", ["paths", "order", "path", "wired"]);

const near = v => Math.round(v * 1000) / 1000;

// Made-up outputs: a USB interface, a screen over HDMI, a jack and a sound card the code cannot name
const usb = "alsa_output.usb-Maker_Interface-00.analog-stereo";
const hdmi = "alsa_output.pci-0000_01_00.1.hdmi-stereo";
const jack = "alsa_output.pci-0000_00_1f.3.analog-stereo";
const card = "alsa_output.pci-0000_00_1f.3.iec958-stereo";
// Made-up Bluetooth devices
const headset = "02:00:00:00:10:06";
const speaker = "02:00:00:00:20:01";

// --- the picture --------------------------------------------------------------------------
eq("kind: a USB device is USB, whatever its profile is called", S.kindOf(usb, {}), "usb");
eq("kind: a screen over HDMI", S.kindOf(hdmi, {}), "hdmi");
eq("kind: a jack is analog", S.kindOf(jack, {}), "analog");
eq("kind: a card it cannot name is the generic one", S.kindOf(card, {}), "other");
eq("kind: the connection beats the name (a USB dock with an HDMI profile)", S.kindOf("alsa_output.usb-Dock_Pro-00.hdmi-stereo", {}), "usb");
eq("kind: the bus the node says counts too", S.kindOf("alsa_output.pci-0000_05_00.0.stereo", { "device.bus": "usb" }), "usb");
eq("kind: the form factor of a headphone socket", S.kindOf("alsa_output.pci-0000_00_1f.3.stereo-fallback", { "device.form_factor": "headphones" }), "analog");
eq("kind: no properties at all is not an error", [S.kindOf(hdmi), S.kindOf(hdmi, null), S.kindOf(hdmi, "usb"), S.kindOf(hdmi, 7)], ["hdmi", "hdmi", "hdmi", "hdmi"]);
eq("kind: nothing readable is the generic one", [S.kindOf("", {}), S.kindOf(undefined, undefined), S.kindOf(null, null)], ["other", "other", "other"]);

eq("glyph: each kind has its own picture", ["usb", "hdmi", "analog", "other"].map(G.wired), ["wiredUsb", "wiredHdmi", "wiredAnalog", "wiredOther"]);
eq("glyph: a kind it does not know is the generic plug, never a Bluetooth picture or an error", ["", "bluetooth", "constructor", undefined, null, 4].map(G.wired), Array(6).fill("wiredOther"));
eq("glyph: every picture is drawn (counter-proof: an unknown name falls back to the Bluetooth glyph)", ["wiredUsb", "wiredHdmi", "wiredAnalog", "wiredOther"].map(k => G.path(k) !== G.path("nothing-of-the-kind") && G.path(k).length > 20), Array(4).fill(true));
eq("glyph: the four are different", new Set(["usb", "hdmi", "analog", "other"].map(k => G.path(G.wired(k)))).size, 4);
eq("glyph: they are not offered in the glyph picker", ["wiredUsb", "wiredHdmi", "wiredAnalog", "wiredOther"].filter(k => G.order.indexOf(k) >= 0), []);

// --- the rounded square -------------------------------------------------------------------
const side = 100;
eq("shape: the corner is soft but not a circle", [S.CORNER > 0.1, S.CORNER < 0.5], [true, true]);
eq("shape: the middle and the middle of each side answer", [[0, 0], [49, 0], [-49, 0], [0, 49], [0, -49]].map(([x, y]) => S.inside(x, y, side)), Array(5).fill(true));
eq("shape: just outside each side does not", [[51, 0], [-51, 0], [0, 51], [0, -51]].map(([x, y]) => S.inside(x, y, side)), Array(4).fill(false));
eq("shape: the sharp corner of the box is rounded off, the four of them", [[49, 49], [-49, 49], [49, -49], [-49, -49]].map(([x, y]) => S.inside(x, y, side)), Array(4).fill(false));
eq("shape: it is a square, not a disc: the diagonal reaches past the circle's edge", [S.inside(40, 40, side), Math.hypot(40, 40) > side / 2], [true, true]);
eq("shape: but not as far as the box's corner: the rounding starts where the corner circle begins", [S.inside(42, 42, side), S.inside(41, 41, side)], [false, true]);
eq("shape: the same on every side", [[40, -40], [-40, 40], [-40, -40]].map(([x, y]) => S.inside(x, y, side)), Array(3).fill(true));
eq("shape: it scales with the side (a small disc has the same shape)", [S.inside(4, 4, 10), S.inside(4.2, 4.2, 10), S.inside(4.9, 4.9, 10)], [true, false, false]);
eq("shape: a point with a missing part never answers by accident", [S.inside(NaN, 0, side), S.inside(0, undefined, side)], [false, false]);

// --- the cable ----------------------------------------------------------------------------
eq("cable: it goes taut in 0.4 s (the user-facing pace, written out so a change is deliberate)", S.TIGHTEN, 400);
eq("cable: loose, its middle hangs a share of its length below the line (the curve reaches half its control point)", near(S.drop(200, 0) / 2), near(200 * S.SLACK));
eq("cable: taut, it is a straight line", S.drop(200, 1), 0);
eq("cable: half way it hangs half as much", near(S.drop(200, 0.5)), near(S.drop(200, 0) / 2));
const steps = Array.from({ length: 11 }, (_, i) => S.drop(200, i / 10));
eq("cable: it only ever tightens, never slackens again on its way", steps.every((v, i) => i === 0 || v < steps[i - 1]), true);
eq("cable: a tension past either end is the end", [S.drop(200, -3) === S.drop(200, 0), S.drop(200, 4)], [true, 0]);
eq("cable: a longer cable hangs more, a point of a cable (no length) not at all", [S.drop(400, 0) > S.drop(200, 0), S.drop(0, 0), S.drop(-5, 0)], [true, 0, 0]);

const from = { x: 100, y: 80 }, to = { x: 300, y: 120 };
eq("cable: a pulse starts at the source and ends at the member, loose or taut", [S.along(from, to, 0, 70), S.along(from, to, 1, 70), S.along(from, to, 0, 0), S.along(from, to, 1, 0)], [from, to, from, to]);
eq("cable: taut, the pulse is on the straight line", S.along(from, to, 0.25, 0), { x: 150, y: 90 });
eq("cable: loose, the middle of the cable hangs half the control point's drop below the line", [S.along(from, to, 0.5, 72).x, S.along(from, to, 0.5, 72).y], [200, 100 + 36]);
eq("cable: a pulse is never above the line of a cable that hangs (counter-proof of the direction)", [0.1, 0.3, 0.5, 0.7, 0.9].every(t => S.along(from, to, t, 50).y > S.along(from, to, t, 0).y), true);

// --- the rows follow the group's wired members --------------------------------------------
const plan = (rows, members) => S.reconcile(rows, members);
eq("rows: a wired output joins, a row is added", plan([], [headset, usb]), { "remove": [], "add": [usb] });
eq("rows: the same group again changes nothing", plan([usb], [headset, usb]), { "remove": [], "add": [] });
eq("rows: a wired output leaves, its row goes and the other stays", plan([usb, hdmi], [headset, hdmi]), { "remove": [0], "add": [] });
eq("rows: several leave: last row first, so numbers stay valid while removing", plan([usb, hdmi, jack], [usb]), { "remove": [2, 1], "add": [] });
eq("rows: the order of the group does not matter", plan([usb, hdmi], [hdmi, headset, usb]), { "remove": [], "add": [] });
eq("rows: some leave and some join at once", plan([usb, hdmi], [jack, hdmi, headset]), { "remove": [0], "add": [jack] });
eq("rows: a Bluetooth member never gets a row", plan([], [headset, speaker]), { "remove": [], "add": [] });
eq("rows: the group ends, every row goes", plan([usb, hdmi], []), { "remove": [1, 0], "add": [] });
eq("rows: a name that is not a wired output is ignored", plan([], [usb, "alsa_output.bad name", "alsa_output.x..y", "bluez_output.02_00_00_00_10_06.1", null, 7, {}]), { "remove": [], "add": [usb] });
eq("rows: an output listed twice has one row", plan([], [usb, usb, hdmi, usb]), { "remove": [], "add": [usb, hdmi] });
eq("rows: no list at all is no change, not an error", [plan(null, undefined), plan(undefined, null), plan("usb", "usb")], Array(3).fill({ "remove": [], "add": [] }));

// Applying the change always lands on the wired members, from any state (every pair of
// small subsets of a pool, the Bluetooth ones and a made-up name mixed in)
const pool = [usb, hdmi, jack, card, headset, speaker, "not a member"];
const subsets = Array.from({ length: 1 << pool.length }, (_, mask) => pool.filter((_, i) => mask & (1 << i)));
const apply = (rows, change) => rows.filter((_, i) => change.remove.indexOf(i) < 0).concat(change.add);
const wiredIn = list => list.filter(t => t.indexOf("alsa_output.") === 0).sort();
let wrong = 0, total = 0;
for (const rows of subsets.filter(s => s.every(t => t.indexOf("alsa_output.") === 0))) {
    for (const members of subsets) {
        total++;
        const next = apply(rows, plan(rows, members));
        if (JSON.stringify(next.slice().sort()) !== JSON.stringify(wiredIn(members)))
            wrong++;
    }
}
eq("rows: from any rows to any group, applying the change gives exactly the wired members (" + total + " cases)", wrong, 0);

// --- one rule for the orbit ---------------------------------------------------------------
const g = { cx: 210, cy: 190, rx: 170, ry: 125, coreSize: 65, bodySize: 51 };
const sz = C.sizes(g);
const group = { x: g.cx, y: g.cy, scale: 1 };
const phase = C.phaseAt(7);
eq("place: the source is in the middle, in front, as big as the host's core", C.place(sz, group, "source", 0, 0, phase), { "x": g.cx, "y": g.cy, "depth": 1, "size": g.coreSize });
const back = { x: 120, y: 90, scale: 0.7 };
eq("place: the source of a group that stepped back is as small as the group, and moves with it", [near(C.place(sz, back, "source", 0, 0, phase).size), C.place(sz, back, "source", 0, 0, phase).x, C.place(sz, back, "source", 0, 0, phase).y], [near(g.coreSize * 0.7), 120, 90]);
for (const n of [1, 2, 3]) {
    const spots = Array.from({ length: n }, (_, i) => C.place(sz, group, "copy", i, n, phase));
    const slots = Array.from({ length: n }, (_, i) => C.copySlot(sz.radius, group, i, n, phase));
    eq("place: " + n + " copies sit where the orbit puts them, as big as their depth says", spots.map(p => [p.x, p.y, p.depth, near(p.size)]), slots.map(p => [p.x, p.y, p.depth, near(sz.copy * C.depthSize(p.depth))]));
}
const trio = Array.from({ length: 3 }, (_, i) => C.place(sz, group, "copy", i, 3, phase));
eq("place: three copies, wired or not, are three different places on one ellipse", [new Set(trio.map(p => p.x + "," + p.y)).size, trio.map(p => near(Math.hypot((p.x - g.cx) / sz.radius, (p.y - g.cy) / (sz.radius * C.TILT)))).every(v => v === 1)], [3, true]);
eq("place: a copy is smaller on the far side of the orbit than on the near side", C.place(sz, group, "copy", 0, 4, Math.PI / 2).size > C.place(sz, group, "copy", 0, 4, -Math.PI / 2).size, true);
eq("place: a copy is smaller than the source (counter-proof of the role)", trio.every(p => p.size < C.place(sz, group, "source", 0, 0, phase).size), true);
eq("place: with the orbit clock stopped it stays where it is", JSON.stringify(C.place(sz, group, "copy", 1, 3, C.phaseAt(5))) === JSON.stringify(C.place(sz, group, "copy", 1, 3, C.phaseAt(5))), true);

done();
