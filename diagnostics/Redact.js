.pragma library
.import "RedactRules.js" as Rules

// Anonymization (values 8 and 11). Every text that can reach the memory
// buffer, the journal, the disk or a report goes through text() first. The
// events themselves are built from an allowlist (Allow.js), so this is the
// second wall: it also cleans what the plugin does not write itself (the DMS
// journal lines, version strings, a program's own error message).
// The rules (what is hidden whatever the machine) are in RedactRules.js; the
// names learned at run time are here.

// Names the plugin learned at run time (a device, the account, the machine),
// hidden everywhere as "device#1", "user#1", "host#1"... The numbers are
// stable for the session so two lines about the same device can still be told
// to belong together. Kept longest first, so "Bob's AirPods Pro" goes before "Bob".
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

// Hard cap on a line: a report is read by a person, not a parser
var MAX_LINE = 240;

// What is read of a text at most: the rest could not be shown anyway, and
// some rules take a time that grows with the square of the length
var MAX_INPUT = 1024;

// Words of a name that say what the device is, not whose: left readable
var _COMMON = /^(?:bluetooth|audio|device|wireless|headset|headphones?|speaker|keyboard|mouse|controller|stereo|phone)$/i;
// Not the name of an account or of a machine anybody could be told by. The
// words of the marks are here too, so no name can eat one.
var _NOBODY = /^(?:localhost|localdomain|user|host|device|secret|root|linux|fedora|unknown|none|mac|ip|email|uid|cmd)$/i;
// How the spaces of a name may be written in a line
var _GAP = "(?:[ _.+,-]|%20|&#32;|\\\\(?:x20|040|u0020| ))";

// One spelling for a name and for the text it is looked for in: composed
// letters, no zero-width character, every control character, line separator
// and odd space as a plain space (so none can forge a line), plain ASCII for
// the full-width forms, the dashes, the apostrophes, the ratio sign (a colon
// to the eye) and the dotless i
function _plain(s) {
    return s.normalize("NFC").replace(/[\u200b-\u200d\u2060\ufeff]/g, "")
        .replace(/[\u0000-\u001f\u007f-\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]/g, " ")
        .replace(/[\uff01-\uff5e]/g, function (c) {
            return String.fromCharCode(c.charCodeAt(0) - 0xfee0);
        })
        .replace(/[\u2010-\u2015\u2212]/g, "-").replace(/[\u2018\u2019\u02bc]/g, "'").replace(/[\u2236\ua789]/g, ":")
        .replace(/\u0131/g, "i").replace(/\u0130/g, "I");
}

// One more spelling to look for under an alias. `bounded`: only where it
// stands alone (a word of a name, an account, a machine).
function _add(name, alias, cut, bounded) {
    var key = "=" + name.toLowerCase();
    if (_byName[key])
        return;
    _byName[key] = alias;
    _known.push({ "name": name, "alias": alias, "cut": cut, "ruled": false, "bounded": bounded });
    // The rules run before the names, so a name they change ("Bob@home" is
    // an account to them) is also looked for as they leave it
    var ruled = Rules.apply(name);
    if (ruled !== name && /[0-9A-Za-z]/.test(ruled.replace(new RegExp(Rules.MARKS, "g"), "")))
        _known.push({ "name": ruled, "alias": alias, "cut": cut, "ruled": true, "bounded": bounded });
}

// The other ways a line may write a name: without its accents, and one word
// of it at a time ("Zorg" for "Zorg Buds Pro")
function _variants(name, alias, cut) {
    var bare = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    _add(bare, alias, cut, false);
    var words = bare.split(/[^0-9A-Za-z\u00c0-\uffff]+/).concat(name.split(/[^0-9A-Za-z\u00c0-\uffff]+/));
    for (var w = 0; w < words.length && w < 16; w++) {
        if (words[w].length >= 4 && words[w] !== name && !_COMMON.test(words[w]) && !_NOBODY.test(words[w]))
            _add(words[w], alias, false, true);
    }
}

// Returns the alias the name is hidden under ("" when it is not a name).
// kind: "device", "user" or "host". A list of names shares one alias.
function register(kind, name) {
    if (Array.isArray(name)) {
        var first = "";
        for (var n = 0; n < name.length && n < 8; n++)
            first = register(kind, name[n]) || first;
        return first;
    }
    // A name may come as a number or a String object from the engine
    if ((typeof name === "number" && isFinite(name)) || name instanceof String)
        name = String(name);
    if (typeof name !== "string" || Rules.KINDS.indexOf(kind) < 0)
        return "";
    // Without the spaces around it, and one space for a run of them: a line
    // of the journal does not carry the name's own spacing
    name = _plain(name.slice(0, RAW_FACTOR * MAX_NAME)).replace(/ +/g, " ").trim();
    var personal = kind !== "device";
    if (!name || (personal && (name.length < 2 || _NOBODY.test(name))))
        return "";
    var cut = name.length > MAX_NAME;
    if (cut)
        name = name.slice(0, MAX_NAME);
    var key = "=" + name.toLowerCase();
    if (_byName[key])
        return _byName[key];
    _counts[kind] = (_counts[kind] || 0) + 1;
    var alias = kind + "#" + _counts[kind];
    _add(name, alias, cut, personal);
    if (!personal)
        _variants(name, alias, cut);
    _stale = true;
    return alias;
}

// The account and the machine the report is made on, read once by the caller
// (the environment, /etc/hostname). Hidden wherever they are written as they
// are: a path outside the home folder, the default name of the Bluetooth
// adapter (the machine's), a line of another program.
function identity(user, host) {
    register("user", user);
    var machine = typeof host === "string" ? host.trim().split(/\s/)[0] : "";
    register("host", machine);
    register("host", machine.split(".")[0]);
}

function forget() {
    _known = [];
    _byName = {};
    _counts = {};
}

function _escape(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// The pattern of a name: any case, its spaces as a line may write them
// (several, "_", ".", "%20", "\x20", none at all for a long name), its quotes
// escaped or not. A single character, a word of a name, an account and a
// machine are hidden only where they stand alone, or they would hide a piece
// of every other word.
// The only group of the pattern is what stands before the name (empty for a
// longer name): it is set where a name was found, and not where a mark or an
// alias was, which is left as it is.
function _pattern(known, kept) {
    var gap = _GAP + (known.name.length >= 6 ? "*" : "+");
    var body = _escape(known.name).replace(/ /g, gap).replace(/['"]/g, "\\\\?$&") + (known.cut ? ".*" : "");
    if (known.name.length < 2)
        body = "(^|[^0-9A-Za-z#.])" + body + "(?![0-9A-Za-z]|\\.[0-9A-Za-z])";
    else if (known.bounded)
        body = "(^|[^0-9A-Za-z#])" + body + "(?![0-9A-Za-z])";
    else
        body = "()" + body;
    // What the rules wrote goes first, except for a name that holds some
    return new RegExp(known.ruled ? body + "|" + kept : kept + "|" + body, "gi");
}

function _prepare() {
    _known.sort(function (a, b) {
        return b.name.length - a.name.length;
    });
    for (var i = 0; i < _known.length; i++)
        _known[i].pattern = _pattern(_known[i], Rules.KEPT);
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

// The rules first: a device may be named like a word they look for ("home",
// "token"), and replacing it before them would let the secret after it out
function _clean(s) {
    return _names(Rules.apply(s));
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
// a secret in half and let its first half read as plain text. So the word the
// cut falls in is left out, the text is also cleaned with MAX_NAME more
// characters in sight, and what the two results do not share (a name of
// several words, seen whole the second time) is left out too.
function text(value) {
    if (value === null || value === undefined)
        return "";
    var all = _plain(String(value).slice(0, RAW_FACTOR * MAX_INPUT));
    var head = all.slice(0, MAX_INPUT);
    if (all.length > MAX_INPUT && all[MAX_INPUT] !== " ")
        head = head.replace(/[^ ]+$/, "");
    var s = _clean(head);
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
