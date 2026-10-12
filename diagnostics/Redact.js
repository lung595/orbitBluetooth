.pragma library

// Anonymization (values 8 and 11). Every text that can reach the memory
// buffer, the journal, the disk or a report goes through text() first. The
// events themselves are built from an allowlist (Allow.js), so this is the
// second wall: it also cleans what the plugin does not write itself (the DMS
// journal lines, version strings, a program's own error message).

// Names the plugin learned at run time (a device, the user's login), hidden
// everywhere as "device#1", "user#1"... The numbers are stable for the session
// so two lines about the same device can still be told to belong together.
// Kept longest first, so "Bob's AirPods Pro" goes before "Bob".
var _known = [];
// Alias by name and count by kind, so registering does not walk the list
var _byName = {};
var _counts = {};
// The patterns are built on the first text after a name came in
var _stale = false;

// A Bluetooth name is 248 bytes at most. A longer one is cut there, and what
// follows it on a line is hidden with it (a pattern has a size limit).
var MAX_NAME = 248;

// How much of a raw name or text is read, in times what is kept of it: making
// one spelling of it only takes characters away (the zero-width ones, a letter
// and its accents composed into one), so there is room for three of those per
// character kept, and an endless text is still never walked whole.
var RAW_FACTOR = 4;

// What the rules write. A name never replaces a piece of one of these or of
// an alias, so cleaning a clean text again changes nothing.
var _MARKS = "<(?:secret|mac|ip|email|host|user|uid|cmd)>";

// One spelling for a name and for the text it is looked for in: composed
// letters, no zero-width character, every control character, line separator
// and odd space as a plain space (so none can forge a line), plain ASCII for
// the full-width forms, the dashes, the apostrophes and the dotless i
function _plain(s) {
    return s.normalize("NFC").replace(/[\u200b-\u200d\u2060\ufeff]/g, "")
        .replace(/[\u0000-\u001f\u007f-\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]/g, " ")
        .replace(/[\uff01-\uff5e]/g, function (c) {
            return String.fromCharCode(c.charCodeAt(0) - 0xfee0);
        })
        .replace(/[\u2010-\u2015\u2212]/g, "-").replace(/[\u2018\u2019\u02bc]/g, "'").replace(/\u0131/g, "i").replace(/\u0130/g, "I");
}

function register(kind, name) {
    // A name may come as a number or a String object from the engine
    if ((typeof name === "number" && isFinite(name)) || name instanceof String)
        name = String(name);
    if (typeof name !== "string" || !/^[a-z]+$/.test(kind))
        return "";
    // Without the spaces around it, and one space for a run of them: a line
    // of the journal does not carry the name's own spacing
    name = _plain(name.slice(0, RAW_FACTOR * MAX_NAME)).replace(/ +/g, " ").trim();
    if (!name)
        return "";
    var cut = name.length > MAX_NAME;
    if (cut)
        name = name.slice(0, MAX_NAME);
    var key = "=" + name.toLowerCase();
    if (_byName[key])
        return _byName[key];
    _counts[kind] = (_counts[kind] || 0) + 1;
    var alias = kind + "#" + _counts[kind];
    _byName[key] = alias;
    _known.push({ "name": name, "alias": alias, "cut": cut, "ruled": false });
    // The rules run before the names, so a name they change ("Bob@home" is
    // an account to them) is also looked for as they leave it
    var ruled = _rules(name);
    if (ruled !== name && /[0-9A-Za-z]/.test(ruled.replace(new RegExp(_MARKS, "g"), "")))
        _known.push({ "name": ruled, "alias": alias, "cut": cut, "ruled": true });
    _stale = true;
    return alias;
}

function forget() {
    _known = [];
    _byName = {};
    _counts = {};
}

function _escape(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// The pattern of a name: any case, its spaces as the journal may write them
// (several, "_", "%20", "\x20"), its quotes escaped or not. A single
// character is hidden only where it stands alone, or it would hide every such
// letter of the text and the first digit of a version.
// The only group of the pattern is what stands before the name (empty for a
// longer name): it is set where a name was found, and not where a mark or an
// alias was, which is left as it is.
function _pattern(known, kept) {
    var body = _escape(known.name).replace(/ /g, "(?:[ _]|%20|\\\\x20)+").replace(/['"]/g, "\\\\?$&") + (known.cut ? ".*" : "");
    if (known.name.length < 2)
        body = "(^|[^0-9A-Za-z#.])" + body + "(?![0-9A-Za-z]|\\.[0-9A-Za-z])";
    else
        body = "()" + body;
    // What the rules wrote goes first, except for a name that holds some
    return new RegExp(known.ruled ? body + "|" + kept : kept + "|" + body, "gi");
}

function _prepare() {
    var kept = "(?:" + _MARKS + "|(?:" + Object.keys(_counts).join("|") + ")#[0-9]+)";
    _known.sort(function (a, b) {
        return b.name.length - a.name.length;
    });
    for (var i = 0; i < _known.length; i++)
        _known[i].pattern = _pattern(_known[i], kept);
    _stale = false;
}

function _names(s) {
    if (_stale)
        _prepare();
    for (var i = 0; i < _known.length; i++) {
        var known = _known[i];
        s = s.replace(known.pattern, function (all, lead) {
            return lead === undefined ? all : lead + known.alias;
        });
    }
    return s;
}

// No lookbehind in these patterns on purpose: the QML engine of Quickshell
// rejects "(?<" ("Invalid regular expression") although gjs accepts it, so
// the character before a match is captured and given back instead.

// Hard cap on a line: a report is read by a person, not a parser
var MAX_LINE = 240;

// What is read of a text at most: the rest could not be shown anyway, and
// some rules take a time that grows with the square of the length
var MAX_INPUT = 1024;

var _HEX2 = "[0-9A-Fa-f]{2}";
// A key that says its value is a secret. It may be prefixed (access_token).
var _PREFIX = "(?:[A-Za-z0-9]{1,32}[-_])";
var _NAMED = "token|secret|passw(?:or)?d|pwd|passphrase|passkey|passcode|pincode|psk|credential|cookie|session[-_]?id|(?:auth|api)[-_]?key";
// "key" and "pin" alone are also everyday words, so they have a rule of their
// own below. With a prefix (wifi_key) they are keys like the others.
var _BARE = "(?:key|pin)";
var _KEY = _PREFIX + "{0,4}(?:" + _NAMED + "|" + _PREFIX + _BARE + ")";
var _VALUE = "(?:\"[^\"]*\"|'[^']*'|<secret>|\\S+)";
var _SIGN = "([\"']?\\s*[=:]\\s*)";
// Where a value ends
var _END = "(?![^\\s,;)])";
// A value that says how things went is not a secret and not an account
var _STATE = "(?:failed|failure|ok|success|succeeded|denied|refused|error|timeout|true|false|yes|no|none|null)";
// What follows a bare "key" or "pin" and is no secret: a state ("pin: yes"),
// the dotted name of a property ("key: api.bluez5.codec"), the name of a
// keyboard key ("key: Enter pressed"). Anything else is hidden.
var _PLAIN_VALUE = "(?:(?:" + _STATE + "|[a-z]+(?:\\.[a-z][a-z0-9_-]*)+)" + _END + "|[a-z]\\w* (?:pressed|released)\\b)";
// A folder of /mnt that is named after what it holds, not after an account
var _MOUNT = "(?:data|disk|usb|backup|storage|share|nas|cdrom|windows)";
var _RULES = [
    // Secrets first, so nothing below can cut one in half. A "key=value" or
    // "key: value" whose key says what it is (quoted or not, as in JSON), a
    // pairing code after its name, an authorization header, well-known token
    // prefixes, and any long run of hex or base64 characters.
    [new RegExp("\\b(" + _KEY + ")" + _SIGN + _VALUE, "gi"), "$1$2<secret>"],
    [new RegExp("\\b(_?" + _BARE + ")" + _SIGN + "(?!" + _PLAIN_VALUE + ")" + _VALUE, "gi"), "$1$2<secret>"],
    // A plural key with a small number is a count ("pins: 3"), not a secret
    [new RegExp("\\b(" + _PREFIX + "{0,4}(?:" + _NAMED + "|" + _BARE + ")s)" + _SIGN + "(?!\\d{1,3}(?![^\\s,;]))" + _VALUE, "gi"), "$1$2<secret>"],
    [/\b(pin(?:code)?|passkey|passcode|pairing code)(\s+)\d{4,8}\b/gi, "$1$2<secret>"],
    [/\b(authorization["']?\s*[=:]\s*)(?:(?:Basic|Bearer|Digest)\s+)?\S+/gi, "$1<secret>"],
    [/\bBearer\s+\S+/gi, "Bearer <secret>"],
    // Base64 after "Basic": long, padded, or short with a digit in it
    [/\bBasic\s+(?:[A-Za-z0-9+\/]{16,}={0,2}|[A-Za-z0-9+\/]{2,}={1,2}|(?=[A-Za-z+\/]*[0-9+\/])[A-Za-z0-9+\/]{4,})/g, "Basic <secret>"],
    [/\b(?:tskey|ghp|gho|ghu|ghs|ghr|github_pat|glpat|xox[abprs]|sk|pk|AKIA)[-_][A-Za-z0-9_-]{8,}/g, "<secret>"],
    [/\b[0-9A-Fa-f]{32,}\b/g, "<secret>"],
    [/\b[A-Za-z0-9+_-]{40,}={0,2}/g, "<secret>"],
    // Links with credentials, then e-mail addresses
    [/\b([a-z][a-z0-9+.-]*:\/\/)[^\s\/@]+@/gi, "$1<secret>@"],
    [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "<email>"],
    // Hardware and network addresses: Bluetooth (colon, dash and BlueZ
    // underscore forms), IPv6 then IPv4, host names of a private network
    [new RegExp("(?:" + _HEX2 + "[:-]){5}" + _HEX2 + "\\b", "g"), "<mac>"],
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
    // (also written without its first slash)
    [/(^|[^A-Za-z0-9_.-])(?:\/var)?\/?home\/[^\/\s:'"]+/g, "$1~"],
    [/\/Users\/[^\/\s:'"]+/g, "~"],
    [/\/root\b/g, "~"],
    [/\/run\/user\/\d+/g, "/run/user/<uid>"],
    // And outside the home folder: a drive mounted for the account (/media
    // at the root only, /usr/share/media is not one), the accounts service,
    // "~name", "name@machine", "uid=1000(name)", "user=name" (but not
    // "login: failed" or "user=42"), "for user name" (but not "by user request")
    [/(^|[^A-Za-z0-9_.~-]|\/run)(\/media)\/[^\/\s:'"]+/g, "$1$2/<user>"],
    [new RegExp("(\\/mnt)\\/(?!" + _MOUNT + "(?![^\\/\\s:'\"]))[^\\/\\s:'\"]+", "g"), "$1/<user>"],
    [/(\/AccountsService\/(?:users|icons))\/[^\/\s:'"]+/g, "$1/<user>"],
    [/(=\d+)\([^)\s]+\)/g, "$1(<user>)"],
    [/(^|[^0-9A-Za-z\/.~])~[A-Za-z_][A-Za-z0-9_.-]*/g, "$1~"],
    [/\b[A-Za-z_][A-Za-z0-9_.-]*@[A-Za-z0-9][A-Za-z0-9.-]*/g, "<user>@<host>"],
    [new RegExp("\\b(user(?:name)?|login|logname)(\\s*[=:]\\s*)(?!" + _STATE + "\\b|\\d+" + _END + ")[^\\s<]\\S*", "gi"), "$1$2<user>"],
    [/\b((?:for|as|by|of) user)(\s+)(?!(?:request|interface|input|action|session|space)\b)[^\s<]\S*/gi, "$1$2<user>"]
];

function _rules(s) {
    for (var j = 0; j < _RULES.length; j++)
        s = s.replace(_RULES[j][0], _RULES[j][1]);
    return s;
}

// The rules first: a device may be named like a word they look for ("home",
// "token"), and replacing it before them would let the secret after it out
function _clean(s) {
    return _names(_rules(s));
}

// How many characters two texts start with in common
function _shared(a, b) {
    var n = 0;
    while (n < a.length && a[n] === b[n])
        n++;
    return n;
}

// Hides everything personal in a text. Cleaning a clean text again changes
// nothing. A text longer than MAX_INPUT is cut there, which may cut a name or
// a secret in half and let its first half read as plain text. So the text is
// also cleaned with MAX_NAME more characters in sight, and what the two
// results do not share (that half, seen whole the second time) is left out.
function text(value) {
    if (value === null || value === undefined)
        return "";
    var all = _plain(String(value).slice(0, RAW_FACTOR * MAX_INPUT));
    var s = _clean(all.slice(0, MAX_INPUT));
    if (all.length > MAX_INPUT)
        s = s.slice(0, _shared(s, _clean(all.slice(0, MAX_INPUT + MAX_NAME))));
    return s.length > MAX_LINE ? s.slice(0, MAX_LINE - 1) + "…" : s;
}

// A command line reduced to the program's name: its arguments carry paths,
// names and secrets. Takes the text of a line or the argument array of a started program.
function command(line) {
    var first = Array.isArray(line) ? line[0] : String(line === null || line === undefined ? "" : line).trim().split(/\s+/)[0];
    var name = String(first === undefined || first === null ? "" : first).split("/").pop();
    return /^[A-Za-z0-9._+-]{1,32}$/.test(name) ? name : "<cmd>";
}
