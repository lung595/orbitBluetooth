.pragma library
.import "Allow.js" as Allow
.import "Codes.js" as Codes
.import "Redact.js" as Redact

// The memory ring buffer and the journal line (level 1 of the diagnostics).
// One event() call = one entry written into a fixed array: no timer, no disk,
// no network, nothing allocated again once the buffer is full. The buffer
// lives and dies with the shell process.
//
// An event is a code from Codes.js plus fields from its allowlist, never a
// sentence. Errors and warnings are also handed to console.error/warn (the
// only calls DMS keeps in its journal; the others are filtered out), tagged
// with the plugin's label so they can be found and filtered afterwards.

var CAPACITY = 200;

var _ring = new Array(CAPACITY);
var _next = 0;
var _size = 0;

// Where error and warn lines go. The console by default; a test swaps it.
var _sink = { "error": function (line) { console.error(line); }, "warn": function (line) { console.warn(line); } };

function setSink(sink) {
    _sink = sink;
}

// "E", "W", "I" or "D" from a well-formed code, else ""
function levelOf(code) {
    var m = /^[A-Z]{2,5}-([EWID])\d{3}$/.exec(typeof code === "string" ? code : "");
    return m ? m[1] : "";
}

// Records an event and returns its line (without the label), "" when the code
// is not one the plugin declared: the call is then dropped whole, so a typo
// can never turn into free text in a journal.
function event(code, fields) {
    var spec = Object.prototype.hasOwnProperty.call(Codes.CODES, code) ? Codes.CODES[code] : null;
    var level = spec ? levelOf(code) : "";
    if (!level)
        return "";
    var allowed = {};
    for (var i = 0; i < spec.fields.length; i++)
        allowed[spec.fields[i]] = Codes.FIELDS[spec.fields[i]];
    // Redact is the second wall behind the allowlist, should a word list ever
    // be edited carelessly
    var line = Redact.text([code].concat(Allow.pick(allowed, fields)).join(" "));
    _ring[_next] = { "at": Date.now(), "line": line };
    _next = (_next + 1) % CAPACITY;
    if (_size < CAPACITY)
        _size++;
    if (level === "E")
        _sink.error("[" + Codes.LABEL + "] " + line);
    else if (level === "W")
        _sink.warn("[" + Codes.LABEL + "] " + line);
    return line;
}

// The buffer, oldest first, as { at, line } copies
function entries() {
    var out = [];
    var start = _size < CAPACITY ? 0 : _next;
    for (var i = 0; i < _size; i++) {
        var e = _ring[(start + i) % CAPACITY];
        out.push({ "at": e.at, "line": e.line });
    }
    return out;
}

function clear() {
    _ring = new Array(CAPACITY);
    _next = 0;
    _size = 0;
}
