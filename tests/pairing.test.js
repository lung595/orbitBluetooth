// The new-device pop-up: scan rules, offers, sheet colours, the input-device guard.
// Run from the plugin root: gjs tests/pairing.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Palette = load("Palette.js", ["contrast", "ensureContrast", "onColor", "lift", "isGrey", "toHsl", "apart"]);
const Offer = load("Offer.js", ["scanBlocker", "isCandidate", "offerable", "headline", "features", "errorText"]);
const Guard = load("Guard.js", ["offerFamily", "hasInput", "refused", "parseUuids"]);

// New device pop-up: when the background scan may run, what is offered
const ctx = { enabled: true, btOn: true, asleep: false, busy: false, audioConnected: false, onBattery: true, level: 50, minLevel: 30 };
eq("scan: allowed", Offer.scanBlocker(ctx), "");
eq("scan: low battery", Offer.scanBlocker(Object.assign({}, ctx, { level: 29 })), "battery below 30%");
eq("scan: low but plugged in", Offer.scanBlocker(Object.assign({}, ctx, { level: 10, onBattery: false })), "");
eq("scan: no battery", Offer.scanBlocker(Object.assign({}, ctx, { level: -1 })), "");
eq("scan: audio playing", Offer.scanBlocker(Object.assign({}, ctx, { audioConnected: true })), "audio device connected");
eq("scan: screen off", Offer.scanBlocker(Object.assign({}, ctx, { asleep: true })), "screen locked or off");
eq("offer: new headphones", Offer.isCandidate({ address: "A", name: "WH-1000XM6" }, "audio", {}), true);
eq("offer: paired", Offer.isCandidate({ address: "A", name: "WH-1000XM6", paired: true }, "audio", {}), false);
eq("offer: a phone", Offer.isCandidate({ address: "A", name: "Pixel 8" }, "phone", {}), false);
eq("offer: ignored", Offer.isCandidate({ address: "A", name: "WH-1000XM6" }, "audio", { A: "WH-1000XM6" }), false);
eq("offer: address only", Offer.isCandidate({ address: "A", name: "AA:BB:CC:DD:EE:FF" }, "audio", {}), false);
eq("offer: snoozed", Offer.offerable("A", { A: 2000 }, 1000), false);
eq("offer: snooze over", Offer.offerable("A", { A: 2000 }, 3000), true);
eq("headline: earbuds", Offer.headline("earbudsRound"), "New earbuds nearby");
eq("tiles: portable speaker charges", Offer.features({ family: "", hours: 0, kind: "speaker" }).map(t => t.value), ["Volume", "Charging"]);
eq("tiles: soundbar has no battery", Offer.features({ family: "", hours: 0, kind: "soundbar" }).map(t => t.value), ["Volume"]);
eq("tiles: headphones", Offer.features({ family: "sony", hours: 30, kind: "headphonesSlim" }).map(t => t.value), ["Noise control", "≈ 30 h", "Volume"]);
eq("error: declined", Offer.errorText("org.bluez.Error.AuthenticationRejected"), "The pairing was declined.");
eq("error: timeout", Offer.errorText("Page Timeout"), "No answer. Is it still in pairing mode?");
eq("error: unknown", Offer.errorText(""), "Could not connect. Is it still in pairing mode?");

// Pairing sheet colours: any accent reads on either skin
const hex = h => ({ r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255 });
const night = hex("#0A0C14"), pearl = hex("#E6E8EF");
for (const accent of ["#F2B8C6", "#1A3A8F", "#C5E66A", "#4B6818", "#00FFD1", "#BDBDBD"]) {
    eq("readable on night: " + accent, Palette.contrast(Palette.ensureContrast(hex(accent), night, 6), night) >= 6, true);
    eq("readable on pearl: " + accent, Palette.contrast(Palette.ensureContrast(hex(accent), pearl, 4.5), pearl) >= 4.5, true);
    const fill = Palette.ensureContrast(hex(accent), pearl, 4.5);
    eq("button ink: " + accent, Palette.contrast(Palette.onColor(fill), fill) >= 4.5, true);
}
eq("hue kept when fixed", Math.round(Palette.toHsl(Palette.ensureContrast(hex("#F2B8C6"), pearl, 4.5)).h * 100), Math.round(Palette.toHsl(hex("#F2B8C6")).h * 100));
eq("lift", Math.round(Palette.toHsl(Palette.lift(hex("#4B6818"), 0.66)).l * 100), 66);
eq("grey", Palette.isGrey(hex("#BDBDBD")), true);

// Two accents never pass for each other (D270): a pink and a salmon (the
// generated theme that showed it) become a pink and a mint; far apart or
// grey, the second accent stays as it is
const hue = c => Math.round(Palette.toHsl(c).h * 360);
const mint = Palette.apart(hex("#FFB3AE"), hex("#FCABF6"));
eq("near twins: opposite hue", Math.abs(hue(mint) - (hue(hex("#FCABF6")) + 180) % 360) <= 1, true);
eq("near twins: own lightness", Math.round(Palette.toHsl(mint).l * 100), Math.round(Palette.toHsl(hex("#FFB3AE")).l * 100));
eq("far apart: unchanged", hue(Palette.apart(hex("#2F6A5E"), hex("#FCABF6"))), hue(hex("#2F6A5E")));
eq("grey: unchanged", hue(Palette.apart(hex("#BDBDBD"), hex("#FCABF6"))), hue(hex("#BDBDBD")));

// Pairing guard (P115): a fake "headset" that can type is refused
const HID = "00001124-0000-1000-8000-00805f9b34fb", HOG = "00001812-0000-1000-8000-00805F9B34FB", A2DP = "0000110b-0000-1000-8000-00805f9b34fb";
eq("offer: audio class", Guard.offerFamily("audio-headset"), "audio");
eq("offer: no class, headset name is not enough", Guard.offerFamily(""), "");
eq("offer: keyboard class", Guard.offerFamily("input-keyboard"), "");
eq("refuse: headset with HID", Guard.refused("audio", [A2DP, HID]), true);
eq("refuse: headset with HID over LE (upper case)", Guard.refused("audio", [HOG]), true);
eq("refuse: unknown family with HID", Guard.refused("", [HID]), true);
eq("allow: real headset", Guard.refused("audio", [A2DP]), false);
eq("allow: real keyboard", Guard.refused("keyboard", [HID]), false);
eq("allow: real mouse", Guard.refused("pointer", [HOG]), false);
eq("uuids parsed", Guard.parseUuids('{"type":"as","data":["0000110B-x"]}'), ["0000110b-x"]);
eq("uuids: garbage", Guard.parseUuids("nope"), null);
eq("uuids: wrong type", Guard.parseUuids('{"type":"s","data":"x"}'), null);

done();
