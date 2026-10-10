// "deco xm6 30": the phrase parser, the device match and the pending delays.
// Run from the plugin root: gjs tests/disconnectPhrase.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const P = load("DisconnectPhrase.js");
const W = load("LauncherWords.js");
const words = W.resolve(undefined);
const ok = (q, m) => ({ "ok": true, "action": "disconnect", "query": q, "minutes": m });

eq("short form", P.parse("deco xm6 5", words), ok("xm6", 5));
eq("english, off", P.parse("off xm6 30", words), ok("xm6", 30));
eq("delay first, english", P.parse("in 5 min disconnect xm6", words), ok("xm6", 5));
eq("delay first, french", P.parse("dans 5 min deco xm6", words), ok("xm6", 5));
eq("hours", [P.parse("deco xm6 2h", words).minutes, P.parse("deco xm6 2 heures", words).minutes], [120, 120]);
eq("a glued unit", P.parse("deco xm6 5min", words), ok("xm6", 5));
eq("case and accents", P.parse("DÉCO Xm6 5", words), ok("xm6", 5));
eq("a name with a number and spaces", P.parse("deco wh 1000xm4 10", words), ok("wh 1000xm4", 10));
eq("a number in the name, delay with a unit", P.parse("deco airpods 2 10 min", words), ok("airpods 2", 10));
// Custom words
eq("a meaningless word", P.parse("zz xm6 5", { "disconnect": ["zz"] }), ok("xm6", 5));
eq("two words for one action", [P.parse("zz xm6 5", { "disconnect": ["zz", "coupe"] }).ok, P.parse("coupe xm6 5", { "disconnect": ["zz", "coupe"] }).ok], [true, true]);
eq("a word of the defaults is not special", P.parse("deco xm6 5", { "disconnect": ["zz"] }).why, "noWord");
// Bad phrases
eq("no word", P.parse("xm6 5", words).why, "noWord");
eq("no delay", P.parse("deco xm6", words).why, "noDelay");
eq("no device", P.parse("deco 5", words).why, "noDevice");
eq("empty and too long", [P.parse("  ", words).why, P.parse("deco " + "a".repeat(130), words).why], ["empty", "long"]);
eq("0 and 1441 minutes", [P.parse("deco xm6 0", words).why, P.parse("deco xm6 1441", words).why], ["badDelay", "badDelay"]);
eq("1 and 1440 minutes", [P.parse("deco xm6 1", words).minutes, P.parse("deco xm6 1440", words).minutes, P.parse("deco xm6 24h", words).minutes], [1, 1440, 1440]);
eq("a fraction is not a delay", P.parse("deco xm6 1.5", words).why, "badDelay");
eq("not a text", P.parse(undefined, words).why, "empty");
// Devices
const devs = [{ "address": "A1", "name": "WH-1000XM6" }, { "address": "A2", "name": "Pods Démo" }, { "address": "A3", "name": "Pods Two" }, { "address": "A4", "name": "" }];
eq("a fragment", P.findDevice("xm6", devs), { "ok": true, "address": "A1" });
eq("accents and case", P.findDevice("DEMO", devs), { "ok": true, "address": "A2" });
eq("unknown", P.findDevice("zzz", devs).why, "none");
eq("ambiguous is never guessed", P.findDevice("pods", devs).why, "ambiguous");
eq("an exact name beats a fragment", P.findDevice("pods two", devs).address, "A3");
eq("empty query, no devices", [P.findDevice("", devs).why, P.findDevice("x", []).why], ["noDevice", "none"]);
// The launcher and the command line pass an address
const addr = [{ "address": "AA:BB:CC:DD:EE:FF", "name": "WH-1000XM6" }, { "address": "11:22:33:44:55:66", "name": "aa:bb Pods" }];
eq("an exact address, any case", [P.findDevice("aa:bb:cc:dd:ee:ff", addr), P.findDevice("AA:BB:CC:DD:EE:FF", addr)], [{ "ok": true, "address": "AA:BB:CC:DD:EE:FF" }, { "ok": true, "address": "AA:BB:CC:DD:EE:FF" }]);
eq("only the connected devices", P.connectedOf([{ "address": "A1", "name": "X", "connected": true }, { "address": "A2", "name": "Y", "connected": false }, { "address": "A3", "connected": true }]), [{ "address": "A1", "name": "X" }, { "address": "A3", "name": "" }]);
eq("no list, no devices", [P.connectedOf(undefined), P.connectedOf([])], [[], []]);
eq("every refusal has a note", ["badDelay", "noDelay", "noDevice", "long", "none", "ambiguous", "nothing"].every(w => P.note(w).length > 0 && P.note(w).indexOf("\u2014") < 0), true);
eq("a long dash from outside becomes a hyphen", [P.plain("Kate \u2014 notes"), P.plain("A\u2013B"), P.plain(null)], ["Kate - notes", "A - B", ""]);
eq("an unknown reason still says something", P.note("zzz"), P.note("noDevice"));
// IPC minutes
eq("clean minutes", [P.cleanMinutes("5"), P.cleanMinutes(30), P.cleanMinutes("0"), P.cleanMinutes("1441"), P.cleanMinutes("1.5"), P.cleanMinutes("-3"), P.cleanMinutes(""), P.cleanMinutes("999999")], [5, 30, null, null, null, null, null, null]);
// Pending delays
let p = P.schedule({}, "A1", 5, 1000);
eq("end time", p, { "A1": 301000 });
p = P.schedule(p, "A1", 10, 1000);
eq("rescheduling replaces", p, { "A1": 601000 });
eq("cancel", P.cancel(p, "A1"), {});
eq("cancel of nothing", P.cancel({}, "A9"), {});
eq("the input map is not changed", p, { "A1": 601000 });
done();
