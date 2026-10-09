// The settings search (SettingsSearch.js) and the index it searches
// (SettingsIndex.js). Run from the plugin root: gjs tests/settingsSearch.test.js
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const S = load("SettingsSearch.js");
const Index = load("SettingsIndex.js");
const Audiophile = load("Audiophile.js");

const ids = (list, q) => S.search(list, q).map(r => r.id);
const first = (list, q) => ids(list, q)[0];

const entries = [
    { id: "a", label: "Noise control", help: "Supported headphones, needs python3", keywords: ["anc", "cancelling"] },
    { id: "b", label: "Wired delay", help: "Nudge the wait that lines up wired outputs", keywords: ["cable", "sync"] },
    { id: "c", label: "Volume tick", help: "A soft tick on each step", keywords: ["sound", "click"] },
    { id: "d", label: "Sounds", help: "On snap, connect and disconnect", keywords: ["audio"] },
    { id: "e", label: "Écran d’accueil", help: "Début de la journée", keywords: [] },
    { id: "f", label: "Pause when you take the headset off", help: "Resumes when you put it back", keywords: ["wear", "sensor"] }
];

// --- Matching ------------------------------------------------------------------
eq("a label word is found", ids(entries, "noise"), ["a"]);
eq("case is ignored", ids(entries, "NOISE Control"), ["a"]);
eq("accents are ignored both ways", [ids(entries, "ecran"), ids(entries, "ÉCRAN"), ids(entries, "debut")], [["e"], ["e"], ["e"]]);
eq("a decomposed accent is the same letter", ids(entries, "écran"), ["e"]);
// "headset" in a label outranks "headphones" in a help text
eq("a word prefix is enough", ids(entries, "head"), ["f", "a"]);
eq("a prefix is not found in the middle of a word", ids(entries, "phones"), []);
eq("a keyword finds the setting (sound finds the tick)", ids(entries, "sound"), ["c", "d"]);
eq("a synonym finds the wired setting (cable)", first(entries, "cable"), "b");
eq("the help text is searched", ids(entries, "python3"), ["a"]);
eq("every word must match (AND)", [ids(entries, "volume tick"), ids(entries, "volume headset")], [["c"], []]);
eq("the words may come in any order", ids(entries, "tick volume"), ["c"]);

// --- Typos ---------------------------------------------------------------------
eq("a letter too many is forgiven from 5 letters", ids(entries, "noisee"), ["a"]);
eq("a letter missing is forgiven", ids(entries, "headphons"), ["a"]);
eq("a wrong letter is forgiven", ids(entries, "volune"), ["c"]);
eq("a swap of neighbours is one edit", ids(entries, "cotnrol"), ["a"]);
eq("a last letter doubled", ids(entries, "controll"), ["a"]);
eq("a swap inside a word", ids(entries, "nosie"), ["a"]);
eq("a short word is not forgiven (4 letters)", ids(entries, "tikc"), []);
eq("two edits are too many", ids(entries, "volxxe"), []);
eq("a typo in a word still being typed", ids(entries, "headphonx"), ["a"]);

// --- Ranking -------------------------------------------------------------------
eq("the label beats a keyword, which beats the help", first(
    [{ id: "help", label: "Other", help: "the tick here", keywords: [] },
     { id: "kw", label: "Other", help: "", keywords: ["tick"] },
     { id: "label", label: "Tick", help: "", keywords: [] }], "tick"), "label");
eq("an exact word beats a prefix", first(
    [{ id: "p", label: "Stars density", help: "", keywords: [] }, { id: "x", label: "Star", help: "", keywords: [] }], "star"), "x");
eq("equal scores keep the order of the page", ids([1, 2, 3].map(n => ({ id: "n" + n, label: "Same", help: "", keywords: [] })), "same"), ["n1", "n2", "n3"]);

// --- Highlighting --------------------------------------------------------------
eq("the label range covers the word", S.search(entries, "delay")[0].label, [[6, 11]]);
eq("a prefix covers only what was typed", S.search(entries, "wir")[0].label, [[0, 3]]);
eq("a word found in the help is marked there", S.search(entries, "python3")[0].help, [[28, 35]]);
eq("a keyword hit marks nothing", S.search(entries, "cable")[0].label, []);
eq("ranges are offsets in the original text, accents included", S.search(entries, "accueil")[0].label, [[8, 15]]);
eq("overlapping ranges merge", S.search([{ id: "m", label: "abc", help: "", keywords: [] }], "ab abc")[0].label, [[0, 3]]);
eq("a typo marks the whole word", S.search(entries, "volune")[0].label, [[0, 6]]);

// --- Limits and bad input ------------------------------------------------------
eq("an empty query finds nothing", [ids(entries, ""), ids(entries, "   "), ids(entries, "!!! ??")], [[], [], []]);
eq("what is not a text finds nothing", [ids(entries, undefined), ids(entries, null), ids(entries, 5), ids(entries, {})], [[], [], [], []]);
eq("no match is an empty list", ids(entries, "zzzzzz"), []);
const many = Array.from({ length: 50 }, (_, n) => ({ id: "m" + n, label: "Same " + n, help: "", keywords: [] }));
eq("at most 20 results", ids(many, "same").length, 20);
eq("the query is cut at 64 characters", ids(entries, "noise " + "x".repeat(200)), []);
eq("the cut keeps the first words", ids(entries, "noise control" + " ".repeat(60) + "zzzz"), ["a"]);
eq("regular expression characters are plain text", [ids(entries, ".*"), ids(entries, "(noise"), ids(entries, "[a-z]+"), ids(entries, "\\")], [[], ["a"], [], []]);
eq("broken entries are skipped", ids([null, { id: 1, label: "x" }, { id: "ok", label: "Fine" }, { label: "no id" }, 7], "fine"), ["ok"]);
eq("an entry without help or keywords works", ids([{ id: "x", label: "Lonely" }], "lonely"), ["x"]);
eq("not a list is nothing", [ids(null, "a"), ids({}, "a"), ids("abc", "a")], [[], [], []]);
eq("prepared entries give the same answer", S.search(S.prepare(entries), "sound"), S.search(entries, "sound"));
eq("entries are not changed", JSON.stringify(entries).length, JSON.stringify(entries.map(e => Object.assign({}, e))).length);

// --- The real index ------------------------------------------------------------
eq("the real index finds the ticks with 'sound'", ids(Index.ENTRIES, "sound").includes("volumeTick"), true);
eq("the real index finds the wired delay with 'cable'", ids(Index.ENTRIES, "cable").includes("togetherFineDelay"), true);
eq("the real index finds the noise control with 'anc'", first(Index.ENTRIES, "anc"), "ancEnabled");
eq("the real index forgives a typo", first(Index.ENTRIES, "vizualizer"), "scopeStyle");

// --- The index follows the real tabs -------------------------------------------
function read(path) {
    const [, bytes] = GLib.file_get_contents(root + "/" + path);
    return new TextDecoder().decode(bytes);
}
// The QML files of the settings page: tabs and their rows
function qmlFiles(path) {
    const d = GLib.Dir.open(path, 0);
    const names = [];
    let n;
    while ((n = d.read_name()) !== null)
        if (n.endsWith(".qml"))
            names.push(n);
    return names.sort();
}
const tabOf = file => { const m = /^(\w+)Tab\.qml$/.exec(file); return m ? m[1].toLowerCase() : null; };
const inIndex = new Map(Index.ENTRIES.map(e => [e.id, e]));

eq("every index id is unique", inIndex.size, Index.ENTRIES.length);
const used = new Set(["volumeKeys", "report"]);
for (const name of qmlFiles(root + "/components/settings")) {
    const src = read("components/settings/" + name);
    const keys = [...src.matchAll(/settingKey: "(\w+)"\s*\n/g)].map(m => m[1]).concat([...src.matchAll(/saveValue\("(\w+)"/g)].map(m => m[1]));
    for (const k of keys) {
        used.add(k);
        eq(name + " " + k + " is in the index", inIndex.has(k), true);
        if (tabOf(name))
            eq(name + " " + k + " is filed under its tab", inIndex.get(k) && inIndex.get(k).category, tabOf(name));
    }
}
eq("the facts of the sound tab are all there", Audiophile.INFOS.every(i => inIndex.has("factCard_" + i.key) && inIndex.has("factMore_" + i.key)), true);
eq("the sound tab still builds the fact keys the index lists", /"factCard_" \+/.test(read("components/settings/SoundTab.qml")) && /"factMore_" \+/.test(read("components/settings/SoundTab.qml")), true);
for (const i of Audiophile.INFOS) { used.add("factCard_" + i.key); used.add("factMore_" + i.key); }
eq("the index lists nothing the tabs no longer have", Index.ENTRIES.map(e => e.id).filter(id => !used.has(id)), []);
eq("the keyless rows exist in the tabs", [/VolumeKeysRow \{/.test(read("components/settings/SoundTab.qml")), /ReportRow \{/.test(read("components/settings/OrbitTab.qml"))], [true, true]);
eq("every entry has a label, a help line and keywords", Index.ENTRIES.filter(e => !e.label || !e.help || !e.keywords.length).map(e => e.id), []);

// --- Speed ---------------------------------------------------------------------
const prepared = S.prepare(Index.ENTRIES);
const t0 = GLib.get_monotonic_time();
for (let i = 0; i < 100; i++)
    S.search(prepared, "volume tick sound");
const per = (GLib.get_monotonic_time() - t0) / 100 / 1000;
eq("a search over the whole index takes under 1 ms (" + per.toFixed(3) + " ms)", per < 1, true);

done();
