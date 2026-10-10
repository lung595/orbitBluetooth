// Prints, as JSON, the outputs a volume tick plays in for one change of level, for tests/graph/device_tick.py.
// usage: gjs tests/graph-ticks.js <wired sink> <Bluetooth sink> <Bluetooth address> <hand> [old]
// <hand>: "wired" (the wired output's own level), "bluetooth" (the headset's PC level) or "group" (the group's general level).
// The wired output is the source of a Listen together group and the headset its copy, so their levels are
// shared (TogetherSession.sharedNodes). "old" ticks every shared output, as the code did before NAK-255.
imports.searchPath.unshift(imports.system.programPath.replace(/\/[^\/]*$/, ""));
const { load } = imports.lib;
const Route = load("Route.js");
const Volume = load("Volume.js");

const [wired, blue, token, hand, old] = ARGV;
const node = name => ({ "name": name, "isSink": true, "isStream": false });
const pc = node(Route.virtualName(token));
const own = node(wired);
const all = [own, node(blue), pc];
const shared = [own, pc];
const moved = hand === "wired" ? own : pc;
const reached = old ? Route.levelNodes(shared, moved) : Route.tickNodes(shared, moved, hand === "group");
const targets = Volume.tickTargets(reached.map(n => Object.assign({}, Route.tickOutput(all, n), { "level": 0.5 })));
print(JSON.stringify({ "filter": Route.filterArgs(token, blue, "Headset"), "sinks": targets.map(t => t.name) }));
