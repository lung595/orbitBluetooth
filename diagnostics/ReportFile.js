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

// A list longer than this is not read at all (and the journal is left out):
// a machine knows some dozens of devices, and every name of every one is
// looked for in every journal line
var MAX_LIST = 256;

// The last moment a four-digit year can write
var MAX_TIME = Date.UTC(9999, 11, 31, 23, 59, 59);

// The properties of a device that may hold a name somebody chose or a model
// ("deviceName" is Quickshell's). They are only ever registered with Redact,
// never written.
var NAMES = ["name", "deviceName", "alias", "model"];
// And any other property called like one. A name that is neither a text nor
// a number (an object, a nested list) cannot be hidden: the device is then
// not readable, and the journal lines are left out.
var NAMED = /name|alias|model|title|label|nick/i;
var MAX_NAMES = 16;

// A time a file name and a report can write: a number of this era, or now
function _time(now) {
    return typeof now === "number" && now >= 0 && now <= MAX_TIME ? now : Date.now();
}

// "orbit-report-20261008-120341Z.txt": the plugin's label and the time, UTC
// so the name does not tell where the person lives. Nothing of the machine,
// the account or a device. A time that is not one gives the present.
function fileName(now) {
    // "2026-10-08T12:03:41.000Z" without its marks and its milliseconds
    var stamp = new Date(_time(now)).toISOString().slice(0, 19).replace(/[-:]/g, "").replace("T", "-");
    return Codes.LABEL + "-report-" + stamp + "Z.txt";
}

// Registers every name of a device and returns the alias to call it by
// ("device" when it has no name)
function _alias(device) {
    var alias = "";
    // A list of bare names instead of objects
    if (typeof device === "string")
        return Redact.register("device", device) || "device";
    if (!device || typeof device !== "object")
        return "device";
    var keys = NAMES.slice();
    for (var key in device) {
        if (NAMED.test(key) && keys.indexOf(key) < 0 && keys.length < MAX_NAMES)
            keys.push(key);
    }
    for (var n = 0; n < keys.length; n++) {
        var value = device[keys[n]];
        if (value === null || value === undefined || typeof value === "function" || typeof value === "boolean")
            continue;
        if (!_nameable(value))
            throw new Error("a name that cannot be read");
        var a = Redact.register("device", value);
        if (!alias)
            alias = a;
    }
    return alias || "device";
}

// A name Redact can hide: a text, a number, or a short list of those
function _nameable(value) {
    if (Array.isArray(value))
        return value.length <= 8 && value.every(function (v) { return !Array.isArray(v) && _nameable(v); });
    return typeof value === "string" || value instanceof String || (typeof value === "number" && isFinite(value));
}

// The devices as an array, or null when they cannot be read: a JS array, a
// QML list (a length and indexes) or a model (count and get). No list at all
// is an empty one.
function _list(list) {
    if (list === null || list === undefined)
        return [];
    if (Array.isArray(list))
        return list.length <= MAX_LIST ? list : null;
    if (typeof list !== "object")
        return null;
    var byGet = typeof list.get === "function";
    var size = byGet ? list.count : list.length;
    if (typeof size !== "number" || !(size >= 0 && size <= MAX_LIST))
        return null;
    var out = [];
    for (var d = 0; d < size; d++)
        out.push(byGet ? list.get(d) : list[d]);
    return out;
}

// The "Devices" lines, and whether every name could be read and registered.
// When not (a list that is not one, an accessor that throws) the names are
// unknown, so nothing can hide them in a journal line: the caller leaves the
// journal out.
function _read(list) {
    var all = null;
    try {
        all = _list(list);
    } catch (e) {}
    if (!all)
        return { "lines": ["Devices (not readable, journal lines left out):", "  none"], "hidden": false };
    var connected = 0;
    var unread = 0;
    var lines = [];
    for (var d = 0; d < all.length; d++) {
        var line = "device ?";
        try {
            // The alias is Redact's and the facts are the allowlist's: the
            // line is written as it is, so a device named "aac" or "yes"
            // cannot change a word of it
            var alias = _alias(all[d]);
            var facts = Allow.pick(Codes.DEVICE, all[d]);
            if (all[d] && all[d].connected === true)
                connected++;
            line = alias + " " + (facts.length ? facts.join(" ") : "?");
        } catch (e) {
            unread++;
        }
        if (d < MAX_DEVICES)
            lines.push("  " + line);
    }
    var notes = [all.length + " known", connected + " connected"];
    if (all.length > MAX_DEVICES)
        notes.push("first " + MAX_DEVICES + " shown");
    if (unread)
        notes.push(unread + " not readable, journal lines left out");
    return { "lines": ["Devices (" + notes.join(", ") + "):"].concat(lines.length ? lines : ["  none"]), "hidden": !unread };
}

// The "Devices" lines. Every device's names are registered, shown or not, so
// none of them survives in a journal line; call it before Report.build.
function devices(list) {
    return _read(list).lines;
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
//   devices: [ { name, deviceName, alias, model: hidden, never written;
//                and the keys of Codes.DEVICE } ]
// Anything missing is shown as "?" or left out. A device that cannot be read
// is a "?" and takes the journal lines away with it; it does not throw.
function build(info) {
    var i = {};
    try {
        var from = info && typeof info === "object" ? info : {};
        for (var key in from)
            i[key] = from[key];
    } catch (e) {
        // What could not be read is left out, like anything missing
        i = {};
    }
    i.now = _time(i.now);
    // First, so the names are known when Report.build cleans the journal
    var read = _read(i.devices);
    if (!read.hidden)
        i.journal = [];
    return Report.build(i) + read.lines.concat(errors()).join("\n") + "\n";
}
