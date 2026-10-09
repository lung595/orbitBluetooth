// The signal read of the nearest-PC filter: the busctl command and the parsing of its answer,
// run against a fake busctl (strong, weak, below the floor, absent, failing, garbled) and fed to NearestFilter.
// Run from the plugin root: gjs tests/signal.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;
const { GLib, Gio } = imports.gi;

const Signal = load("Signal.js", []);
const Nearest = load("NearestFilter.js");

const path = n => "/org/bluez/hci0/dev_00_00_00_00_00_" + n;

// --- The command -------------------------------------------------------------------------
eq("one busctl read of RSSI, path after --", Signal.command(path("01")), ["busctl", "--json=short", "get-property", "--", "org.bluez", path("01"), "org.bluez.Device1", "RSSI"]);
eq("only a BlueZ device path is accepted", ["", undefined, null, "/org/bluez/hci0", "/org/bluez/hci0/dev_00_00_00_00_00_0G", path("01") + "; rm", "-h", "/etc/passwd", path("01") + "\n"].map(Signal.command), Array(9).fill(null));

// --- The answer, as text ----------------------------------------------------------------------
eq("a reading", Signal.parse(0, '{"type":"n","data":-62}'), -62);
eq("no reading: exit code not 0", [Signal.parse(1, ""), Signal.parse(2, '{"type":"n","data":-62}')], [undefined, undefined]);
eq("no reading: not an int16 below 0", ["", "x", "null", "[]", '{"type":"n","data":0}', '{"type":"n","data":12}', '{"type":"s","data":"-40"}', '{"type":"n","data":"-40"}', '{"type":"n"}'].map(t => Signal.parse(0, t)), Array(9).fill(undefined));

// --- A fake busctl on PATH ----------------------------------------------------------------------
const dir = GLib.dir_make_tmp("orbit-busctl-XXXXXX");
const script = dir + "/busctl";
GLib.file_set_contents(script, `#!/bin/sh
# $5 is the object path: its last byte picks the answer
case "$5" in
*_01) echo '{"type":"n","data":-40}' ;;
*_02) echo '{"type":"n","data":-70}' ;;
*_03) echo '{"type":"n","data":-90}' ;;
*_04) echo "Failed to get property RSSI on interface org.bluez.Device1: No such property 'RSSI'" >&2; exit 1 ;;
*_05) echo "Failed to connect to bus" >&2; exit 1 ;;
*_06) echo '{"type":"n","data":' ;;
*_07) echo '{"type":"n","data":127}' ;;
*) exit 3 ;;
esac
`);
GLib.chmod(script, 0o755);
GLib.setenv("PATH", dir + ":" + GLib.getenv("PATH"), true);

// Runs the command the way SignalRead does and reads the answer
function read(n) {
    const command = Signal.command(path(n));
    const p = Gio.Subprocess.new(command, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
    const [, out] = p.communicate_utf8(null, null);
    return Signal.parse(p.get_exit_status(), out);
}
const verdict = n => Nearest.shouldOffer({ "rssi": read(n) });

eq("strong: read, opens at once", [read("01"), verdict("01").offer, verdict("01").delayMs], [-40, true, 0]);
eq("weak: read, opens after a wait", [read("02"), verdict("02").offer, verdict("02").delayMs > 0], [-70, true, true]);
eq("below the floor: not offered here", [read("03"), verdict("03").offer], [-90, false]);
eq("absent (No such property): today's behavior", [read("04"), verdict("04").offer, verdict("04").delayMs], [undefined, true, 0]);
eq("busctl failing: today's behavior", [read("05"), verdict("05").offer, verdict("05").delayMs], [undefined, true, 0]);
eq("garbled answer: today's behavior", [read("06"), verdict("06").offer], [undefined, true]);
eq("BlueZ's marker 127 is no reading", [read("07"), verdict("07").offer], [undefined, true]);
eq("an unknown path ends in no reading", read("99"), undefined);

GLib.unlink(script);
GLib.rmdir(dir);

// --- The re-check when the wait ends -----------------------------------------------------------
const recheck = (rssi, discovering, extra) => Nearest.recheck(Object.assign({ "rssi": rssi, "discovering": discovering }, extra)).offer;
eq("still there and strong enough: offer", recheck(-60, true), true);
eq("fell below the floor during the wait: no pop-up", recheck(-80, true), false);
eq("signal gone while discovering (left or connected elsewhere): no pop-up", [recheck(undefined, true), recheck(0, true)], [false, false]);
eq("signal gone after discovery ended proves nothing: today's behavior", [recheck(undefined, false), recheck(undefined, undefined), recheck(undefined, undefined, undefined)], [true, true, true]);
eq("no context: today's behavior", Nearest.recheck(undefined).offer, true);

done();
