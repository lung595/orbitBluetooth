// Accent colours (lifted, grey, two kept apart) and the input-device guard of pairing.
// Run from the plugin root: gjs tests/pairing.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Palette = load("Palette.js", ["lift", "isGrey", "toHsl", "apart"]);
const Guard = load("Guard.js", ["hasInput", "refused", "parseUuids"]);

const hex = h => ({ r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255 });
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
