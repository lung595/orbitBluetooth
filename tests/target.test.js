imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Target = load("Target.js", ["resolve"]);

const members = ["AA:01", "AA:02", "alsa_output.usb"];
const all = () => true;

eq("nothing touched: the group", Target.resolve("", members, all), "");
eq("a member touched: that member", Target.resolve("AA:02", members, all), "AA:02");
eq("a wired member touched: that one", Target.resolve("alsa_output.usb", members, all), "alsa_output.usb");
eq("a member that left: the group", Target.resolve("AA:09", members, all), "");
eq("a member without its own level: the group", Target.resolve("AA:01", members, id => id !== "AA:01"), "");
eq("no group left: the group", Target.resolve("AA:01", [], all), "");
eq("bad input never throws", [Target.resolve(null, members, all), Target.resolve("AA:01", null, all), Target.resolve(undefined, undefined, all)], ["", "", ""]);

done();
