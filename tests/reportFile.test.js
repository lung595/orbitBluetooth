// The report written as a file: its name, its device lines and its error counts. Every
// name, address and path below is made up. As in diagnostics.test.js the checks that
// matter most are the leak ones: whatever goes in, none of it may come out.
// Run from the plugin root: gjs tests/reportFile.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Codes = load("Codes.js");
const Codecs = load("Codecs.js");
const Glyphs = load("Glyphs.js");
const Log = load("Log.js");
const Redact = load("Redact.js");
const ReportFile = load("ReportFile.js");

Log.setSink({ "error": () => {}, "warn": () => {} });
const MAC = "AA:BB:CC:DD:EE:01";
const NOW = Date.UTC(2026, 9, 8, 12, 3, 41);

// --- Codes.DEVICE: what may be said of a device ------------------------------------
eq("a device is said in numbers, yes/no and listed words only", Object.values(Codes.DEVICE).filter(s => !(s === "int" || s === "bool" || Array.isArray(s))), []);
eq("no key of a device can hold a name or an address", Object.keys(Codes.DEVICE).filter(k => /name|alias|model|address|mac|path|id/i.test(k)), []);
eq("the kinds are the glyphs the plugin draws", Codes.DEVICE.kind, Glyphs.order);
eq("the codecs are the ones the plugin knows", Codes.DEVICE.codec, Object.keys(Codecs.CODECS));
eq("every device word is a short plain token", Codes.DEVICE.kind.concat(Codes.DEVICE.codec).filter(w => !/^[A-Za-z0-9_.-]{1,24}$/.test(w)), []);

// --- fileName: dated, nothing personal ---------------------------------------------
eq("the name is the plugin's label and the time, UTC", ReportFile.fileName(NOW), "orbit-report-20261008-120341Z.txt");
eq("one-digit parts are padded", ReportFile.fileName(Date.UTC(2027, 0, 2, 3, 4, 5)), "orbit-report-20270102-030405Z.txt");
const shape = /^orbit-report-\d{8}-\d{6}Z\.txt$/;
eq("a time that is not one still gives a plain name", [undefined, null, "\x2fhome/jdoe", NaN, Infinity, 1e300, {}, "../../x"].filter(t => !shape.test(ReportFile.fileName(t))), []);
eq("the name cannot leave its folder", /[\/\\\s]|\.\./.test(ReportFile.fileName(NOW)), false);

// --- devices: one line each, from the allowlist ------------------------------------
Redact.forget();
const buds = { "name": "Bob's AirPods Pro", "alias": "Bob's buds", "model": "AirPods Pro", "address": MAC, "path": "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_01", "kind": "earbudsStem", "connected": true, "paired": true, "trusted": true, "codec": "aac", "battery": 80, "batteryLeft": 79.6, "batteryRight": 81, "batteryCase": 40, "charging": false };
const speaker = { "name": "kitchen speaker", "kind": "speaker", "connected": false, "paired": true, "codec": "Bob's codec", "battery": "full" };
eq("a device is written from its allowed facts, under its alias", ReportFile.devices([buds, speaker]), [
    "Devices (2 known, 1 connected):",
    "  device#1 kind=earbudsStem connected=yes paired=yes trusted=yes codec=aac battery=80 batteryLeft=80 batteryRight=81 batteryCase=40 charging=no",
    "  device#4 kind=speaker connected=no paired=yes codec=? battery=?"
]);
eq("every name of a device is hidden afterwards, the model too", Redact.text("Bob's AirPods Pro, Bob's buds, AirPods Pro, kitchen speaker"), "device#1, device#2, device#3, device#4");
eq("the same device keeps its alias from one report to the next", ReportFile.devices([speaker])[1], "  device#4 kind=speaker connected=no paired=yes codec=? battery=?");
eq("no device, no line", [ReportFile.devices([]), ReportFile.devices(null), ReportFile.devices("Bob"), ReportFile.devices({ "length": 3 })], Array(4).fill(["Devices (0 known, 0 connected):", "  none"]));
eq("a device that is not one, or says nothing allowed, is a ?", ReportFile.devices([null, "Bob's phone", 7, {}, { "name": "x" }, { "address": MAC }]).slice(1), Array(6).fill("  device ?"));
// A getter that throws is the caller's bug; a prototype key is not a fact
eq("an inherited key is not read", ReportFile.devices([Object.create({ "kind": "phone", "name": "Inherited Bob" })])[1], "  device#5 ?");

// Each rule, one hostile device at a time: the value goes in every allowed key and in
// keys nobody allowed, and the whole text is searched
const hostile = {
    "full address": MAC,
    "address, lower case": "aa:bb:cc:dd:ee:01",
    "address with dashes": "AA-BB-CC-DD-EE-01",
    "BlueZ path": "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_01",
    "name the user chose": "Bob's AirPods Pro",
    "login": "jdoe",
    "host name": "laptop-jdoe.local",
    "bare host name": "laptop-jdoe",
    "home path": "\x2fhome/jdoe/Downloads/secret.txt",
    "network address": "192.168.7.23",
    "token": "tskey-auth-kAbCdEfGh12345",
    "e-mail": "jdoe@example.org"
};
const forbidden = ["AA:BB", "aa:bb", "AA-BB", "AA_BB", "EE:01", "Bob", "AirPods", "jdoe", "laptop", "Downloads", "secret.txt", "192.168", "tskey", "example.org"];
for (const what in hostile) {
    Redact.forget();
    const device = { "name": hostile[what], "alias": hostile[what], "model": hostile[what], "address": hostile[what], "hostname": hostile[what], "user": hostile[what] };
    for (const key in Codes.DEVICE)
        device[key] = hostile[what];
    device[hostile[what]] = true;
    const text = ReportFile.build({ "now": NOW, "plugin": hostile[what], "versions": { "dms": hostile[what], "distro": hostile[what] }, "settings": { "hostGlyph": hostile[what] }, "facts": { "devices": hostile[what] }, "devices": [device] });
    eq("no leak from a device: " + what, forbidden.filter(f => text.indexOf(f) >= 0), []);
}

// --- errors: counted by code -------------------------------------------------------
Redact.forget();
Log.clear();
eq("no event, no error", ReportFile.errors(), ["Errors and warnings (0 among the 0 events kept):", "  none"]);
Log.event("ORB-W010", { "state": "off" });
Log.event("ORB-E001", { "action": "connect", "reason": "timeout" });
Log.event("ORB-I020", { "surface": "widget" });
Log.event("ORB-E001", { "action": "pair", "reason": "refused" });
Log.event("ORB-D040", { "state": "hidden", "count": 3 });
eq("errors and warnings are counted by code, info and debug are not", ReportFile.errors(), [
    "Errors and warnings (3 among the 5 events kept):",
    "  ORB-E001 x2 (A Bluetooth action failed)",
    "  ORB-W010 x1 (No usable Bluetooth adapter)"
]);

// --- build: the whole file ---------------------------------------------------------
Redact.register("user", "jdoe");
const report = ReportFile.build({
    "now": NOW,
    "plugin": "1.16.0",
    "versions": { "dms": "1.6.3", "quickshell": "0.3.1", "qt": "6.11.2", "niri": "25.08", "distro": "Fedora Linux 44" },
    "surfaces": { "widget": true },
    "settings": { "showLabels": true },
    "facts": { "devices": 2 },
    "cpu": { "percent": 4.2, "windowMs": 1000 },
    "devices": [buds, speaker],
    "journal": [
        "Oct 08 12:00:00 laptop-jdoe qs[123]: [orbit] ORB-E001 action=connect reason=timeout",
        "ERROR qml: OrbitBluetooth at file://\x2fhome/jdoe/.config/x/A.qml[4:1]: Bob's buds (AirPods Pro) " + MAC + " of jdoe on kitchen speaker"
    ]
});
const lines = report.split("\n");
eq("the file starts as the clipboard report does", lines.slice(0, 3), ["OrbitBluetooth diagnostic report (anonymous: versions, states and codes only)", "Created      : 2026-10-08 12:03:41 UTC", "Plugin       : OrbitBluetooth 1.16.0"]);
eq("a device named in a journal line carries the alias of its own line", lines.filter(l => l.indexOf("A.qml") >= 0), ["  ERROR qml: OrbitBluetooth at file://~/.config/x/A.qml[4:1]: device#2 (device#3) <mac> of user#1 on device#4"]);
eq("the devices and the error counts close the file", lines.slice(-7), [
    "Devices (2 known, 1 connected):",
    "  device#1 kind=earbudsStem connected=yes paired=yes trusted=yes codec=aac battery=80 batteryLeft=80 batteryRight=81 batteryCase=40 charging=no",
    "  device#4 kind=speaker connected=no paired=yes codec=? battery=?",
    "Errors and warnings (3 among the 5 events kept):",
    "  ORB-E001 x2 (A Bluetooth action failed)",
    "  ORB-W010 x1 (No usable Bluetooth adapter)",
    ""
]);
eq("no name, address, login, machine or path anywhere in the file", ["Bob", "AirPods", "kitchen", "jdoe", "laptop", "AA:BB", "AA_BB", "\x2fhome/"].filter(w => report.indexOf(w) >= 0), []);
eq("every line is printable and short", lines.filter(l => l.length > Redact.MAX_LINE + 2 || /[\u0000-\u001f\u007f]/.test(l)), []);

// Empty state
Redact.forget();
Log.clear();
for (const nothing of [undefined, null, {}, "x", 7, []]) {
    const bare = ReportFile.build(nothing).split("\n");
    eq("a file with nothing is still a report: " + JSON.stringify(nothing), [bare[2], bare.slice(-5)], ["Plugin       : OrbitBluetooth ?", ["Devices (0 known, 0 connected):", "  none", "Errors and warnings (0 among the 0 events kept):", "  none", ""]]);
}
eq("hostile shapes never throw", ReportFile.build({ "devices": { "0": buds }, "now": "never", "journal": 5, "versions": [] }).indexOf("Devices (0 known") > 0, true);

// Special characters: a name is taken literally, a control character cannot forge a line
Redact.forget();
const odd = ["(my) [pods]+ $1 \\d.*", "Écouteurs de Zoé 🎧", "耳机 蓝牙", "a\nDevices (0 known)\nfake", "<script>alert(1)</script>", "\u202Edetrevni", "  ", "x", "%s %n {0}", "'; rm -rf ~ #", "name\twith\ttabs", "\u0000nul"];
const oddText = ReportFile.build({ "now": NOW, "devices": odd.map(n => ({ "name": n, "kind": n, "codec": n, "connected": n, "battery": n })), "journal": odd.map(n => "[orbit] seen " + n + " again") });
eq("no odd name comes out, whole or in part", ["pods", "Zoé", "🎧", "耳机", "fake", "script", "detrevni", "rm -rf", "tabs", "nul", "%s"].filter(w => oddText.indexOf(w) >= 0), []);
eq("a name cannot add a line to the file", oddText.split("\n").filter(l => /^Devices/.test(l)), ["Devices (12 known, 0 connected):"]);
eq("every odd device has its line", oddText.split("\n").filter(l => /^ {2}device(#\d+)? kind=\? connected=\? codec=\? battery=\?$/.test(l)).length, 12);
eq("no control character in the file but its line ends", /[\u0000-\u0009\u000b-\u001f\u007f]/.test(oddText), false);

// A very large state: counted whole, shown in part, still quick and every name hidden
Redact.forget();
Log.clear();
for (let n = 0; n < 1000; n++)
    Log.event(n % 2 ? "ORB-E001" : "ORB-W011", { "action": "connect", "reason": "timeout", "tool": "pactl" });
const many = [];
for (let n = 0; n < 2000; n++)
    many.push({ "name": "Headset of person " + n, "address": MAC, "kind": "headphones", "connected": n % 4 === 0, "codec": "ldac", "battery": n % 101 });
const journal = [];
for (let n = 0; n < 5000; n++)
    journal.push("[orbit] ORB-E001 with Headset of person " + (n % 2000) + " at " + MAC + " " + "y".repeat(500));
const started = Date.now();
const big = ReportFile.build({ "now": NOW, "devices": many, "journal": journal });
const took = Date.now() - started;
const bigLines = big.split("\n");
eq("a huge state is counted whole and shown in part", bigLines.filter(l => /^Devices/.test(l)), ["Devices (2000 known, 500 connected, first 32 shown):"]);
eq("32 device lines at most", [ReportFile.MAX_DEVICES, bigLines.filter(l => /^ {2}device#\d+ kind=headphones/.test(l)).length], [32, 32]);
eq("the journal stays at its 50 lines and the events at the buffer's 200", [bigLines.filter(l => /^ {2}\[orbit\]/.test(l)).length, bigLines.filter(l => /^ {2}\d\d:\d\d:\d\d ORB-/.test(l)).length], [50, 200]);
eq("the errors are the buffer's, counted", bigLines.slice(-4), ["Errors and warnings (200 among the 200 events kept):", "  ORB-E001 x100 (A Bluetooth action failed)", "  ORB-W011 x100 (A helper program is missing)", ""]);
eq("a device past the 32 shown is hidden in the journal all the same", ["Headset", "person", "AA:BB"].filter(w => big.indexOf(w) >= 0), []);
eq("the file stays small enough to read and attach", big.length < 40000, true);
eq("and is built in a few seconds at worst", took < 10000, true);

done();
