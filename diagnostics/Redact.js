.pragma library

// Anonymization (values 8 and 11). Every text that can reach the memory
// buffer, the journal, the disk or a report goes through text() first. The
// events themselves are built from an allowlist (Allow.js), so this is the
// second wall: it also cleans what the plugin does not write itself (the DMS
// journal lines, version strings, a program's own error message).

// Names the plugin learned at run time (a device, the user's login), hidden
// everywhere as "device#1", "user#1"... The numbers are stable for the session
// so two lines about the same device can still be told to belong together.
var _known = [];

function register(kind, name) {
    if (typeof name !== "string" || name.length < 2 || !/^[a-z]+$/.test(kind))
        return "";
    for (var i = 0; i < _known.length; i++) {
        if (_known[i].name.toLowerCase() === name.toLowerCase())
            return _known[i].alias;
    }
    var count = 1;
    for (var j = 0; j < _known.length; j++) {
        if (_known[j].kind === kind)
            count++;
    }
    var alias = kind + "#" + count;
    _known.push({ "kind": kind, "name": name, "alias": alias });
    return alias;
}

function forget() {
    _known = [];
}

function _escape(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// No lookbehind in these patterns on purpose: the QML engine of Quickshell
// rejects "(?<" ("Invalid regular expression") although gjs accepts it, so
// the character before a match is captured and given back instead.

// Hard cap on a line: a report is read by a person, not a parser
var MAX_LINE = 240;

var _HEX2 = "[0-9A-Fa-f]{2}";
var _RULES = [
    // Secrets first, so nothing below can cut one in half. A "key=value" or
    // "key: value" whose key says what it is, a bearer header, well-known
    // token prefixes, and any long run of hex or base64 characters.
    [/\b(token|secret|passw(?:or)?d|passwd|pwd|authkey|auth[-_]?key|api[-_]?key|apikey|credential)s?(\s*[=:]\s*)(?:"[^"]*"|'[^']*'|\S+)/gi, "$1$2<secret>"],
    [/\bBearer\s+\S+/gi, "Bearer <secret>"],
    [/\b(?:tskey|ghp|gho|ghu|ghs|ghr|github_pat|glpat|xox[abprs]|sk|pk|AKIA)[-_][A-Za-z0-9_-]{8,}/g, "<secret>"],
    [/\b[0-9A-Fa-f]{32,}\b/g, "<secret>"],
    [/\b[A-Za-z0-9+_-]{40,}={0,2}/g, "<secret>"],
    // Links with credentials, then e-mail addresses
    [/\b([a-z][a-z0-9+.-]*:\/\/)[^\s\/@]+@/gi, "$1<secret>@"],
    [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "<email>"],
    // Hardware and network addresses: Bluetooth (colon, dash and BlueZ
    // underscore forms), IPv6 then IPv4, host names of a private network
    [new RegExp("\\b(?:" + _HEX2 + "[:-]){5}" + _HEX2 + "\\b", "g"), "<mac>"],
    [new RegExp("(^|[^0-9A-Za-z])(?:" + _HEX2 + "_){5}" + _HEX2 + "(?![0-9A-Za-z])", "g"), "$1<mac>"],
    [/(^|[^0-9A-Za-z:])(?:[0-9a-f]{1,4}:){7}[0-9a-f]{1,4}(?![0-9A-Za-z:])/gi, "$1<ip>"],
    [/(^|[^0-9A-Za-z:])(?:[0-9a-f]{1,4}:){1,7}:(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})?(?:%[0-9A-Za-z]+)?(?![0-9A-Za-z:])/gi, "$1<ip>"],
    [/(^|[^0-9A-Za-z:])::(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})(?![0-9A-Za-z:])/gi, "$1<ip>"],
    // A four-part version (1.0.0.1) looks like an address and is hidden too: the safe side
    [/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, "<ip>"],
    [/\b[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:local|lan|home|internal|localdomain|home\.arpa|ts\.net)\b/gi, "<host>"],
    // The account name lives in the home folder and in the runtime folder
    [/(?:\/var)?\/home\/[^\/\s:'"]+/g, "~"],
    [/\/Users\/[^\/\s:'"]+/g, "~"],
    [/\/root\b/g, "~"],
    [/\/run\/user\/\d+/g, "/run/user/<uid>"]
];

// Hides everything personal in a text. Safe to call twice on the same text.
function text(value) {
    if (value === null || value === undefined)
        return "";
    var s = String(value).replace(/[\u0000-\u001f\u007f]/g, " ");
    // Longest first, so "Bob's AirPods Pro" goes before "Bob"
    var names = _known.slice().sort(function (a, b) {
        return b.name.length - a.name.length;
    });
    for (var i = 0; i < names.length; i++)
        s = s.replace(new RegExp(_escape(names[i].name), "gi"), names[i].alias);
    for (var j = 0; j < _RULES.length; j++)
        s = s.replace(_RULES[j][0], _RULES[j][1]);
    return s.length > MAX_LINE ? s.slice(0, MAX_LINE - 1) + "…" : s;
}

// A command line reduced to the program's name: its arguments carry paths,
// names and secrets. Takes the text of a line or the argument array of a started program.
function command(line) {
    var first = Array.isArray(line) ? line[0] : String(line === null || line === undefined ? "" : line).trim().split(/\s+/)[0];
    var name = String(first === undefined || first === null ? "" : first).split("/").pop();
    return /^[A-Za-z0-9._+-]{1,32}$/.test(name) ? name : "<cmd>";
}
