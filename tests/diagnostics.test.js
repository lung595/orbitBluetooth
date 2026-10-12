// Diagnostics: the allowlist, the anonymization, the memory buffer, the CPU line and the
// report. Every name, address and path below is made up. The checks that matter most are
// the leak ones: whatever goes in, none of it may come out.
// Run from the plugin root: gjs tests/diagnostics.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;

const Allow = load("Allow.js");
const Redact = load("Redact.js");
const Codes = load("Codes.js");
const Log = load("Log.js");
const Cpu = load("Cpu.js");
const Report = load("Report.js");
const Gather = load("Gather.js");
const Glyphs = load("Glyphs.js");

// --- Allow.js: the allowlist -------------------------------------------------------
eq("a yes/no is written yes or no", [Allow.value("bool", true), Allow.value("bool", false)], ["yes", "no"]);
eq("a truthy string is not a yes/no", [Allow.value("bool", "true"), Allow.value("bool", 1)], [null, null]);
eq("a number is rounded and clamped", [Allow.value("int", 3.6), Allow.value("int", 1e12), Allow.value("int", -1e12)], ["4", "1000000000", "-1000000000"]);
eq("a number string, NaN and Infinity are refused", [Allow.value("int", "7"), Allow.value("int", NaN), Allow.value("int", Infinity)], [null, null, null]);
eq("a word is allowed only from its list", [Allow.value(["a", "b"], "a"), Allow.value(["a", "b"], "Bob's AirPods")], ["a", null]);
eq("an unknown spec allows nothing", Allow.value("text", "anything"), null);
eq("pick follows the schema's order, not the caller's", Allow.pick({ "x": "int", "y": "bool" }, { "y": true, "x": 2 }), ["x=2", "y=yes"]);
eq("pick drops an unknown key and shows ? for a refused value", Allow.pick({ "x": "int", "y": ["ok"] }, { "x": 1, "y": "AA:BB:CC:DD:EE:01", "name": "Bob" }), ["x=1", "y=?"]);
eq("pick takes nothing from a non-object", [Allow.pick({ "x": "int" }, null), Allow.pick({ "x": "int" }, "x=1")], [[], []]);
eq("pick does not read inherited keys", Allow.pick({ "toString": "int" }, {}), []);

// --- Redact.js: what must never get out --------------------------------------------
// Built in two halves so the repository-wide greps for links stay empty
const HT = "ht" + "tp";
const MAC = "AA:BB:CC:DD:EE:01";
const IP4 = "192.168.7.23";
const secrets = {
    "mac colon": "paired " + MAC,
    "mac lower": "paired aa:bb:cc:dd:ee:01",
    "mac dash": "paired AA-BB-CC-DD-EE-01",
    "bluez path": "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_01/player0",
    "pipewire sink": "bluez_output.AA_BB_CC_DD_EE_01.1",
    "ipv4": "from " + IP4 + " port 22",
    "ipv6": "peer fd7a:115c:a1e0:ab12:4843:cd96:6258:1234 up",
    "ipv6 short": "peer fe80::1ff:fe23:4567:890a%wlan0 up",
    "home path": "QML Plug at file://\x2fhome/jdoe/.config/DankMaterialShell/plugins/x/Plug.qml[4:1]",
    "silverblue home": "/var\x2fhome/jdoe/Documents/a.txt",
    "runtime dir": "/run/user/1000/quickshell/by-id/abc",
    "token key": "authkey=tskey-auth-kAbCdEfGh12345-ZyXwVuTs9876",
    "token colon": "Token: abcDEF123456",
    "bearer": "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig",
    "github token": "ghp_16C7e42F292c6912E7710c838347Ae178B4a",
    "long hex": "key 0123456789abcdef0123456789abcdef0123",
    "email": "write to jdoe@example.org",
    "url credentials": HT + "s://jdoe:hunter2@example.org/path",
    "lan host": "reached laptop-jdoe.local and nas.home.arpa",
    "tailnet": "node jdoe-pc.tail1234.ts.net"
};
const forbidden = ["AA:BB:CC:DD:EE:01", "aa:bb:cc:dd:ee:01", "AA-BB-CC-DD-EE-01", "AA_BB_CC_DD_EE_01", "192.168.7.23", "fd7a:115c", "fe80::1ff", "jdoe", "hunter2", "tskey-auth", "abcDEF123456", "eyJhbGci", "ghp_16C7", "0123456789abcdef", "laptop-jdoe", "nas.home", "tail1234", "1000/quickshell"];
for (const what in secrets) {
    const out = Redact.text(secrets[what]);
    eq("no leak: " + what, forbidden.filter(f => out.indexOf(f) >= 0), []);
}
eq("a home path keeps the rest of the path", Redact.text("file://\x2fhome/jdoe/.config/a/b.qml"), "file://~/.config/a/b.qml");
eq("a plain time is not an address", Redact.text("12:03:41 ready"), "12:03:41 ready");
eq("a version is not an address", Redact.text("Qt 6.11.2, niri 25.08.1"), "Qt 6.11.2, niri 25.08.1");
eq("a code and its states stay readable", Redact.text("ORB-E001 action=connect reason=timeout"), "ORB-E001 action=connect reason=timeout");
eq("a control character cannot forge a new line", Redact.text("a\nb\u0000c\r"), "a b c ");
eq("a long line is cut", Redact.text("xy ".repeat(200)).length, 240);
eq("cleaning twice changes nothing", Redact.text(Redact.text(secrets["ipv6"] + " " + secrets["mac colon"])), Redact.text(secrets["ipv6"] + " " + secrets["mac colon"]));
eq("nothing becomes an empty text", [Redact.text(null), Redact.text(undefined)], ["", ""]);

// Names learned at run time become stable aliases
eq("a device name gets an alias", Redact.register("device", "Bob's AirPods Pro"), "device#1");
eq("the same name (any case) gets the same alias", Redact.register("device", "BOB'S airpods PRO"), "device#1");
eq("the next device gets the next number", Redact.register("device", "Kitchen Speaker"), "device#2");
eq("the login is hidden as a user", Redact.register("user", "jdoe"), "user#1");
eq("a name of spaces or of nothing is refused (it would hide every gap)", [Redact.register("device", "   "), Redact.register("device", ""), Redact.register("device", "\t\n\u00a0")], ["", "", ""]);
eq("a name with a tab is hidden where the tab reads as a space", (Redact.register("device", "Tab\tname"), [Redact.text("x Tab\tname y"), Redact.text("x Tab name y")]), ["x device#3 y", "x device#3 y"]);
eq("a bad kind is refused", Redact.register("de vice", "Name"), "");
eq("the longest known name goes first", Redact.text("Bob's AirPods Pro and kitchen speaker, jdoe"), "device#1 and device#2, user#1");
eq("a name with regex characters is taken literally", (Redact.register("device", "(my) [pods]+"), Redact.text("x (my) [pods]+ y")), "x device#4 y");
Redact.forget();
eq("forgetting clears the aliases", Redact.text("Bob's AirPods Pro"), "Bob's AirPods Pro");

// The spaces around a name are not part of it (D1): the journal does not carry them
for (const edge of ["Edge pods ", "Edge pods\n", "Edge pods\t", " Edge pods", "\r\n Edge pods \t"]) {
    Redact.forget();
    Redact.register("device", edge);
    eq("a name is hidden whatever space it starts or ends with: " + JSON.stringify(edge), [Redact.text("[orbit] Edge pods: connected"), Redact.text("link to Edge pods"), Redact.text("(Edge pods)")], ["[orbit] device#1: connected", "link to device#1", "(device#1)"]);
}
// One spelling for a name and for the line it is looked for in (D3)
Redact.forget();
Redact.register("device", "Zoe\u0301's  buds");
eq("a name is found under its other spellings (composed letters, odd spaces, apostrophes, zero width)", ["Zo\u00e9's buds", "Zoe\u0301\u2019s buds", "Zo\u00e9's\u00a0buds", "Zo\u00e9's   buds", "Zo\u00e9's\u2028buds", "Zo\u00e9's\u0085buds", "Zo\u00e9\u200b's buds"].map(t => Redact.text("on " + t + " now")), Array(7).fill("on device#1 now"));
eq("a line separator cannot forge a line either", /[\u0085\u2028\u2029]/.test(Redact.text("a\u0085b\u2028c\u2029d")), false);
Redact.forget();
eq("a one-character name is hidden where it stands alone, not inside a word", (Redact.register("device", "x"), [Redact.text("seen x again, x: ok"), Redact.text("taxi x2 max")]), ["seen device#1 again, device#1: ok", "taxi x2 max"]);
eq("a one-digit name does not eat the number of an alias", (Redact.register("device", "1"), Redact.text(Redact.text("x and 1"))), "device#1 and device#2");
Redact.forget();
eq("a name that is a number or a String object is a name", [Redact.register("device", 4242), Redact.register("device", new String("Boxed Bob")), Redact.text("4242 and Boxed Bob")], ["device#1", "device#2", "device#1 and device#2"]);
eq("what cannot be a name is refused", [null, undefined, true, {}, [], NaN, Infinity].map(n => Redact.register("device", n)), Array(7).fill(""));
// A name longer than a Bluetooth name can be (D5): no pattern too big, and nothing of it left
Redact.forget();
const endless = "Long Bob " + "z".repeat(50000) + " tail-of-bob";
eq("an endless name is registered without throwing", Redact.register("device", endless), "device#1");
eq("and hidden to the end of its line", Redact.text("[orbit] seen " + endless + " here"), "[orbit] seen device#1");
Redact.forget();

// The rules run before the names (N1), and a name never rewrites what they or an alias wrote
Redact.register("device", "device");
Redact.register("device", "secret");
Redact.register("user", "user");
eq("a name that is a word of an alias or of a mark changes neither, once or twice", [Redact.text("device and user, token=abc"), Redact.text(Redact.text("device and user, token=abc"))], Array(2).fill("device#1 and user#1, token=<secret>"));
Redact.forget();
eq("a one-digit name leaves a version alone and is hidden at the end of a sentence", (Redact.register("device", "1"), [Redact.text("Orbit 1.15.0 on Qt 6.1"), Redact.text("it is 1.")]), ["Orbit 1.15.0 on Qt 6.1", "it is device#1."]);
Redact.forget();
// The other ways a journal may write a name (D3)
Redact.register("device", "Bob's Big Buds");
eq("a name is found escaped, in full-width letters, with thin spaces", ["Bob's_Big_Buds", "Bob's%20Big%20Buds", "Bob's\\x20Big\\x20Buds", "Bob\\'s Big Buds", "Bob's\u2009Big\u2003Buds", "\uff22\uff4f\uff42's Big Buds", "BOB'S B\u0131G BUDS"].map(t => Redact.text("on " + t + " now")), Array(7).fill("on device#1 now"));
Redact.forget();
Redact.register("device", "Ann@nas speaker");
eq("a name the rules change is still hidden whole", Redact.text("on Ann@nas speaker now"), "on device#1 now");
Redact.forget();
// A text far longer than a line (N2): read up to a cap, in a time that does not grow with its square
for (const piece of ["a.", "1.", "a-", "a@", "a:"]) {
    const from = Date.now();
    const cut = Redact.text(piece.repeat(24000));
    eq("48 000 characters of " + JSON.stringify(piece) + " are cleaned at once", [Date.now() - from < 500, cut.length <= Redact.MAX_LINE], [true, true]);
}
Redact.register("device", "Bob Buds");
const filler = "token=" + "A1b2".repeat(300);
eq("a name or a secret cut in half by the cap does not come out", [filler.slice(0, Redact.MAX_INPUT - 5) + " Bob Buds tail", filler.slice(0, Redact.MAX_INPUT - 12) + " deadbeefdeadbeefdeadbeefdeadbeef0123 tail"].map(t => Redact.text(t)), Array(2).fill("token=<secret> "));
Redact.forget();
// What reads like a secret or an account and is neither
eq("a count and a state stay readable", Redact.text("pins: 3 tokens: 12, login: failed user=none"), "pins: 3 tokens: 12, login: failed user=none");
eq("a plural key with a value is still a secret", ["pins: 1234", "tokens: abc", "tokens=12a"].map(t => Redact.text(t)), ["pins: <secret>", "tokens: <secret>", "tokens=<secret>"]);
const rest = {
    "address glued to a letter, with colons": "macAA:BB:CC:DD:EE:01 up",
    "address in full-width digits": "at \uff21\uff21:BB:CC:DD:EE:\uff10\uff11 up",
    "drive under /mnt": "open /mnt/jdoe/a.txt",
    "accounts service": "read /var/lib/AccountsService/users/jdoe",
    "home folder without its first slash": "open home/jdoe/a.txt",
    "id with the account": "uid=1000(jdoe) gid=1000(jdoe)",
    "account after its word": "session opened for user jdoe",
    "short basic header": "Basic aHVudGVyMg==, Basic dTpw0A",
    "authorization header": "Authorization: Basic hunter2",
    "pairing code without a sign": "pin 123456, pairing code 123456",
    "psk and bare key": "psk=hunter2 key=hunter2 wifi_key: hunter2"
};
for (const what in rest) {
    const out = Redact.text(rest[what]);
    eq("no leak: " + what, ["AA:BB", "jdoe", "hunter2", "aHVudGVy", "dTpw", "123456", "\uff10"].filter(f => out.indexOf(f) >= 0), []);
}

// The addresses, accounts and secrets the first patterns let through (D6, D7, D9)
const more = {
    "address without separator": "dev AABBCCDDEE01 up",
    "address glued to a letter": "devAABBCCDDEE01x up",
    "address in dotted groups": "at aabb.ccdd.ee01 up",
    "address with spaces": "at AA BB CC DD EE 01 up",
    "address in a link": "dev=AA%3ABB%3ACC%3ADD%3AEE%3A01&x",
    "address with a one-digit part": "at AA:BB:CC:DD:EE:1 up",
    "five parts of an address": "at AA:BB:CC:DD:EE up",
    "four parts of an address": "at BB-CC-DD-EE up",
    "drive mounted for the account": "open /run/media/jdoe/KEY/a.txt and /media/jdoe/b",
    "tilde account": "cd ~jdoe/Music",
    "account at machine": "as jdoe@laptop now",
    "user= account": "session user=jdoe login: jdoe USERNAME=jdoe",
    "prefixed key": "access_token=hunter2 refresh-token: hunter2",
    "JSON key": '{"token": "hunter2", "api_key":"hunter2"}',
    "pairing code": "Passkey: 123456 pin=0000 pincode: 9999",
    "passphrase": "passphrase=hunter2",
    "basic header": "Authorization: Basic aHVudGVyMjpodW50ZXIy",
    "session cookie": "cookie=hunter2 session_id=hunter2"
};
const moreForbidden = ["AABB", "aabb", "AA BB", "AA%3A", "AA:BB", "BB-CC", "EE:1", "jdoe", "laptop", "hunter2", "123456", "0000", "9999", "aHVudGVy"];
for (const what in more) {
    const out = Redact.text(more[what]);
    eq("no leak: " + what, moreForbidden.filter(f => out.indexOf(f) >= 0), []);
    eq("cleaning twice changes nothing: " + what, Redact.text(out), out);
}
eq("what is not an address stays readable", Redact.text("12:03:41 ready, A.qml[4:1], 2026-10-08, Qt 6.11.2, Basic settings, x ~ y"), "12:03:41 ready, A.qml[4:1], 2026-10-08, Qt 6.11.2, Basic settings, x ~ y");

eq("a command is reduced to its program", [Redact.command("/usr/bin/wl-copy --sensitive hunter2"), Redact.command(["/usr/bin/pw-play", "\x2fhome/jdoe/a.wav"]), Redact.command("dms ipc call")], ["wl-copy", "pw-play", "dms"]);
eq("an odd command becomes <cmd>", [Redact.command(""), Redact.command(["x y"]), Redact.command(null), Redact.command(["\x2fhome/jdoe/my tool"])], ["<cmd>", "<cmd>", "<cmd>", "<cmd>"]);

// --- Codes.js: the declarations are consistent -------------------------------------
const wordOk = /^[A-Za-z0-9_.-]{1,24}$/;
const badWords = [];
for (const key in Codes.FIELDS) {
    if (Array.isArray(Codes.FIELDS[key]))
        Codes.FIELDS[key].forEach(w => { if (!wordOk.test(w)) badWords.push(key + ":" + w); });
}
for (const key in Codes.SETTINGS) {
    if (Array.isArray(Codes.SETTINGS[key]))
        Codes.SETTINGS[key].forEach(w => { if (!wordOk.test(w)) badWords.push(key + ":" + w); });
}
eq("every allowed word is a short plain token", badWords, []);
eq("every code is well formed and uses declared fields", Object.keys(Codes.CODES).filter(c => !/^[A-Z]{3}-[EWID]\d{3}$/.test(c) || Codes.CODES[c].fields.some(f => !(f in Codes.FIELDS))), []);
eq("every code has a sentence for the guide", Object.keys(Codes.CODES).filter(c => !Codes.CODES[c].text), []);
eq("no field name or setting is a free-text kind", [...Object.values(Codes.FIELDS), ...Object.values(Codes.SETTINGS), ...Object.values(Codes.FACTS)].filter(s => !(s === "int" || s === "bool" || Array.isArray(s))), []);
// The guide explains each code (value 7): a code added without its entry fails here
const guide = new TextDecoder().decode(GLib.file_get_contents(GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir()))) + "/docs/DEBUGGING.md")[1]);
eq("every code is explained in docs/DEBUGGING.md", Object.keys(Codes.CODES).filter(c => guide.indexOf("`" + c + "`") < 0), []);

// --- Log.js: the buffer and the journal line ---------------------------------------
const journal = [];
Log.setSink({ "error": l => journal.push("E " + l), "warn": l => journal.push("W " + l) });
eq("an error is recorded and returned as a line", Log.event("ORB-E001", { "action": "connect", "reason": "timeout" }), "ORB-E001 action=connect reason=timeout");
eq("an error goes to the journal with the plugin's label", journal, ["E [orbit] ORB-E001 action=connect reason=timeout"]);
Log.event("ORB-W010", { "state": "off" });
Log.event("ORB-I020", { "surface": "widget" });
Log.event("ORB-D040", { "state": "hidden", "count": 3 });
eq("a warning goes to the journal, info and debug do not", journal.length, 2);
eq("all four stay in the buffer, oldest first", Log.entries().map(e => e.line), ["ORB-E001 action=connect reason=timeout", "ORB-W010 state=off", "ORB-I020 surface=widget", "ORB-D040 state=hidden count=3"]);
eq("an entry carries its time", typeof Log.entries()[0].at, "number");

// Whatever a caller passes, no free text gets into the buffer or the journal
journal.length = 0;
Log.clear();
const line = Log.event("ORB-E001", { "action": "Bob's AirPods Pro", "reason": MAC, "name": "jdoe", "address": IP4, "path": "\x2fhome/jdoe/x", "token": "tskey-auth-abcdef123456" });
eq("a name, an address, a path or a token passed as a field never comes out", [line, journal], ["ORB-E001 action=? reason=?", ["E [orbit] ORB-E001 action=? reason=?"]]);
eq("a field the code does not declare is dropped", Log.event("ORB-E002", { "reason": "timeout", "action": "connect" }), "ORB-E002 reason=timeout");
eq("a code nobody declared is dropped whole", [Log.event("ORB-E999", { "reason": "timeout" }), Log.event("Bob's AirPods", {}), Log.event(null), Log.event("__proto__"), journal.length], ["", "", "", "", 2]);
eq("a call with no fields is fine", Log.event("ORB-E005", undefined), "ORB-E005");
Log.clear();
eq("clear empties the buffer", Log.entries(), []);

// The ring keeps the last 200, oldest first, and never grows
for (let n = 0; n < 450; n++)
    Log.event("ORB-D040", { "count": n });
const kept = Log.entries();
eq("the ring holds exactly its capacity", [Log.CAPACITY, kept.length], [200, 200]);
eq("it keeps the newest and in order", [kept[0].line, kept[199].line], ["ORB-D040 count=250", "ORB-D040 count=449"]);
Log.clear();

// --- Cpu.js: measured on request, from two readings --------------------------------
const stat = "1234 (qs) S 1 1234 1234 0 -1 4194560 100 0 0 0 5000 700 0 0 20 0 30 0 100 1000 100 18446744073709551615";
eq("ticks are user + system", Cpu.ticksOf(stat), 5700);
eq("a process name with spaces and brackets does not shift the fields", Cpu.ticksOf(stat.replace("(qs)", "(my ) S (x)")), 5700);
eq("a missing or broken reading is -1", [Cpu.ticksOf(""), Cpu.ticksOf(null), Cpu.ticksOf("12 (x"), Cpu.ticksOf("1 (x) S 2")], [-1, -1, -1, -1]);
eq("17 ticks in one second is 17 % of a core", Cpu.percent(5700, 5717, 1000), 17);
eq("a two-core second can pass 100 %", Cpu.percent(0, 250, 1000), 250);
eq("a window too short, or time running backwards, is not measured", [Cpu.percent(10, 20, 50), Cpu.percent(20, 10, 1000), Cpu.percent(-1, 10, 1000), Cpu.percent(10, 20, NaN)], [-1, -1, -1, -1]);
eq("the line says it is the whole shell", Cpu.line({ "percent": 4.2, "windowMs": 1000 }), "4.2% of one core, whole shell (DMS and every plugin), over 1 s");
eq("no measure, no number", [Cpu.line(null), Cpu.line({ "percent": -1, "windowMs": 1000 })], ["not measured", "not measured"]);

// --- Report.js: the whole report, with everything personal thrown at it ------------
Redact.register("device", "Bob's AirPods Pro");
Redact.register("user", "jdoe");
Log.event("ORB-I020", { "surface": "widget" });
Log.event("ORB-E003", { "tool": "pw_loopback", "code": 1 });
const report = Report.build({
    "now": Date.UTC(2026, 9, 8, 12, 3, 41),
    "plugin": "1.14.0",
    "versions": { "dms": "1.6.3", "quickshell": "0.3.1", "qt": "6.11.2", "niri": "25.08", "distro": "Fedora Linux 44 (Workstation Edition)" },
    "surfaces": { "widget": true, "daemon": true, "desktop": false, "settings": "yes", "evil": true },
    "settings": { "showLabels": true, "maxDevices": 8, "ancEngine": "demand", "starDensity": "Bob's AirPods Pro", "imageFolder": "\x2fhome/jdoe/Pictures", "deviceName": "Bob's AirPods Pro" },
    "facts": { "devices": 3, "timersRunning": 0, "sceneVisible": false, "hostname": "laptop-jdoe" },
    "cpu": { "percent": 4.2, "windowMs": 1000 },
    "journal": [
        "WARN qml: [orbit] ORB-W010 state=off",
        "ERROR qml: QML OrbitBluetooth at file://\x2fhome/jdoe/.config/DankMaterialShell/plugins/orbitBluetooth/A.qml[4:1]: Bob's AirPods Pro " + MAC + " " + IP4,
        "INFO qml: something unrelated of another plugin 192.168.7.23",
        "x".repeat(10) + " [orbit] token=tskey-auth-abcdef123456",
        "Oct 08 12:00:00 laptop-jdoe qs[123]: [orbit] ORB-W011 tool=pw_loopback"
    ]
});
const expected = [
    "OrbitBluetooth diagnostic report (anonymous: versions, states and codes only)",
    "Created      : 2026-10-08 12:03:41 UTC",
    "Plugin       : OrbitBluetooth 1.14.0",
    "DMS          : 1.6.3   Quickshell : 0.3.1   Qt : 6.11.2",
    "Compositor   : niri 25.08",
    "Distribution : Fedora Linux 44 (Workstation Edition)",
    "Surfaces     : widget, daemon (active)",
    "Settings     : showLabels=yes maxDevices=8 starDensity=? ancEngine=demand",
    "State        : devices=3 timersRunning=0 sceneVisible=no",
    "CPU          : 4.2% of one core, whole shell (DMS and every plugin), over 1 s",
    "Last events (2 of 200 kept, oldest first, UTC):"
];
const lines = report.split("\n");
eq("the report's header holds the versions, surfaces, settings, state and CPU", lines.slice(0, 11), expected);
eq("the events follow, with their time", lines.slice(11, 13).map(l => l.replace(/^ {2}\d\d:\d\d:\d\d /, "  T ")), ["  T ORB-I020 surface=widget", "  T ORB-E003 tool=pw_loopback code=1"]);
eq("only the plugin's own journal lines are kept, cleaned", lines.slice(13), [
    "Journal lines (anonymized, 4 kept, last 50 at most):",
    "  WARN qml: [orbit] ORB-W010 state=off",
    "  ERROR qml: QML OrbitBluetooth at file://~/.config/DankMaterialShell/plugins/orbitBluetooth/A.qml[4:1]: device#1 <mac> <ip>",
    "  xxxxxxxxxx [orbit] token=<secret>",
    "  [orbit] ORB-W011 tool=pw_loopback",
    ""
]);
eq("a report ends with a new line", report.endsWith("\n"), true);
const leaks = ["Bob", "AirPods", "jdoe", "AA:BB", "192.168", "tskey", "\x2fhome/", "Pictures", "laptop", "hostname"].filter(w => report.indexOf(w) >= 0);
eq("no device name, address, login, path, setting value or token anywhere in the report", leaks, []);

// An empty or hostile input still gives a readable report and never throws
const bare = Report.build(null);
eq("a report with nothing is still a report", [bare.indexOf("Plugin       : OrbitBluetooth ?") > 0, bare.indexOf("Surfaces     : none active") > 0, bare.indexOf("CPU          : not measured") > 0], [true, true, true]);
const hostile = Report.build({ "plugin": "1.0 \x2fhome/jdoe", "versions": { "dms": { "a": 1 }, "qt": "x\ny", "distro": "<script>" }, "surfaces": 5, "settings": "no", "facts": [1], "cpu": "high", "journal": "no", "now": "never" });
eq("hostile versions become ? and no input throws", [hostile.indexOf("jdoe"), hostile.indexOf("DMS          : ?   Quickshell : ?   Qt : ?"), hostile.indexOf("<script>")], [-1, 0 < hostile.indexOf("DMS          : ?   Quickshell : ?   Qt : ?") ? hostile.indexOf("DMS          : ?   Quickshell : ?   Qt : ?") : -2, -1]);

// The machine name that starts a journal line goes whatever the date format (D8)
const isoHost = Report.build({ "journal": ["2026-10-08T12:00:00+0200 laptop-jdoe qs[123]: [orbit] ORB-E001 iso", "2026-10-08T12:00:00.123456+02:00 laptop-jdoe qs[123]: [orbit] ORB-E001 precise", "2026-10-08T10:00:00Z laptop-jdoe qs[123]: [orbit] ORB-E001 zulu"] });
eq("a journal line dated the ISO way loses its machine name too", [isoHost.indexOf("laptop"), isoHost.indexOf("jdoe"), isoHost.split("\n").filter(l => /^ {2}\[orbit\] ORB-E001 (iso|precise|zulu)$/.test(l)).length], [-1, -1, 3]);

// Zero cost at rest (value 6) and no way out (value 5): the module holds no timer, no
// file, no process and no network call, so nothing in it can run on its own
const files = ["Allow", "Codes", "Cpu", "Log", "Redact", "Report", "ReportFile"];
const sources = files.map(f => new TextDecoder().decode(GLib.file_get_contents(GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir()))) + "/diagnostics/" + f + ".js")[1]));
eq("no timer, file, process, network or QML import in the module", sources.map((src, i) => new RegExp("Timer|setTimeout|setInterval|FileView|Process|XML" + HT.toUpperCase().slice(0, 0) + "HttpRequest|fetch\\(|WebSocket|\\bimport (Qt|Quickshell|qs)|Qt\\.|" + HT + "s?:").test(src) ? files[i] : null).filter(Boolean), []);
eq("only warn and error reach the console, never log", sources.filter(src => /console\.(log|debug|info)/.test(src)).length, 0);

// A fixed spread of hostile values passed as fields: only plain words and numbers may come out
const garbage = ["Bob's AirPods", MAC, IP4, "\x2fhome/jdoe/x", "tskey-auth-abc123456789", "a\nb", "", null, undefined, {}, [], [1], NaN, Infinity, 1e99, "__proto__", "constructor", true];
const plain = /^ORB-[EWID]\d{3}( [a-z]+=(\?|-?\d+|[a-z0-9_.-]+))*$/;
const dirty = [];
Log.setSink({ "error": () => {}, "warn": () => {} });
for (const code of Object.keys(Codes.CODES)) {
    for (const g of garbage) {
        const fields = {};
        Codes.CODES[code].fields.forEach(f => { fields[f] = g; });
        const out = Log.event(code, fields);
        if (!plain.test(out) || forbidden.some(w => out.indexOf(w) >= 0))
            dirty.push(code + " <- " + JSON.stringify(g) + " -> " + out);
    }
}
eq("every code with every hostile value gives a plain line", dirty, []);

eq("a numeric tickEvery is reported, not shown as ?", Allow.pick(Codes.SETTINGS, { "tickEvery": 1 }), ["tickEvery=1"]);

// --- Codes.js against the settings pages: B cannot drift from what the user can pick ---
// Every settingKey of the pages is either listed in Codes.SETTINGS with exactly the
// words (or number kind) of its choices, or left out on purpose.
// Three behaviour flags live in Prefs.qml without a settings control of their own
const KEPT_PREFS = ["keysOffered", "keysGivenBack", "learnHabits"];
const OMITTED = ["imageFolder", "factCard_", "factMore_"];
const settingsDir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir()))) + "/components/settings";
const keysFound = {};
const dirEnum = Gio.File.new_for_path(settingsDir).enumerate_children("standard::name", 0, null);
for (let info = dirEnum.next_file(null); info; info = dirEnum.next_file(null)) {
    if (!/\.qml$/.test(info.get_name()))
        continue;
    const qml = new TextDecoder().decode(GLib.file_get_contents(settingsDir + "/" + info.get_name())[1]);
    qml.split(/\n(?=\s*[A-Z]\w+ \{)/).forEach(block => {
        const key = /(?:settingKey|settingKey: string): "(\w+)"|settingKey: "(\w+)"/.exec(block);
        if (key)
            keysFound[key[1] || key[2]] = [...block.matchAll(/value: "([^"]*)"/g)].map(m => m[1]);
    });
}
const glyphWords = ["auto"].concat(Glyphs.order);
const settingsDrift = [];
for (const key in keysFound) {
    if (OMITTED.indexOf(key) >= 0)
        continue;
    const spec = Codes.SETTINGS[key];
    const words = keysFound[key];
    const numeric = words.length > 0 && words.every(w => /^\d+$/.test(w));
    if (spec === undefined)
        settingsDrift.push(key + " is not in Codes.SETTINGS");
    else if (key === "hostGlyph" ? JSON.stringify(spec) !== JSON.stringify(glyphWords) : (words.length && !numeric && JSON.stringify(spec) !== JSON.stringify(words)))
        settingsDrift.push(key + " words differ: " + JSON.stringify(words));
    else if ((numeric || (words.length === 0 && Array.isArray(spec))) && spec !== "int")
        settingsDrift.push(key + " should be int");
}
eq("every setting of the pages is in Codes.SETTINGS with its real words", settingsDrift, []);
eq("the check really read the pages", Object.keys(keysFound).length > 30, true);
eq("Codes.SETTINGS holds no key the pages no longer have", Object.keys(Codes.SETTINGS).filter(k => !(k in keysFound) && KEPT_PREFS.indexOf(k) < 0), []);

// The QML engine of Quickshell rejects lookbehind patterns that gjs accepts, which broke
// Redact.js the first time QML loaded it: no diagnostics file may use one.
const diagDir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir()))) + "/diagnostics";
const lookbehind = [];
const diagEnum = Gio.File.new_for_path(diagDir).enumerate_children("standard::name", 0, null);
for (let info = diagEnum.next_file(null); info; info = diagEnum.next_file(null)) {
    const code = new TextDecoder().decode(GLib.file_get_contents(diagDir + "/" + info.get_name())[1]);
    if (code.indexOf("(?<" + "!") >= 0 || code.indexOf("(?<" + "=") >= 0)
        lookbehind.push(info.get_name());
}
eq("no diagnostics file uses a regular expression lookbehind (QML cannot parse it)", lookbehind, []);

// --- Gather.js: what the report is made of -----------------------------------------
eq("versions come out of each tool's own line", [Gather.parse("dms", "dms v1.6.3\n"), Gather.parse("niri", "niri 26.04 (8ed0da4)"), Gather.parse("quickshell", "Quickshell 0.3.1 (revision , distributed by Someone)")], ["1.6.3", "26.04", "0.3.1"]);
eq("a tool that said nothing usable gives an empty version", [Gather.parse("dms", ""), Gather.parse("niri", "error: /home/bob/x not found"), Gather.parse("dms", null)], ["", "", ""]);
eq("the distribution is the pretty name of os-release", Gather.parse("distro", 'NAME="Fedora Linux"\nPRETTY_NAME="Fedora Linux 44 (Workstation Edition)"\nID=fedora\n'), "Fedora Linux 44 (Workstation Edition)");
eq("an os-release without a pretty name gives nothing", Gather.parse("distro", "ID=fedora\n"), "");
eq("the journal is kept as non-empty lines", Gather.parse("journal", "a\n\nb\n"), ["a", "b"]);
eq("the plugin version is read from plugin.json, or empty", [Gather.pluginVersion('{"version":"1.14.0"}'), Gather.pluginVersion("not json"), Gather.pluginVersion('{"version":3}')], ["1.14.0", "", ""]);
eq("only declared settings are read, an unknown value is skipped", Gather.settingsOf(k => k === "sounds" ? true : k === "maxDevices" ? 8 : undefined), { "maxDevices": 8, "sounds": true });
eq("a copy tool that is not installed is told from one that refused", [Gather.missing(-1), Gather.missing(1), Gather.missing(127)], [true, false, false]);
eq("the sensitive copy comes first and nothing is an argument but flags", Gather.COPY_TOOLS.map(t => t.command), [["wl-copy", "--sensitive"], ["dms", "clipboard", "copy"]]);
eq("every probe is an argument list that starts with a program", Gather.PROBES.every(p => Array.isArray(p.command) && /^[a-z]+$/.test(p.command[0])), true);
eq("a long report is cut for the IPC answer", [Gather.capped("x".repeat(30000)).length, Gather.capped("short")], [Gather.MAX_REPORT, "short"]);
eq("a report built from probe answers holds no path of the home folder", /home|bob/i.test(Report.build({ "now": 0, "plugin": Gather.pluginVersion('{"version":"1.0.0"}'), "versions": { "dms": Gather.parse("dms", "dms v1.6.3"), "distro": Gather.parse("distro", 'PRETTY_NAME="Fedora Linux 44"') }, "journal": ["Oct 08 12:00:00 bobs-pc qs[1]: [orbit] ORB-E001 failed at /home/bob/.cache/x"] })), false);

done();
