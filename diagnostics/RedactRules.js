.pragma library

// The rules of Redact.js: what is hidden in a text whatever the plugin knows
// of the machine. Hidden by default: after a key that may hold something
// personal (key, pin, code, user, owner, hostname, name...) the whole value
// goes, whatever its shape, unless it is on a short list of known safe ones.
//
// No lookbehind in these patterns on purpose: the QML engine of Quickshell
// rejects "(?<" ("Invalid regular expression") although gjs accepts it, so
// the character before a match is captured and given back instead.

// What the rules and the names write. Never hidden again, never cut in two.
var MARKS = "<(?:secret|mac|ip|email|host|user|uid|cmd)>";
var KINDS = ["device", "host", "user"];
var KEPT = "(?:" + MARKS + "|(?:" + KINDS.join("|") + ")#[0-9]+)";

var _HEX2 = "[0-9A-Fa-f]{2}";
var _PREFIX = "(?:[A-Za-z0-9]{1,32}[-_]){0,4}";
var _SIGN = "([\"']?\\s*[=:]\\s*)";
// Where a value ends: the end of the text, or the next "key=" or "key:"
var _AHEAD = "(?:[,;]\\s*|\\s+)[(\\[{\"\']?[\\w.-]+[\"\']?\\s*[=:]";
var _NEXT = "(?=\\s*$|" + _AHEAD + ")";
var _WHOLE = "(?=\\s*$|" + _AHEAD + "|\\s*[)\\]}])";
// A value: up to the next key (quoted or not), or else the rest of the line.
// Nothing is left after it, so no half of a secret is, and a second cleaning
// finds the mark alone.
var _REST = "(?:(?:\"[^\"]*\"|'[^']*'|[^\\n]{1,200}?)" + _NEXT + "|[^\\n]*)";
// A value that says how things went
var _STATE = "(?:failed|failure|ok|success|succeeded|denied|refused|error|timeout|true|false|yes|no|none|null|on|off|unknown)";
// A count or an exit code, also as Allow.js clamps it (ten digits): a
// pairing code has four to eight
var _SMALL = "-?(?:[0-9]{1,3}|10{9})";
// The dotted name of a PipeWire or BlueZ property, a keyboard key said to be
// pressed or released (the name alone could be a password), one of the
// plugin's own codes
var _PROPERTY = "(?:api|node|device|media|audio|bluez5?|factory|object|port|card|priority|application|client|module|stream)(?:\\.[a-z][a-z0-9_-]*){2,}";
var _KEYS = "Enter|Return|Escape|Esc|Space|Tab|Backspace|Delete|Up|Down|Left|Right|Home|End|Shift|Control|Ctrl|Alt|Super|Meta";
var _KEYNAME = "(?:" + _KEYS + "|F[0-9]{1,2}|[A-Za-z0-9]|" + KEPT + ") (?:pressed|released|" + KEPT + ")";
var _CODE = "[A-Z]{2,5}-[A-Z]?[0-9]{1,4}";
var _SAFE_SECRET = "(?:" + KEPT + "|" + _STATE + "|" + _SMALL + "|\\?|" + _PROPERTY + "|" + _KEYNAME + "|" + _CODE + ")";
var _SAFE_NAME = "(?:" + KEPT + "|" + _STATE + "|[0-9]{1,9}|\\?|" + _CODE + ")";

// Keys whose value is a secret whatever it looks like
var _NAMED = "token|secret|passw(?:or)?d|pwd|passphrase|passkey|passcode|pincode|psk|credentials?|session[-_]?id|signature|mot de passe";
// Everyday words too ("key: Enter pressed", "pin: yes"): the safe list applies
var _BARE = "key|pin|code|pass|pw|auth|otp|sig|seed|nonce|access";
var _STRICT = "key|pin|pass|pw|otp|seed|nonce";
var _ACCOUNT = "user(?:name)?|login|logname|owner|account|whoami|uid|gid";
var _MACHINE = "host(?:name)?|machine|alias|name|nick(?:name)?";
// What may follow "password", "token"... or "user" in a sentence
var _WORDS = "is|was|for|to|of|the|a|an|not|no|and|or|from|in|on|at|by|required|requested|request|expired|missing|invalid|accepted|rejected"
    + "|entry|prompt|agent|changed|set|needed|mismatch|failed|ok|interface|input|action|space|session|user|id|name|unit|service|manager|settings";
var _AFTER = "(?:" + KEPT + "|" + _WORDS + ")(?![^\\s,;.)])";

// "key<sign>value" hidden unless the whole value is a safe one
function _pair(keys, safe, mark, prefix) {
    return [new RegExp("\\b(" + prefix + "(?:" + keys + "))" + _SIGN + "(?!\\s)" + (safe ? "(?!" + safe + _WHOLE + ")" : "(?!" + KEPT + _WHOLE + ")") + _REST, "gi"), "$1$2" + mark];
}

var _SEP = "(?:[\\/\\\\]|%2[Ff]|%5[Cc])";
var _SEPS = _SEP + "+(?:\\." + _SEP + "+)*";
var _PART = "[^\\/\\\\\\s:'\"%<]+";
// The home folder, however its path is written: doubled or backward slashes,
// "./", encoded in a link, any case, /var/home, C:\Users, a space in the name
// (up to the next slash). The account name is the second group.
var _ROOT = "(^|[^A-Za-z0-9_.-])(?:[A-Za-z]:)?(?:" + _SEPS + "(?:var|usr|data|export|net))?(?:" + _SEP + "(?:\\." + _SEP + "+)*)?";
var _WHOSE = "(" + _PART + "(?: " + _PART + "){1,3}(?=" + _SEP + ")|" + _PART + ")";
var HOME = new RegExp(_ROOT + "(?:home|users)" + _SEPS + "(?:\\.ecryptfs" + _SEPS + ")?" + _WHOSE, "gi");

// A "media" folder is a drive mounted for the account unless it is under a
// system folder (/usr/share/media) or already in the home folder
function _media(all, before) {
    return /^(?:~|\/usr|\/opt|\/etc|\/lib|\/var\/lib)(?:\/|$)/.test(before) ? all : before + "/media/<user>";
}

// Under /mnt the first folder may say what is mounted ("/mnt/usb"); any other
// one, and whatever is under it, may be named after the account
var _MOUNT = new RegExp("^(?:data|usb|share|nas|disk|" + KEPT + ")$", "i");
function _mnt(all, first, under) {
    if (!_MOUNT.test(first))
        return "/mnt/<user>";
    return "/mnt/" + first + (under.length > 1 ? "/<user>" : under);
}

var _MAC_SEP = "(?:\\s{0,2}(?:\\\\?[:_.,\\/-]|%3[Aa])\\s{0,2}|\\s{1,2})";
var _SECRETS = [
    // Secrets first, so nothing below can cut one in half
    [/\b((?:set-)?cookie["']?\s*[=:]\s*)[^\n]+/gi, "$1<secret>"],
    [/\b(authorization["']?\s*[=:]\s*)[^\n]+/gi, "$1<secret>"],
    _pair(_NAMED + "|(?:auth|api)[-_]?key", "", "<secret>", _PREFIX),
    // A plural key with a small number is a count ("pins: 3"), not a secret
    _pair("(?:" + _NAMED + "|" + _BARE + ")s", "[0-9]{1,3}", "<secret>", _PREFIX),
    // With a prefix (wifi_key) these are keys like the named ones
    _pair(_STRICT, "", "<secret>", "(?:[A-Za-z0-9]{1,32}[-_]){1,4}"),
    _pair(_BARE, _SAFE_SECRET, "<secret>", _PREFIX + "_?"),
    // A pairing code near its name: "PIN is 4821", "Request confirmation 482193"
    [/\b((?:pin|passkey|passcode|pairing|confirm[a-z]*|code)[^0-9\n<]{0,24})[0-9]{4,8}\b/gi, "$1<secret>"],
    // The same keys without a sign: "password hunter2", "link key AB12", "--token x"
    [new RegExp("\\b((?:" + _NAMED + "|link[ -]key)(?:\\s+(?:is|was))?\\s+)(?!" + _AFTER + ")[^\\s<]\\S*", "gi"), "$1<secret>"],
    [/\bBearer\s+\S+/gi, "Bearer <secret>"],
    // Base64 after "Basic": long, padded, or short with a digit in it
    [/\bBasic\s+(?:[A-Za-z0-9+\/]{16,}={0,2}|[A-Za-z0-9+\/]{2,}={1,2}|(?=[A-Za-z+\/]*[0-9+\/])[A-Za-z0-9+\/]{4,})/g, "Basic <secret>"],
    [/\b(?:tskey|ghp|gho|ghu|ghs|ghr|github_pat|glpat|xox[abprs]|sk|pk|AKIA)[-_][A-Za-z0-9_-]{8,}/g, "<secret>"],
    [/\b[0-9A-Fa-f]{32,}\b/g, "<secret>"],
    [/\b[A-Za-z0-9+_-]{40,}={0,2}/g, "<secret>"],
    // Links with credentials, then e-mail addresses
    [/\b([a-z][a-z0-9+.-]*:\/\/)[^\s\/@]+@/gi, "$1<secret>@"],
    [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "<email>"]
];

var _ADDRESSES = [
    // A Bluetooth address: six pairs with any separator between them (colon,
    // dash, BlueZ underscore, dot, comma, slash, spaces, "%3A", "\:"), also
    // when a letter follows; three dotted groups; two halves; twelve digits
    [new RegExp("(?:" + _HEX2 + "[:-]){5}" + _HEX2, "g"), "<mac>"],
    [new RegExp("(^|[^0-9A-Za-z])" + _HEX2 + "(?:" + _MAC_SEP + _HEX2 + "){5}", "g"), "$1<mac>"],
    [/(^|[^0-9A-Za-z.])(?:[0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}(?![0-9A-Za-z.])/g, "$1<mac>"],
    [/(^|[^0-9A-Za-z])[0-9A-Fa-f]{6}[:-][0-9A-Fa-f]{6}(?![0-9A-Za-z])/g, "$1<mac>"],
    [/(^|[^0-9A-Fa-f])[0-9A-Fa-f]{12}(?![0-9A-Fa-f])/g, "$1<mac>"],
    // IPv4 first (dots or dashes), so "::ffff:192.168.1.2" keeps none of it
    [/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, "<ip>"],
    [/(^|[^0-9A-Za-z])(?:\d{1,3}-){3}\d{1,3}(?![0-9A-Za-z])/g, "$1<ip>"],
    [/(^|[^0-9A-Za-z:])(?:[0-9a-f]{1,4}:){7}[0-9a-f]{1,4}(?![0-9A-Za-z:])/gi, "$1<ip>"],
    [/(^|[^0-9A-Za-z:])(?:[0-9a-f]{1,4}:){1,7}:(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})?(?:%[0-9A-Za-z]+)?(?![0-9A-Za-z:])/gi, "$1<ip>"],
    [/(^|[^0-9A-Za-z:])::(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})(?![0-9A-Za-z:])/gi, "$1<ip>"],
    // What is left of an address: four or five of its six parts, a part
    // written with one digit, or the maker's three (a time has no letter)
    [/(^|[^0-9A-Za-z:])(?:[0-9A-Fa-f]{1,2}:){3,5}[0-9A-Fa-f]{1,2}(?![0-9A-Za-z:])/g, "$1<mac>"],
    [new RegExp("\\b(?:" + _HEX2 + "-){3,4}" + _HEX2 + "\\b", "g"), "<mac>"],
    [new RegExp("(^|[^0-9A-Za-z:-])(?=[0-9:-]{0,7}[A-Fa-f])" + _HEX2 + "([:-])" + _HEX2 + "\\2" + _HEX2 + "(?![0-9A-Za-z:-])", "g"), "$1<mac>"],
    [/\b[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:local|lan|home|internal|localdomain|home\.arpa|ts\.net|fritz\.box|box|corp|mshome\.net|intranet|private)\b\.?/gi, "<host>"],
    [/(\\\\|\b(?:smb|ssh|sftp|nfs|afp|rdp|vnc):\/\/)[A-Za-z0-9][A-Za-z0-9.-]*/gi, "$1<host>"]
];

var _ACCOUNTS = [
    // The account name lives in the home folder, the runtime folder, a drive
    // mounted for it, its mail, its timers, the accounts service
    [HOME, "$1~"],
    [/\/root\b/g, "~"],
    [/\/run\/user\/\d+/g, "/run/user/<uid>"],
    [/([^\s'":]*)\/media\/[^\/\s:'"]+/g, _media],
    [/\/mnt\/([^\/\s:'"]+)((?:\/[^\s:'"]*)?)/g, _mnt],
    [/(\/AccountsService\/(?:users|icons)|\/var\/mail|\/var\/spool\/(?:cron|mail)|\/etc\/sudoers\.d|\/srv)\/[^\/\s:'"]+/g, "$1/<user>"],
    // "uid=1000(name)", "~name", "name@machine", then the keys and the phrases
    [/\b((?:uid|gid|user)[= ]\d+ ?)\([^)\s]+\)/gi, "$1(<user>)"],
    [/(=\d+)\([^)\s]+\)/g, "$1(<user>)"],
    [/(^|[^0-9A-Za-z\/.~])~[A-Za-z_][A-Za-z0-9_.-]*/g, "$1~"],
    [/\b[A-Za-z_][A-Za-z0-9_.-]*@[A-Za-z0-9][A-Za-z0-9.-]*/g, "<user>@<host>"],
    _pair(_ACCOUNT, _SAFE_NAME, "<user>", "[A-Za-z0-9_-]{0,32}"),
    _pair(_MACHINE, _SAFE_NAME, "<host>", "[A-Za-z0-9_-]{0,32}"),
    [new RegExp("\\b(user|session (?:of|for)(?: user)?)(\\s+[\"']?)(?!" + _AFTER + ")[^\\s<\"']+", "gi"), "$1$2<user>"]
];

var _ALL = _SECRETS.concat(_ADDRESSES, _ACCOUNTS);

// The account names a text gives away in a home folder path: hidden wherever
// else the same text writes them (a file named after the account in its
// own Music folder)
function _learned(s) {
    var names = [];
    var m;
    HOME.lastIndex = 0;
    while ((m = HOME.exec(s)) !== null && names.length < 4) {
        if (m[2].length >= 3 && names.indexOf(m[2]) < 0 && !/^(?:user|users|home|share|root|lib)$/i.test(m[2]))
            names.push(m[2]);
    }
    HOME.lastIndex = 0;
    s = s.replace(HOME, "$1~");
    for (var n = 0; n < names.length; n++) {
        var name = names[n].replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        s = s.replace(new RegExp("(^|[^0-9A-Za-z])" + name + "(?![0-9A-Za-z])", "g"), "$1<user>");
    }
    return s;
}

function apply(s) {
    s = _learned(s);
    for (var j = 0; j < _ALL.length; j++)
        s = s.replace(_ALL[j][0], _ALL[j][1]);
    return s;
}
