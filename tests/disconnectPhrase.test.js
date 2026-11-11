// Disconnect after a delay: the device match, the IPC minutes and the pending delays.
// Run from the plugin root: gjs tests/disconnectPhrase.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const P = load("DisconnectPhrase.js");

// Devices
const devs = [{ "address": "A1", "name": "WH-1000XM6" }, { "address": "A2", "name": "Pods Démo" }, { "address": "A3", "name": "Pods Two" }, { "address": "A4", "name": "" }];
eq("a fragment", P.findDevice("xm6", devs), { "ok": true, "address": "A1" });
eq("accents and case", P.findDevice("DEMO", devs), { "ok": true, "address": "A2" });
eq("unknown", P.findDevice("zzz", devs).why, "none");
eq("ambiguous is never guessed", P.findDevice("pods", devs).why, "ambiguous");
eq("an exact name beats a fragment", P.findDevice("pods two", devs).address, "A3");
eq("empty query, no devices", [P.findDevice("", devs).why, P.findDevice("x", []).why], ["noDevice", "none"]);
// The command line passes an address
const addr = [{ "address": "AA:BB:CC:DD:EE:FF", "name": "WH-1000XM6" }, { "address": "11:22:33:44:55:66", "name": "aa:bb Pods" }];
eq("an exact address, any case", [P.findDevice("aa:bb:cc:dd:ee:ff", addr), P.findDevice("AA:BB:CC:DD:EE:FF", addr)], [{ "ok": true, "address": "AA:BB:CC:DD:EE:FF" }, { "ok": true, "address": "AA:BB:CC:DD:EE:FF" }]);
eq("only the connected devices", P.connectedOf([{ "address": "A1", "name": "X", "connected": true }, { "address": "A2", "name": "Y", "connected": false }, { "address": "A3", "connected": true }]), [{ "address": "A1", "name": "X" }, { "address": "A3", "name": "" }]);
eq("no list, no devices", [P.connectedOf(undefined), P.connectedOf([])], [[], []]);
eq("every refusal has a note", ["badDelay", "noDevice", "none", "ambiguous", "nothing"].every(w => P.note(w).length > 0 && P.note(w).indexOf("\u2014") < 0), true);
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
