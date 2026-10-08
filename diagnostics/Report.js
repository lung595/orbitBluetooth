.pragma library
.import "Allow.js" as Allow
.import "Codes.js" as Codes
.import "Cpu.js" as Cpu
.import "Log.js" as Log
.import "Redact.js" as Redact

// Builds the anonymous report a person pastes into a GitHub issue (level 2).
// Pure: the caller gathers the facts when the report is asked for and hands
// them over; nothing is read, written or sent from here. Every piece of text
// goes through the allowlist and Redact, so what comes out holds versions,
// states and codes, and nothing that identifies a person or a machine.

// "Oct 08 12:00:00 <host> qs[123]: " as journalctl writes it by default
var SYSLOG_PREFIX = /^\w{3} [ \d]\d \d\d:\d\d:\d\d \S+ \S+: /;

// A version or a distribution name: letters, digits and a few separators
function _version(v) {
    var s = typeof v === "string" ? v.trim() : "";
    return /^[A-Za-z0-9 ._+~()\/-]{1,48}$/.test(s) ? Redact.text(s) : "?";
}

function _two(n) {
    return (n < 10 ? "0" : "") + n;
}

// UTC, so the report does not tell where the person lives
function _clock(ms) {
    var d = new Date(ms);
    return _two(d.getUTCHours()) + ":" + _two(d.getUTCMinutes()) + ":" + _two(d.getUTCSeconds());
}

function _stamp(ms) {
    var d = new Date(ms);
    return d.getUTCFullYear() + "-" + _two(d.getUTCMonth() + 1) + "-" + _two(d.getUTCDate()) + " " + _clock(ms) + " UTC";
}

// info = {
//   now: ms, plugin: version text,
//   versions: { dms, quickshell, qt, niri, distro },
//   surfaces: { widget: bool, ... }, settings: { key: value }, facts: { key: value },
//   cpu: { percent, windowMs } or null, journal: [ lines from the DMS journal ]
// }
// Anything missing is shown as "?" or left out; nothing throws.
function build(info) {
    var i = info || {};
    var v = i.versions || {};
    var now = typeof i.now === "number" ? i.now : Date.now();
    var active = [];
    for (var s = 0; s < Codes.SURFACES.length; s++) {
        if (i.surfaces && i.surfaces[Codes.SURFACES[s]] === true)
            active.push(Codes.SURFACES[s]);
    }
    var out = [
        Codes.PLUGIN + " diagnostic report (anonymous: versions, states and codes only)",
        "Created      : " + _stamp(now),
        "Plugin       : " + Codes.PLUGIN + " " + _version(i.plugin),
        "DMS          : " + _version(v.dms) + "   Quickshell : " + _version(v.quickshell) + "   Qt : " + _version(v.qt),
        "Compositor   : niri " + _version(v.niri),
        "Distribution : " + _version(v.distro),
        "Surfaces     : " + (active.length ? active.join(", ") + " (active)" : "none active"),
        "Settings     : " + Allow.pick(Codes.SETTINGS, i.settings).join(" "),
        "State        : " + Allow.pick(Codes.FACTS, i.facts).join(" "),
        "CPU          : " + Cpu.line(i.cpu)
    ];
    var events = Log.entries();
    out.push("Last events (" + events.length + " of " + Log.CAPACITY + " kept, oldest first, UTC):");
    if (!events.length)
        out.push("  none");
    for (var e = 0; e < events.length; e++)
        out.push("  " + _clock(events[e].at) + " " + events[e].line);
    var lines = Array.isArray(i.journal) ? i.journal : [];
    // The journal only carries what the plugin tagged, but the engine's own
    // errors name files and folders: cleaned like everything else. The short
    // journalctl format starts with the machine name, which no pattern could
    // recognise, so that prefix is cut off first. A device name in an engine
    // line is hidden only once registered (Redact.register): the caller does so.
    var tag = "[" + Codes.LABEL + "]";
    var kept = lines.filter(function (l) {
        return typeof l === "string" && (l.indexOf(tag) >= 0 || l.indexOf(Codes.PLUGIN) >= 0);
    }).slice(-50);
    out.push("Journal lines (anonymized, " + kept.length + " kept, last 50 at most):");
    if (!kept.length)
        out.push("  none");
    for (var k = 0; k < kept.length; k++)
        out.push("  " + Redact.text(kept[k].replace(SYSLOG_PREFIX, "")));
    return out.join("\n") + "\n";
}
