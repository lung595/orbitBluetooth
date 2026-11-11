// Prints, as JSON, the processes Listen together would run for a wired source and its copy, for tests/graph/wired_tick.py.
// Also prints the link group the tick player is given for each output (Route.tickGroup).
// usage: gjs tests/graph-commands.js <source sink> <copy sink> <copy token> <source wait ms> [nofilter]
imports.searchPath.unshift(imports.system.programPath.replace(/\/[^\/]*$/, ""));
const { load } = imports.lib;
const Together = load("Together.js");

const [from, to, token, wait, nofilter] = ARGV;
// The filter's own name is what WirePlumber would report once the process runs
// "nofilter" plans as the code did before NAK-251, the copies reading the sink: the counter-proof
const Route = load("Route.js");
const pc = nofilter ? "" : Route.wiredFilterName(from);
const sound = who => who === from ? { "sink": from, "pc": pc, "profile": "" } : { "sink": to, "pc": "", "profile": "a2dp-sink" };
const plan = Together.plan([from, token], sound, from);
// The groups come from the sinks alone, filter or not: without one the group is a name nothing carries
const groups = Object.fromEntries([from, to].map(s => [s, Route.tickGroup(s)]));
print(JSON.stringify({ "filter": pc, "commands": Together.commands(plan, {}, Number(wait)), "groups": groups }));
