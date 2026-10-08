.pragma library
.import "Codes.js" as Codes

// What the report is made of and how it is copied (level 2). Pure: it names
// the commands and reads their answers; running them is the QML's job, and
// only when a report is asked for. Every answer is cut down to the few words
// worth keeping before it goes anywhere near the report, so a path or a name
// in a tool's output cannot get through.

// Argument lists, never a shell string (value 11). The journal is read for
// the DMS unit only; the report keeps what Orbit tagged in it.
var PROBES = [
    { "key": "dms", "command": ["dms", "version"] },
    { "key": "quickshell", "command": ["quickshell", "--version"] },
    { "key": "niri", "command": ["niri", "--version"] },
    // QML cannot tell its own Qt version; the package manager can (Fedora)
    { "key": "qt", "command": ["rpm", "-q", "--qf", "%{VERSION}", "qt6-qtbase"] },
    { "key": "distro", "command": ["cat", "--", "/etc/os-release"] },
    { "key": "journal", "command": ["journalctl", "--user", "-u", "dms", "-n", "300", "--no-pager"] }
];

// Tried in this order. The first marks the text as sensitive so DMS's
// clipboard history leaves it out (D371); the second is the fallback.
// The text goes in through standard input, never as an argument.
var COPY_TOOLS = [
    { "tool": "wl_copy", "command": ["wl-copy", "--sensitive"] },
    { "tool": "dms", "command": ["dms", "clipboard", "copy"] }
];

// The longest report the IPC call hands back (a person reads it)
var MAX_REPORT = 20000;

// "1.6.3" out of "dms v1.6.3", "26.04" out of "niri 26.04 (8ed0da4)"...
function _number(text) {
    var m = /\bv?(\d+(?:\.\d+){0,3}(?:[-+~][A-Za-z0-9.]+)?)/.exec(typeof text === "string" ? text : "");
    return m ? m[1] : "";
}

// PRETTY_NAME of /etc/os-release, or ""
function _distro(text) {
    var m = /^PRETTY_NAME="?([^"\n]{1,48})"?$/m.exec(typeof text === "string" ? text : "");
    return m ? m[1] : "";
}

// The value to put in the report for one probe's output: a version or a name
// ("" when the tool answered nothing usable), or the journal's lines.
function parse(key, text) {
    if (key === "journal")
        return typeof text === "string" ? text.split("\n").filter(function (l) { return l.length > 0; }) : [];
    return key === "distro" ? _distro(text) : _number(text);
}

// The plugin's own version from the text of its plugin.json, or ""
function pluginVersion(text) {
    try {
        var v = JSON.parse(text).version;
        return typeof v === "string" ? v : "";
    } catch (e) {
        return "";
    }
}

// { key: value } of the settings a report may show. `read` returns a
// setting's current value (undefined when the plugin has none by that name).
function settingsOf(read) {
    var out = {};
    for (var key in Codes.SETTINGS) {
        if (Object.prototype.hasOwnProperty.call(Codes.SETTINGS, key)) {
            var v = read(key);
            if (v !== undefined)
                out[key] = v;
        }
    }
    return out;
}

// A copy tool that could not be started (not installed) ends with -1, which
// is what ToolProcess reports; any other failure means it ran and refused.
function missing(code) {
    return code < 0;
}

// The report as the IPC call hands it back, capped
function capped(text) {
    return text.length > MAX_REPORT ? text.slice(0, MAX_REPORT - 1) + "…" : text;
}
