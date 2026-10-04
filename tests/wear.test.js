// Pause when the headset comes off (Wear.js): the reading's meaning, which
// players are fed to the headset, and which may start again.
// Run from the plugin root: gjs tests/wear.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Wear = load("Wear.js");

// What a reading means: only the two ends decide
eq("classify worn", Wear.classify(0), "worn");
eq("classify removed", Wear.classify(4), "removed");
for (const code of [1, 2, 3, 5, 255, null, undefined, "0", "4"])
    eq("classify undecided " + code, Wear.classify(code), "");

// The first decided reading is a reference and never acts
eq("step: first worn is a reference", Wear.step("", 0), { last: "worn", action: "" });
eq("step: first removed never pauses", Wear.step("", 4), { last: "removed", action: "" });
eq("step: removed after worn pauses", Wear.step("worn", 4), { last: "removed", action: "pause" });
eq("step: worn after removed resumes", Wear.step("removed", 0), { last: "worn", action: "resume" });
eq("step: same state twice does nothing", Wear.step("worn", 0), { last: "worn", action: "" });
eq("step: same removed twice does nothing", Wear.step("removed", 4), { last: "removed", action: "" });
eq("step: one-sided code changes nothing", Wear.step("worn", 1), { last: "worn", action: "" });
eq("step: unknown reading keeps the state", Wear.step("removed", null), { last: "removed", action: "" });
// A whole session, as the headset would report it
let last = "";
const acts = [];
for (const s of [null, 0, 0, 4, 4, 2, 0, 4, 0]) {
    const r = Wear.step(last, s);
    last = r.last;
    acts.push(r.action);
}
eq("step: a whole session", acts, ["", "", "", "pause", "", "", "resume", "pause", "resume"]);

// Only Sony headsets, only when switched on
eq("eligible", [Wear.eligible(true, "sony"), Wear.eligible(false, "sony"), Wear.eligible(true, "bose"), Wear.eligible(true, "")], [true, false, false, false]);

// When the session has to stay open: one probe, then only if the headset has the sensor
const ready = (wear) => ({ status: "ready", features: { wear: wear } });
eq("session: off", Wear.sessionWanted(false, "sony", ready(true)), false);
eq("session: other brand", Wear.sessionWanted(true, "apple", null), false);
eq("session: never asked, one probe", Wear.sessionWanted(true, "sony", null), true);
eq("session: still connecting", Wear.sessionWanted(true, "sony", { status: "connecting" }), true);
eq("session: has the sensor", Wear.sessionWanted(true, "sony", ready(true)), true);
eq("session: no sensor, probe over", Wear.sessionWanted(true, "sony", ready(false)), false);
eq("session: ready without features", Wear.sessionWanted(true, "sony", { status: "ready" }), false);
eq("session: error, no retry loop", Wear.sessionWanted(true, "sony", { status: "error" }), false);

// Which headsets are followed: sorted, stable between two snapshots
const snaps = { "B": ready(true), "A": ready(true), "C": ready(false), "D": null, "E": { status: "connecting" } };
eq("followed", Wear.followed(true, snaps), ["A", "B"]);
eq("followed: off", Wear.followed(false, snaps), []);
eq("followed: nothing yet", Wear.followed(true, null), []);

// Names: one spelling for a player and for a stream
eq("token", Wear.token("Google Chrome"), "googlechrome");
eq("token: dashes", Wear.token("google-chrome"), "googlechrome");
eq("token: nothing", Wear.token(undefined), "");
eq("busName: plain", Wear.busName("org.mpris.MediaPlayer2.spotify"), "spotify");
eq("busName: browser instance", Wear.busName("org.mpris.MediaPlayer2.firefox.instance_1_42"), "firefox");
eq("busName: chromium instance", Wear.busName("org.mpris.MediaPlayer2.chromium.instance3456"), "chromium");
eq("busName: foreign name", Wear.busName("com.example.Player"), "com.example.Player");
eq("playerKeys", Wear.playerKeys({ desktopEntry: "firefox", dbusName: "org.mpris.MediaPlayer2.firefox.instance_1_42", identity: "Mozilla Firefox" }), ["firefox", "firefox", "mozillafirefox"]);
eq("playerKeys: empty fields dropped", Wear.playerKeys({ desktopEntry: "", dbusName: "org.mpris.MediaPlayer2.mpv", identity: "mpv" }), ["mpv", "mpv"]);
eq("streamKeys", Wear.streamKeys({ "application.name": "Firefox", "application.process.binary": "firefox", "media.name": "Some video" }), ["firefox", "firefox"]);
eq("streamKeys: no properties", Wear.streamKeys(null), []);
eq("sameApp: equal names", Wear.sameApp(["spotify"], ["spotify", "x"]), true);
eq("sameApp: different names", Wear.sameApp(["spotify"], ["firefox"]), false);
eq("sameApp: no containment guess", Wear.sameApp(["chrome"], ["googlechrome"]), false);
eq("sameApp: nothing to compare", Wear.sameApp([], ["spotify"]), false);

// Which players to pause
const player = (name, playing, extra) => Object.assign({ desktopEntry: name, dbusName: "org.mpris.MediaPlayer2." + name, identity: name, isPlaying: playing, canPause: true }, extra);
const spotify = player("spotify", true);
const firefox = player("firefox", true);
const mpv = player("mpv", false);
const stuck = player("vlc", true, { canPause: false });
const apps = [["spotify"], ["firefox", "mozillafirefox"], ["vlc"]];
eq("pausable: the ones on the headset", Wear.pausable([spotify, firefox, mpv, stuck], apps), [spotify, firefox]);
eq("pausable: a player on the speakers is left alone", Wear.pausable([spotify, firefox], [["spotify"]]), [spotify]);
eq("pausable: no stream on the headset", Wear.pausable([spotify, firefox], []), []);
eq("pausable: nobody playing", Wear.pausable([mpv], [["mpv"]]), []);
eq("pausable: no list", Wear.pausable(null, apps), []);
eq("pausable: no apps", Wear.pausable([spotify], null), []);

// Which of them may start again
const PAUSED = 2, PLAYING = 1;
const held = [player("spotify", false, { playbackState: PAUSED, canPlay: true }), player("firefox", false, { playbackState: PAUSED, canPlay: true })];
eq("resumable: both still paused", Wear.resumable(held, held.slice(), PAUSED).length, 2);
held[0].playbackState = PLAYING;
eq("resumable: one played meanwhile", Wear.resumable(held, held.slice(), PAUSED), [held[1]]);
held[1].canPlay = false;
eq("resumable: one cannot play", Wear.resumable(held, held.slice(), PAUSED), []);
held[1].canPlay = true;
eq("resumable: a player that left", Wear.resumable(held, [held[0]], PAUSED), []);
eq("resumable: a new instance is not the same", Wear.resumable(held, [Object.assign({}, held[1])], PAUSED), []);
eq("resumable: nothing held", Wear.resumable([], held, PAUSED), []);
eq("resumable: no lists", Wear.resumable(null, null, PAUSED), []);

// What the status command tells
eq("report: off", Wear.report(false, "sony", ready(true)), { state: "off" });
eq("report: other brand", Wear.report(true, "bose", null), { state: "unsupported" });
eq("report: no answer yet", Wear.report(true, "sony", null), { state: "waiting" });
eq("report: connecting", Wear.report(true, "sony", { status: "connecting" }), { state: "waiting" });
eq("report: error", Wear.report(true, "sony", { status: "error" }), { state: "error" });
eq("report: no sensor", Wear.report(true, "sony", ready(false)), { state: "unsupported" });
eq("report: sensor, no reading yet", Wear.report(true, "sony", { status: "ready", features: { wear: true }, state: { wearing: null } }), { state: "waiting", code: null, holding: 0 });
eq("report: worn", Wear.report(true, "sony", { status: "ready", features: { wear: true }, state: { wearing: 0 } }, 0), { state: "worn", code: 0, holding: 0 });
eq("report: removed, holding two", Wear.report(true, "sony", { status: "ready", features: { wear: true }, state: { wearing: 4 } }, 2), { state: "removed", code: 4, holding: 2 });
eq("report: one-sided code is unclear", Wear.report(true, "sony", { status: "ready", features: { wear: true }, state: { wearing: 2 } }), { state: "unclear", code: 2, holding: 0 });

done();
