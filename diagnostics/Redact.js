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

// A Bluetooth name is 248 bytes at most. A longer one is cut there, and what
// follows it on a line is hidden with it (a pattern has a size limit).
var MAX_NAME = 248;

// One spelling for a name and for the text it is looked for in: composed
// letters, no zero-width character, every control character, line separator
// and odd space as a plain space (so none can forge a line), a plain apostrophe
function _plain(s) {
    return s.normalize("NFC").replace(/[\u200b-\u200d\u2060\ufeff]/g, "").replace(/[\u0000-\u001f\u007f-\u00a0\u2028\u2029\u202f\u3000]/g, " ").replace(/[\u2018\u2019\u02bc]/g, "'");
}

function register(kind, name) {
    // A name may come as a number or a String object from the engine
    if ((typeof name === "number" && isFinite(name)) || name instanceof String)
        name = String(name);
    if (typeof name !== "string" || !/^[a-z]+$/.test(kind))
        return "";
    // Without the spaces around it, and one space for a run of them: a line
    // of the journal does not carry the name's own spacing
    name = _plain(name).replace(/ +/g, " ").trim();
    if (!name)
        return "";
    var cut = name.length > MAX_NAME;
    if (cut)
        name = name.slice(0, MAX_NAME);
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
    var body = _escape(name).replace(/ /g, " +");
    // A single character is hidden where it stands alone, or it would hide
    // every such letter of the text (and the digit of an alias)
    var pattern = name.length < 2 ? new RegExp("(^|[^0-9A-Za-z#])" + body + "(?![0-9A-Za-z])", "gi") : new RegExp(body + (cut ? ".*" : ""), "gi");
    _known.push({ "kind": kind, "name": name, "alias": alias, "pattern": pattern, "by": name.length < 2 ? "$1" + alias : alias });
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
    // The key may be prefixed (access_token), quoted (JSON), or a pairing code.
    [/\b((?:[A-Za-z0-9]+[-_])*(?:token|secret|passw(?:or)?d|passwd|pwd|passphrase|passkey|pin(?:code)?|authkey|auth[-_]?key|api[-_]?key|apikey|credential|cookie|session[-_]?id))s?(["']?\s*[=:]\s*)(?:"[^"]*"|'[^']*'|<secret>|\S+)/gi, "$1$2<secret>"],
    [/\bBearer\s+\S+/gi, "Bearer <secret>"],
    [/\bBasic\s+[A-Za-z0-9+\/]{16,}={0,2}/g, "Basic <secret>"],
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
    // The same address written with spaces, in a link (%3A), in three dotted
    // groups, or as twelve digits in a row (also when a letter follows)
    [new RegExp("(^|[^0-9A-Za-z])(?:" + _HEX2 + "(?:%3[Aa]| )){5}" + _HEX2 + "(?![0-9A-Za-z])", "g"), "$1<mac>"],
    [/(^|[^0-9A-Za-z.])(?:[0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}(?![0-9A-Za-z.])/g, "$1<mac>"],
    [/(^|[^0-9A-Fa-f])[0-9A-Fa-f]{12}(?![0-9A-Fa-f])/g, "$1<mac>"],
    [/(^|[^0-9A-Za-z:])(?:[0-9a-f]{1,4}:){7}[0-9a-f]{1,4}(?![0-9A-Za-z:])/gi, "$1<ip>"],
    [/(^|[^0-9A-Za-z:])(?:[0-9a-f]{1,4}:){1,7}:(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})?(?:%[0-9A-Za-z]+)?(?![0-9A-Za-z:])/gi, "$1<ip>"],
    [/(^|[^0-9A-Za-z:])::(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})(?![0-9A-Za-z:])/gi, "$1<ip>"],
    // What is left of an address once the IPv6 forms are gone: four or five
    // of its six parts, or a part written with one digit (a time has three)
    [/(^|[^0-9A-Za-z:])(?:[0-9A-Fa-f]{1,2}:){3,5}[0-9A-Fa-f]{1,2}(?![0-9A-Za-z:])/g, "$1<mac>"],
    [new RegExp("\\b(?:" + _HEX2 + "-){3,4}" + _HEX2 + "\\b", "g"), "<mac>"],
    // A four-part version (1.0.0.1) looks like an address and is hidden too: the safe side
    [/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, "<ip>"],
    [/\b[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:local|lan|home|internal|localdomain|home\.arpa|ts\.net)\b/gi, "<host>"],
    // The account name lives in the home folder and in the runtime folder
    [/(?:\/var)?\/home\/[^\/\s:'"]+/g, "~"],
    [/\/Users\/[^\/\s:'"]+/g, "~"],
    [/\/root\b/g, "~"],
    [/\/run\/user\/\d+/g, "/run/user/<uid>"],
    // And outside the home folder: a drive mounted for the account, "~name",
    // "name@machine", "user=name"
    [/(\/(?:run\/)?media)\/[^\/\s:'"]+/g, "$1/<user>"],
    [/(^|[^0-9A-Za-z\/.~])~[A-Za-z_][A-Za-z0-9_.-]*/g, "$1~"],
    [/\b[A-Za-z_][A-Za-z0-9_.-]*@[A-Za-z0-9][A-Za-z0-9.-]*/g, "<user>@<host>"],
    [/\b(user(?:name)?|login|logname)(\s*[=:]\s*)[^\s<]\S*/gi, "$1$2<user>"]
];

// Hides everything personal in a text. Safe to call twice on the same text.
function text(value) {
    if (value === null || value === undefined)
        return "";
    var s = _plain(String(value));
    // Longest first, so "Bob's AirPods Pro" goes before "Bob"
    var names = _known.slice().sort(function (a, b) {
        return b.name.length - a.name.length;
    });
    for (var i = 0; i < names.length; i++)
        s = s.replace(names[i].pattern, names[i].by);
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
