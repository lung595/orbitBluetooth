// The leaks a security review found in the anonymous report, one check each: the account,
// the machine, an address, a personal path, a pairing code, a device name. Every name,
// address and secret below is made up (account "jdoe", machine "hostq", secret "hunter2",
// device "Zorg Buds").
// Run from the plugin root: gjs tests/reportLeaks.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Log = load("Log.js");
const Redact = load("Redact.js");
const Report = load("Report.js");
const ReportFile = load("ReportFile.js");
const Gather = load("Gather.js");

Log.setSink({ "error": () => {}, "warn": () => {} });
const HT = "ht" + "tp";
const NOW = Date.UTC(2026, 9, 8, 12, 3, 41);

// The words of `words` a text still shows
function shown(text, words) {
    return words.filter(w => text.toLowerCase().indexOf(w.toLowerCase()) >= 0);
}
// Each line alone, cleaned twice: nothing of `words` may be left, and the second
// cleaning changes nothing
function hidden(title, lines, words) {
    for (const line of lines) {
        const once = Redact.text(line);
        eq(title + ": " + JSON.stringify(line), [shown(once, words), Redact.text(once)], [[], once]);
    }
}

// --- The machine name before a journal line, whatever the language and the format ---
const journalProbe = Gather.PROBES.filter(p => p.key === "journal")[0].command;
eq("the journal is asked for without its prefix and in no language", [journalProbe.indexOf("LC_ALL=C") >= 0, journalProbe.slice(-2)], [true, ["-o", "cat"]]);
const stamps = ["oct. 08 12:00:00", "janv. 08 12:00:00", "f\u00e9vr. 08 12:00:00", "mars 08 12:00:00", "ao\u00fbt 08 12:00:00", "d\u00e9c. 08 12:00:00", "M\u00e4r 08 12:00:00", "pa\u017a 08 12:00:00", "\u043e\u043a\u0442 08 12:00:00", "10\u6708 08 12:00:00", "Oct 08 12:00:00.123456", "1791460800.123456", "[ 1234.567890]", "Thu 2026-10-08 12:00:00 CEST", "  Oct 08 12:00:00", "\tOct 08 12:00:00"];
for (const stamp of stamps) {
    const report = Report.build({ "now": NOW, "journal": [stamp + " hostq qs[123]: [orbit] ORB-E001 tagged", stamp + " hostq qs[123]: ERROR qml: OrbitBluetooth engine", stamp + " hostq my prog[9]: OrbitBluetooth spaced"] });
    eq("no machine name before a journal line dated " + JSON.stringify(stamp), [shown(report, ["hostq", "12:00:00"]), report.split("\n").filter(l => /^ {2}(\[orbit\] ORB-E001 tagged|ERROR qml: OrbitBluetooth engine|OrbitBluetooth spaced)$/.test(l)).length], [[], 3]);
}
const noPid = Report.build({ "now": NOW, "journal": ["oct. 08 12:00:00 hostq qs: OrbitBluetooth failed", "{\"_HOSTNAME\":\"hostq\",\"MESSAGE\":\"[orbit] ORB-E001 json\"}"] });
eq("nor without a process number, nor in the JSON format", shown(noPid, ["hostq"]), []);
eq("the level of a tagged line is kept", Report.build({ "journal": ["Oct 08 12:00:00 hostq qs[1]: WARN qml: [orbit] ORB-W010 state=off"] }).indexOf("\n  WARN qml: [orbit] ORB-W010 state=off\n") > 0, true);

// --- The account and the machine the report is made on, given by the caller ---------
eq("the account is read from the home folder and the machine from its file", [Gather.account("\x2fhome/jdoe"), Gather.account("\x2fhome/jdoe/"), Gather.account(null), Gather.parse("host", "hostq\n"), Gather.parse("host", "two words\n"), Gather.parse("host", null)], ["jdoe", "jdoe", "", "hostq", "", ""]);
Redact.forget();
const known = Report.build({ "now": NOW, "user": "jdoe", "host": "hostq.example.org", "journal": [
    "[orbit] adapter hostq powered, owner jdoe", "[orbit] open /tmp/jdoe-cache/x and /srv/pool/jdoe/a", "[orbit] JDOE on HOSTQ and hostq.example.org", "[orbit] controller name hostq #1", "[orbit] jdoes hostqs"
] });
eq("the account and the machine are hidden wherever a line writes them", [shown(known.replace(/jdoes hostqs/, ""), ["jdoe", "hostq"]), known.indexOf("jdoes hostqs") > 0, known.indexOf("user#1") > 0, known.indexOf("host#1") > 0], [[], true, true, true]);
Redact.forget();
eq("a name anybody has is not an account", [Redact.register("user", "root"), Redact.register("host", "localhost"), Redact.register("host", "fedora"), Redact.register("user", "x")], ["", "", "", ""]);
hidden("the machine after a key or in a link", ["hostname=hostq", "host: hostq", "Hostname: hostq up", "\\\\hostq\\share", "smb:\x2f/hostq/music", "ssh:\x2f/hostq", "ping hostq.fritz.box", "ping hostq.box", "ping hostq.corp", "ping hostq.mshome.net", "ping hostq.local"], ["hostq"]);
hidden("the account after a key or in a phrase", ["user jdoe", "User jdoe logged in", "user 'jdoe'", "owner=jdoe", "account=jdoe", "name=jdoe", "session of jdoe", "session for user jdoe", "uid 1000 (jdoe)", "uid=1000(jdoe)", "login: jdoe", "user=42,jdoe", "jdoe@hostq"], ["jdoe"]);

// --- A secret after "key" or "pin" (the exceptions of the last round were too wide) ---
hidden("a value after key or pin", ["key: yes.hunter2", "key=yes.hunter2", "pin: no.hunter2", "pin=my.hunter2pass", "Key: Abc.Hunter2", "key: hunter2 pressed", "pin: hunter2 released", "key: true,hunter2", "key: yes hunter2", "key: api.hunter2"], ["hunter2"]);
hidden("a dotted word after key", ["key: correct.horse", "pin: Secret.word"], ["horse", "word"]);
hidden("a secret behind a short key", ["pass=hunter2", "pw=hunter2", "auth=hunter2", "otp=hunter2", "code=hunter2", "sig=hunter2", "seed=hunter2", "nonce: hunter2"], ["hunter2"]);
hidden("a secret without a sign", ["token hunter2", "password hunter2", "password is hunter2", "--password hunter2", "--token hunter2", "link key hunter2ab"], ["hunter2"]);
hidden("a secret in a header", ["Cookie: a=1; sid=hunter2", "Set-Cookie: sid=hunter2; Path=/", "Authorization: Token hunter2", "Authorization: Basic aHVudGVyMg==", "Basic aHVudGVyMg==", "mot de passe: hunter2"], ["hunter2", "aHVudGVyMg"]);
hidden("a pairing code", ["PIN code: 4821", "Enter PIN code: 4821", "PIN is 4821", "PIN4821", "Request confirmation 482193", "Confirm passkey 482193", "pairing code 482193", "passkey: 482193", "pin=4821"], ["4821"]);
// R4: a secret longer than what is read of a text
hidden("a secret cut by the cap", [HT + ":\x2f/jdoe:" + "hunter2".repeat(200) + "@example.org/a", "secret=\"" + "hunter2 ".repeat(200) + "\"", "password=" + "hunter2".repeat(40) + " tail"], ["hunter2", "jdoe"]);

// --- A drive mounted for the account, a folder named after it ------------------------
hidden("a media folder under another root", ["\x2fhost/media/jdoe", "\x2frun/host/media/jdoe/a", "\x2fvar/host/media/jdoe", "\x2fsysroot/media/jdoe", "x-/media/jdoe", "cd \x2fdata/media/jdoe/x", "\x2fmedia/jdoe/a.oga"], ["jdoe"]);
hidden("a folder under a mount point", ["\x2fmnt/data/jdoe/x", "\x2fmnt/share/jdoe/x", "\x2fmnt/usb/jdoe", "\x2fmnt/nas/jdoe/a/b", "\x2fmnt/disk/jdoe", "\x2fmnt/jdoe/x"], ["jdoe"]);
hidden("the home folder written another way", ["\x2f\x2fhome\x2f\x2fjdoe/x","\x2fhome/./jdoe/x", "%2Fhome%2Fjdoe%2Fx", "\x2fHOME/jdoe/x", "\x2fHome/jdoe", "\\home\\jdoe\\x", "C:\\Users\\jdoe\\x", "\x2fhome/.ecryptfs/jdoe/x", "\x2fvar\x2fhome/jdoe/x", "\x2fhome/jdoe/Music/jdoe-mix.flac", "\x2fvar/mail/jdoe", "\x2fvar/spool/cron/jdoe"], ["jdoe"]);
eq("a space in the account's folder", shown(Redact.text("open \x2fhome/jdoe smith/x.txt"), ["jdoe", "smith"]), []);

// --- An address written an unusual way -----------------------------------------------
hidden("a Bluetooth address", ["AA.BB.CC.DD.EE.01", "AA,BB,CC,DD,EE,01", "AA/BB/CC/DD/EE/01", "AA  BB  CC  DD  EE  01", "AA\\:BB\\:CC\\:DD\\:EE\\:01", "AA:BB:CC:DD:EE:01x", "AABBCC:DDEE01", "AABB.CCDD.EE01", "dev AA:BB:CC up", "AA: BB: CC: DD: EE: 01", "AA :BB :CC :DD :EE :01", "AA%3ABB%3ACC%3ADD%3AEE%3A01", "AA_BB_CC_DD_EE_01", "AABBCCDDEE01"], ["BB", "EE"]);
hidden("a network address", ["ip 192-168-7-23 up", "::ffff:192.168.7.23", "fe80::1ff:fe23:4567:890a%eth0", "192.168.7.23:8080"], ["168", "fe23"]);

// --- A device name the list holds another way, or a line writes another way (R5) -----
function fileOf(device, line) {
    Redact.forget();
    return ReportFile.build({ "now": NOW, "devices": [device], "journal": ["[orbit] seen " + line + " again"] });
}
for (const key of ["name", "deviceName", "alias", "model", "title", "label", "nickname", "Name", "friendlyName", "ALIAS"]) {
    const device = {};
    device[key] = "Zorg Buds";
    eq("a device name under " + key, shown(fileOf(device, "Zorg Buds"), ["Zorg"]), []);
}
const unreadable = [{ "a": "Zorg Buds" }, [["Zorg Buds"]], ["a", { "b": "Zorg Buds" }], Symbol("Zorg Buds"), new Array(9).fill("Zorg Buds")];
for (let u = 0; u < unreadable.length; u++) {
    const out = fileOf({ "name": unreadable[u], "kind": "tv" }, "Zorg Buds");
    eq("a name that cannot be read takes the journal away, case " + u, [shown(out, ["Zorg"]), out.indexOf("1 not readable, journal lines left out") > 0], [[], true]);
}
eq("a name that is a function is no name", shown(fileOf({ "name": () => "x", "alias": "Zorg Buds" }, "Zorg Buds"), ["Zorg"]), []);
for (const form of ["ZorgBuds", "Zorg-Buds", "Zorg.Buds", "Zorg+Buds", "Zorg,Buds", "Zorg\\040Buds", "Zorg&#32;Buds", "Zorg%20Buds", "zorg_buds", "Zorg", "the Zorg ones", "ZORG  BUDS"])
    eq("a device name written " + JSON.stringify(form), shown(fileOf({ "name": "Zorg Buds" }, form), ["zorg"]), []);
eq("a device name written without its accents", shown(fileOf({ "name": "Z\u00f6rg B\u00fcds" }, "Zorg Buds"), ["zorg", "z\u00f6rg"]), []);
eq("a word that says what a device is stays readable", fileOf({ "name": "Zorg Wireless Headphones" }, "Wireless Headphones").indexOf("seen Wireless Headphones again") > 0, true);

// --- A device named like a word the rules leave readable: twice is the same as once ---
const words = [["yes", "pin: yes"], ["data", "open \x2fmnt/data"], ["request", "cancelled by user request"], ["1", "user=1"], ["pressed", "key: Enter pressed"], ["usb", "\x2fmnt/usb/x"], ["Enter", "key: Enter pressed"]];
for (const [name, line] of words) {
    Redact.forget();
    Redact.register("device", name);
    const once = Redact.text(line);
    eq("a device named " + JSON.stringify(name) + " is hidden once and for all", [once.indexOf("device#1") >= 0, Redact.text(once), Redact.text(Redact.text(once))], [true, once, once]);
}
Redact.forget();

// --- What is nobody's stays readable ---------------------------------------------------
for (const plain of ["key: Enter pressed", "key: a released", "pin: yes", "user=42", "cancelled by user request", "key: api.bluez5.codec", "open \x2fmnt/usb and \x2fmnt/data", "ORB-E003 tool=pw_loopback code=1", "ORB-E003 tool=? code=1000000000", "code=-1000000000", "pins: 3", "play \x2fusr/share/media/sounds/bell.oga", "connected at 12:00:01 in 250 ms"])
    eq("stays readable: " + plain, Redact.text(plain), plain);

done();
