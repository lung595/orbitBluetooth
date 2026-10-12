.pragma library
.import "Allow.js" as Allow
.import "Codes.js" as Codes
.import "Log.js" as Log
.import "Redact.js" as Redact
.import "Report.js" as Report

// The report as a file a person attaches to a GitHub issue: Report.build's
// text, then what a clipboard report leaves out because it is longer, the
// devices (kind, link, codec, batteries) and the errors counted by code.
// Pure, like Report.js: the caller reads the state and writes the file;
// nothing is read, written or sent from here.
//
// A device is written from the allowlist Codes.DEVICE only, so its name, its
// address and anything else the caller leaves on the object cannot get in.
// It is called "device#2", the alias Redact gives its name, which is also
// what replaces that name in a journal line: the two can be told to be the
// same device without either saying which.

// A report is read by a person: past this many devices the rest is counted
var MAX_DEVICES = 32;

// The properties of a device that may hold a name somebody chose or a model.
// They are only ever registered with Redact, never written.
var NAMES = ["name", "alias", "model"];

function _two(n) {
    return (n < 10 ? "0" : "") + n;
}

// "orbit-report-20261008-120341Z.txt": the plugin's label and the time, UTC
// so the name does not tell where the person lives. Nothing of the machine,
// the account or a device. A time that is not one gives the present.
function fileName(now) {
    var d = new Date(typeof now === "number" && isFinite(now) ? now : Date.now());
    if (isNaN(d.getTime()))
        d = new Date();
    return Codes.LABEL + "-report-" + d.getUTCFullYear() + _two(d.getUTCMonth() + 1) + _two(d.getUTCDate())
        + "-" + _two(d.getUTCHours()) + _two(d.getUTCMinutes()) + _two(d.getUTCSeconds()) + "Z.txt";
}

// Registers every name of a device and returns the alias to call it by
// ("device" when it has no name long enough to be hidden)
function _alias(device) {
    var alias = "";
    if (!device || typeof device !== "object")
        return "device";
    for (var n = 0; n < NAMES.length; n++) {
        var a = Redact.register("device", device[NAMES[n]]);
        if (!alias)
            alias = a;
    }
    return alias || "device";
}

// The "Devices" lines. Every device's names are registered, shown or not, so
// none of them survives in a journal line; call it before Report.build.
function devices(list) {
    var all = Array.isArray(list) ? list : [];
    var connected = 0;
    var lines = [];
    for (var d = 0; d < all.length; d++) {
        var alias = _alias(all[d]);
        if (all[d] && all[d].connected === true)
            connected++;
        if (d >= MAX_DEVICES)
            continue;
        var facts = Allow.pick(Codes.DEVICE, all[d]);
        // Redact is the second wall, as in Log.event
        lines.push("  " + Redact.text(alias + " " + (facts.length ? facts.join(" ") : "?")));
    }
    var head = "Devices (" + all.length + " known, " + connected + " connected" + (all.length > MAX_DEVICES ? ", first " + MAX_DEVICES + " shown" : "") + "):";
    return [head].concat(lines.length ? lines : ["  none"]);
}

// The errors and warnings of the memory buffer, counted by code: what went
// wrong and how often, at a glance, above the events in order
function errors() {
    var events = Log.entries();
    var counts = {};
    var total = 0;
    for (var e = 0; e < events.length; e++) {
        var code = events[e].line.split(" ")[0];
        var level = Log.levelOf(code);
        if (level !== "E" && level !== "W")
            continue;
        counts[code] = (counts[code] || 0) + 1;
        total++;
    }
    var out = ["Errors and warnings (" + total + " among the " + events.length + " events kept):"];
    var codes = Object.keys(counts).sort();
    if (!codes.length)
        out.push("  none");
    for (var c = 0; c < codes.length; c++)
        out.push("  " + codes[c] + " x" + counts[codes[c]] + " (" + Codes.CODES[codes[c]].text + ")");
    return out;
}

// info = what Report.build takes, plus
//   devices: [ { name, alias, model: hidden, never written;
//                and the keys of Codes.DEVICE } ]
// Anything missing is shown as "?" or left out; nothing throws.
function build(info) {
    var i = info && typeof info === "object" ? info : {};
    // First, so the names are known when Report.build cleans the journal
    var deviceLines = devices(i.devices);
    return Report.build(i) + deviceLines.concat(errors()).join("\n") + "\n";
}
