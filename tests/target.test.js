imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Target = load("Target.js", ["resolve", "expect", "isEcho", "fromHeadset"]);

const members = ["AA:01", "AA:02", "alsa_output.usb"];
const all = () => true;

eq("nothing touched: the group", Target.resolve("", members, all), "");
eq("a member touched: that member", Target.resolve("AA:02", members, all), "AA:02");
eq("a wired member touched: that one", Target.resolve("alsa_output.usb", members, all), "alsa_output.usb");
eq("a member that left: the group", Target.resolve("AA:09", members, all), "");
eq("a member without its own level: the group", Target.resolve("AA:01", members, id => id !== "AA:01"), "");
eq("no group left: the group", Target.resolve("AA:01", [], all), "");
eq("bad input never throws", [Target.resolve(null, members, all), Target.resolve("AA:01", null, all), Target.resolve(undefined, undefined, all)], ["", "", ""]);

// A level Orbit or the keys wrote comes back within the window: an echo
let book = Target.expect({}, "bluez_output.AA_01", 0.5, 1000);
eq("the write coming back is an echo", Target.isEcho(book, "bluez_output.AA_01", 0.5, 1100), true);
eq("a headset rounding it (1/127) is still an echo", Target.isEcho(book, "bluez_output.AA_01", 0.496, 1100), true);
eq("another level is not", Target.isEcho(book, "bluez_output.AA_01", 0.6, 1100), false);
eq("another node is not", Target.isEcho(book, "bluez_output.AA_02", 0.5, 1100), false);
eq("late, it is not", Target.isEcho(book, "bluez_output.AA_01", 0.5, 1501), false);
eq("no book never throws", [Target.isEcho(null, "x", 0.5, 0), Target.expect(null, "x", 0.5, 0).x.length], [false, 1]);

// A fast run of presses: every level written comes back, in any order
book = Target.expect(Target.expect(book, "bluez_output.AA_01", 0.55, 1100), "bluez_output.AA_01", 0.6, 1200);
eq("a run of presses: the first echo", Target.isEcho(book, "bluez_output.AA_01", 0.5, 1250), true);
eq("a run of presses: the last echo", Target.isEcho(book, "bluez_output.AA_01", 0.6, 1250), true);
book = Target.expect(book, "bluez_output.AA_02", 0.3, 1701);
eq("the book forgets old writes", book, { "bluez_output.AA_02": [{ "v": 0.3, "at": 1701 }] });

// Reading what the headset did
book = Target.expect({}, "n", 0.5, 1000);
eq("the first read is a start, not a change", Target.fromHeadset(book, "n", null, 0.7, 5000), false);
eq("a read before any value (NaN) is not a change", Target.fromHeadset({}, "n", NaN, 0.7, 5000), false);
eq("a level that moved with nobody writing: the headset", Target.fromHeadset({}, "n", 0.5, 0.55, 5000), true);
eq("the same level again: nothing", Target.fromHeadset({}, "n", 0.5, 0.5, 5000), false);
eq("a level Orbit just wrote: not the headset", Target.fromHeadset(book, "n", 0.4, 0.5, 1100), false);
eq("the same level long after the write: the headset", Target.fromHeadset(book, "n", 0.4, 0.5, 2000), true);

done();
