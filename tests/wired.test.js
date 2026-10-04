// Wired outputs for Listen together: which sinks are plugged in, how each is labelled and drawn.
// Run from the plugin root: gjs tests/wired.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const Wired = load("Wired.js");

// Made-up listings in tests/fixtures: one sink each, shaped like `pactl --format=json list sinks`
const fixture = name => new TextDecoder().decode(GLib.file_get_contents(root + "/tests/fixtures/pactl-sinks-" + name + ".json")[1]);
// Several fixtures as one listing, the way a whole desk looks
const desk = (...names) => JSON.stringify([].concat(...names.map(n => JSON.parse(fixture(n)))));
const sinksOf = text => Wired.parse(text).map(e => e.sink);
const ALL = ["usb-headset", "usb-interface", "usb-noports", "analog-unplugged", "hdmi-unplugged", "bluetooth", "virtual", "monitor", "trap"];
const HEADSET = "alsa_output.usb-Acme_Pulse_Headset_0000-00.analog-stereo";
const INTERFACE = "alsa_output.usb-Acme_Studio_2x2-00.HiFi__Line1__sink";
const DONGLE = "alsa_output.usb-Acme_Dongle_DAC-00.analog-stereo";

// One sink with the given ports and properties, for the cases a fixture would only repeat
const sink = (ports, active, props, name) => JSON.stringify([{
    "name": name || "alsa_output.usb-Acme_Test-00.analog-stereo", "description": "Test output",
    "ports": ports, "active_port": active, "properties": props || { "media.class": "Audio/Sink" }
}]);
const port = (name, availability) => availability === undefined ? { "name": name } : { "name": name, "availability": availability };

// --- The command ---------------------------------------------------------------------
eq("the exact command, an argument list", Wired.command(), ["pactl", "--format=json", "list", "sinks"]);
eq("each call gives its own list, so nobody can change the next one", (Wired.command().push("x"), Wired.command()), ["pactl", "--format=json", "list", "sinks"]);

// --- Outputs that are plugged in -------------------------------------------------------
eq("a USB headset that is plugged in", Wired.parse(fixture("usb-headset")), [{ "sink": HEADSET, "label": "Acme Pulse Headset Analog Stereo", "bus": "usb", "formFactor": "headset", "plugged": true }]);
eq("a USB audio interface (its port cannot be sensed: availability unknown)", Wired.parse(fixture("usb-interface")), [{ "sink": INTERFACE, "label": "Acme Studio 2x2 Line Out", "bus": "usb", "formFactor": "", "plugged": true }]);
eq("a USB DAC with no port at all", sinksOf(fixture("usb-noports")), [DONGLE]);
eq("a jack with nothing in it (not available)", Wired.parse(fixture("analog-unplugged")), []);
eq("an HDMI port with no screen (not available)", Wired.parse(fixture("hdmi-unplugged")), []);

// --- What is never a wired output ------------------------------------------------------
eq("a Bluetooth sink", Wired.parse(fixture("bluetooth")), []);
eq("Orbit's own virtual node", Wired.parse(fixture("virtual")), []);
eq("a monitor", Wired.parse(fixture("monitor")), []);
eq("a sink with a name made to be run by a shell", Wired.parse(fixture("trap")), []);
eq("a loopback, even named like a sound card", sinksOf(sink([], null, { "media.class": "Audio/Sink" }, "alsa_output.loopback-1234-5")), []);
eq("a monitor by its class, whatever its name", sinksOf(sink([], null, { "device.class": "monitor" })), []);
eq("a virtual node, whatever its name", sinksOf(sink([], null, { "node.virtual": "true" })), []);
eq("a node that is not a sink", sinksOf(sink([], null, { "media.class": "Audio/Source" })), []);

// --- Several at once ---------------------------------------------------------------------
eq("only the plugged wired ones, sorted by name", sinksOf(desk(...ALL)), [DONGLE, HEADSET, INTERFACE]);
eq("the order of the listing does not matter", sinksOf(desk(...ALL.slice().reverse())), [DONGLE, HEADSET, INTERFACE]);
eq("the same sink twice is one output", sinksOf(desk("usb-headset", "usb-headset")), [HEADSET]);
eq("the same name sorts by sink", Wired.parse(JSON.stringify([
    { "name": "alsa_output.b", "description": "Same", "ports": [] }, { "name": "alsa_output.a", "description": "same", "ports": [] }
])).map(e => e.sink), ["alsa_output.a", "alsa_output.b"]);
const many = JSON.stringify(Array.from({ length: 20 }, (_, i) => ({ "name": "alsa_output.dev" + (i < 10 ? "0" : "") + i, "description": "Dev " + (i < 10 ? "0" : "") + i, "ports": [] })));
eq("at most 16 outputs", [Wired.parse(many).length, sinksOf(many)[0], sinksOf(many)[15]], [16, "alsa_output.dev00", "alsa_output.dev15"]);

// --- The port that tells ---------------------------------------------------------------
eq("an available port", sinksOf(sink([port("a", "available")], "a")).length, 1);
eq("a port that is not available", sinksOf(sink([port("a", "not available")], "a")).length, 0);
eq("a port that is unknown", sinksOf(sink([port("a", "availability unknown")], "a")).length, 1);
eq("a port that says nothing", sinksOf(sink([port("a")], "a")).length, 1);
eq("only the active port counts: another one empty", sinksOf(sink([port("a", "available"), port("b", "not available")], "a")).length, 1);
eq("only the active port counts: the active one empty", sinksOf(sink([port("a", "not available"), port("b", "available")], "a")).length, 0);
eq("ports but none active: nothing to play on", [sinksOf(sink([port("a", "available")], null)).length, sinksOf(sink([port("a", "available")], "other")).length, sinksOf(sink([null], "a")).length], [0, 0, 0]);
eq("no ports key at all", sinksOf(JSON.stringify([{ "name": "alsa_output.a", "description": "x" }])), ["alsa_output.a"]);

// --- Things that must never throw ----------------------------------------------------------
eq("nothing", Wired.parse(fixture("empty")), []);
eq("a listing cut short", Wired.parse(fixture("truncated")), []);
eq("not JSON", [Wired.parse(""), Wired.parse("pactl: not found"), Wired.parse("{"), Wired.parse("[1,")], [[], [], [], []]);
eq("JSON that is not a list", [Wired.parse("{}"), Wired.parse("null"), Wired.parse("5"), Wired.parse("\"x\""), Wired.parse("true")], [[], [], [], [], []]);
eq("not text", [Wired.parse(null), Wired.parse(undefined), Wired.parse(5), Wired.parse({}), Wired.parse([])], [[], [], [], [], []]);
eq("a list of nonsense", Wired.parse(JSON.stringify([null, 5, "x", [], {}, { "name": 5 }, { "name": "alsa_output.a", "properties": null, "ports": [null] }, { "name": "alsa_output.", "ports": [] }])), []);
eq("properties of the wrong kind", sinksOf(JSON.stringify([{ "name": "alsa_output.a", "properties": "x", "ports": [] }, { "name": "alsa_output.b", "properties": [], "ports": [] }])), ["alsa_output.a", "alsa_output.b"]);
const padded = len => { const text = desk("usb-headset"); return text + " ".repeat(len - text.length); };
eq("text of exactly 200000 characters is read, one more is not", [sinksOf(padded(200000)), sinksOf(padded(200001))], [[HEADSET], []]);

// --- The sink's name ---------------------------------------------------------------------------
const named = n => sinksOf(JSON.stringify([{ "name": n, "ports": [] }]));
eq("names that are accepted", [named("alsa_output.a"), named("alsa_output.usb-Acme_X-00.HiFi__Line1__sink"), named("alsa_output.pci-0000_00_1f.3.analog-stereo"), named("alsa_output.a+b")], [["alsa_output.a"], ["alsa_output.usb-Acme_X-00.HiFi__Line1__sink"], ["alsa_output.pci-0000_00_1f.3.analog-stereo"], ["alsa_output.a+b"]]);
eq("names that are refused", [named("alsa_output."), named("alsa_input.a"), named("ALSA_OUTPUT.a"), named("x.alsa_output.a"), named("alsa_output.a b"), named("alsa_output.a;b"), named("alsa_output.a$(x)"), named("alsa_output.a\nb"), named("alsa_output.a/b"), named("alsa_output.é"), named(5), named(null)], [[], [], [], [], [], [], [], [], [], [], [], []]);
eq("150 characters after the prefix, not 151", [named("alsa_output." + "a".repeat(150)).length, named("alsa_output." + "a".repeat(151)).length], [1, 0]);

// --- The label ---------------------------------------------------------------------------------
const labelOf = d => Wired.parse(JSON.stringify([{ "name": "alsa_output.a", "description": d, "ports": [] }]))[0].label;
eq("spaces are normalised", labelOf("  Acme \t  Studio\n\n 2x2  "), "Acme Studio 2x2");
eq("control characters never reach the screen", labelOf("Acme\u0000\u001b[31m Studio\u007f\u009b"), "Acme [31m Studio");
eq("invisible and reordering characters are dropped", labelOf("Acme‮odutS​﻿ Pro"), "Acme odutS Pro");
eq("40 characters at most", [labelOf("x".repeat(100)), labelOf("y".repeat(40)).length, labelOf("z".repeat(41)).length], ["x".repeat(40), 40, 40]);
eq("a cut never ends on a space", labelOf("a".repeat(39) + " bbb"), "a".repeat(39));
eq("an emoji is never split", labelOf("a".repeat(39) + "\u{1F3A7}\u{1F3A7}"), "a".repeat(39) + "\u{1F3A7}");
eq("nothing to say: a plain name", [labelOf(""), labelOf("   "), labelOf("\u0000\u0001"), labelOf(5), labelOf(null), labelOf({})], ["Wired output", "Wired output", "Wired output", "Wired output", "Wired output", "Wired output"]);
eq("labelOf is the same helper", Wired.labelOf("  Acme\u0000 X "), "Acme X");

// --- How the connection and the form factor are read ----------------------------------------------
const entryOf = props => Wired.parse(sink([], null, props))[0];
eq("lower case and short words only", [entryOf({ "device.bus": "USB", "device.form_factor": "Headset" }).bus, entryOf({ "device.bus": "USB", "device.form_factor": "Headset" }).formFactor], ["usb", "headset"]);
eq("anything else is left out", [entryOf({ "device.bus": "usb; rm", "device.form_factor": "a".repeat(30) }).bus, entryOf({ "device.bus": 5, "device.form_factor": null }).formFactor], ["", ""]);

// --- Which picture ---------------------------------------------------------------------------------
const kind = (sinkName, bus, formFactor) => Wired.kindOf({ "sink": sinkName, "label": "x", "bus": bus || "", "formFactor": formFactor || "", "plugged": true });
eq("USB by its bus", kind("alsa_output.a", "usb"), "usb");
eq("USB by its name", kind("alsa_output.usb-Acme_X-00.analog-stereo"), "usb");
eq("HDMI and DisplayPort", [kind("alsa_output.pci-0000_01_00.1.hdmi-stereo", "pci"), kind("alsa_output.pci-0000_01_00.1.hdmi-surround"), kind("alsa_output.pci-0000_01_00.1.displayport-stereo"), kind("alsa_output.pci-0000_01_00.1.display-port")], ["hdmi", "hdmi", "hdmi", "hdmi"]);
eq("a jack by its profile or its form factor", [kind("alsa_output.pci-0000_00_1f.3.analog-stereo", "pci"), kind("alsa_output.a", "pci", "headphones"), kind("alsa_output.a", "pci", "headset"), kind("alsa_output.a", "pci", "speaker"), kind("alsa_output.a", "pci", "internal")], ["analog", "analog", "analog", "analog", "analog"]);
eq("S/PDIF and unknown cards are other", [kind("alsa_output.pci-0000_0d_00.6.iec958-stereo", "pci"), kind("alsa_output.a"), kind("alsa_output.a", "pci", "computer")], ["other", "other", "other"]);
eq("a USB device stays USB even with an HDMI or analog profile", [kind("alsa_output.usb-Acme_Dock-00.hdmi-stereo"), kind("alsa_output.a.hdmi-stereo", "usb", "headset")], ["usb", "usb"]);
eq("not an entry", [Wired.kindOf(null), Wired.kindOf(undefined), Wired.kindOf({}), Wired.kindOf({ "sink": 5, "bus": 5, "formFactor": 5 }), Wired.kindOf("alsa_output.usb-x")], ["other", "other", "other", "other", "other"]);
eq("the entries of a real listing", Wired.parse(desk(...ALL)).map(Wired.kindOf), ["usb", "usb", "usb"]);

// --- Nothing to restart when nothing changed --------------------------------------------------------
const first = Wired.parse(desk(...ALL)), again = Wired.parse(desk(...ALL.slice().reverse()));
eq("two readings of the same desk are the same set", Wired.sameSet(first, again), true);
eq("two empty readings", [Wired.sameSet([], []), Wired.sameSet(null, []), Wired.sameSet(undefined, null), Wired.sameSet([], "x")], [true, true, true, true]);
eq("an output more or less", [Wired.sameSet(first, first.slice(1)), Wired.sameSet(first.slice(1), first), Wired.sameSet(first, [])], [false, false, false]);
eq("another output", Wired.sameSet(first, first.slice(0, 2).concat(Wired.parse(desk("usb-headset")))), false);
const changed = field => Wired.sameSet(first, first.map((e, i) => i === 0 ? Object.assign({}, e, { [field]: "changed" }) : e));
eq("a renamed output is a change, so is any other field", ["sink", "label", "bus", "formFactor"].map(changed).concat(Wired.sameSet(first, first.map((e, i) => i === 0 ? Object.assign({}, e, { "plugged": false }) : e))), [false, false, false, false, false]);

done();
