// Prints, as JSON, the processes Listen together would run for a wired source and its copy, for tests/graph/wired_copy.py.
// usage: gjs tests/graph-commands.js <source sink> <copy sink> <copy token> <source wait ms>
imports.searchPath.unshift(imports.system.programPath.replace(/\/[^\/]*$/, ""));
const { load } = imports.lib;
const Together = load("Together.js");
const Route = load("Route.js");

const [from, to, token, wait] = ARGV;
// The filter's own name is what WirePlumber would report once the process runs
const pc = Route.wiredFilterName(from);
const sound = who => who === from ? { "sink": from, "pc": pc, "profile": "" } : { "sink": to, "pc": "", "profile": "a2dp-sink" };
const plan = Together.plan([from, token], sound, from);
print(JSON.stringify({ "filter": pc, "commands": Together.commands(plan, {}, Number(wait)) }));
