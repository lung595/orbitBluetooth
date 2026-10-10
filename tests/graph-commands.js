// Prints, as JSON, the processes Listen together would run for a wired source and its copy, for tests/graph/wired_tick.py.
// usage: gjs tests/graph-commands.js <source sink> <copy sink> <copy token> <source wait ms> [nofilter]
imports.searchPath.unshift(imports.system.programPath.replace(/\/[^\/]*$/, ""));
const { load } = imports.lib;
const Together = load("Together.js");

const [from, to, token, wait, nofilter] = ARGV;
// The filter's own name is what WirePlumber would report once the process runs
// "nofilter" plans as the code did before NAK-251, the copies reading the sink: the counter-proof
const pc = nofilter ? "" : load("Route.js").wiredFilterName(from);
const sound = who => who === from ? { "sink": from, "pc": pc, "profile": "" } : { "sink": to, "pc": "", "profile": "a2dp-sink" };
const plan = Together.plan([from, token], sound, from);
print(JSON.stringify({ "filter": pc, "commands": Together.commands(plan, {}, Number(wait)) }));
