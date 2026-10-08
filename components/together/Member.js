.pragma library
.import "../common/Address.js" as Address

// Who can take part in Listen together (D298): a Bluetooth device or a wired
// PipeWire output. A member is one validated token, the only form of a member
// that ever reaches a command (value 11):
//   - a Bluetooth address, "AA:BB:CC:DD:EE:FF";
//   - the node name of an ALSA output, "alsa_output.<...>" (a headset plugged
//     in by USB, an audio interface, the sound card).
// Pure logic, tested by tests/member.test.js.

var SINK_PREFIX = "alsa_output.";

// Longest token accepted: real ALSA names stay well under it, and a longer one
// is not worth a node name
var MAX_LENGTH = 160;

// What a node name may hold, so that it can sit in a property string
// ("key=value key=value") without a space, a quote, a brace or a comma
var WIRED = /^alsa_output\.[A-Za-z0-9_.+\-]+$/;

// How much of the device's name stays readable in a node name (pw-top)
var SLUG_LENGTH = 16;

// Two seeds for the two halves of a key: the standard FNV offset basis and a
// second, unrelated constant
var SEEDS = [2166136261, 305419896];

// The member behind `text`: its token (a Bluetooth address with colons, an
// ALSA node name as it is), or "" for anything else
function clean(text) {
    if (typeof text !== "string")
        return "";
    if (text.indexOf(SINK_PREFIX) !== 0)
        return Address.colon(text.length <= 17 ? text : "");
    // ".." never belongs to a real name and is what a path trick is made of
    return text.length <= MAX_LENGTH && WIRED.test(text) && text.indexOf("..") < 0 ? text : "";
}

// "bluetooth", "wired", or "" when `id` is not a member
function kind(id) {
    const token = clean(id);
    if (!token)
        return "";
    return token.indexOf(SINK_PREFIX) === 0 ? "wired" : "bluetooth";
}

function isWired(id) {
    return kind(id) === "wired";
}

// 32-bit FNV-1a of a text from `seed`, as 8 hex digits. Not a secret, only a
// name that is the same every time and differs for every output.
function hash(text, seed) {
    let h = seed >>> 0;
    for (let i = 0; i < text.length; i++) {
        h = Math.imul(h ^ text.charCodeAt(i), 16777619) >>> 0;
    }
    return ("00000000" + h.toString(16)).slice(-8);
}

// The part of a PipeWire node name that tells members apart, "" when `id` is
// not a member. A Bluetooth address gives "AA_BB_CC_DD_EE_FF"; an ALSA output
// gives "w_<short readable part>_<64 bits of its whole name>", lower case
// letters, digits and underscores only: the readable part helps whoever looks
// at the graph, the hash keeps two names that start alike apart.
function key(id) {
    const token = clean(id);
    if (!token)
        return "";
    if (!isWired(token))
        return Address.key(token);
    const slug = token.slice(SINK_PREFIX.length).toLowerCase().replace(/[^a-z0-9]+/g, "_").slice(0, SLUG_LENGTH).replace(/^_+|_+$/g, "");
    return "w_" + (slug ? slug + "_" : "") + SEEDS.map(seed => hash(token, seed)).join("");
}
