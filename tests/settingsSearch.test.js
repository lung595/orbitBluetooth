// The settings search (SettingsSearch.js) and the index it searches
// (SettingsIndex.js). Run from the plugin root: gjs tests/settingsSearch.test.js
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const S = load("SettingsSearch.js");
const Index = load("SettingsIndex.js");
const View = load("SettingsView.js");
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

// --- The index follows the real pages -------------------------------------------
function read(path) {
    const [, bytes] = GLib.file_get_contents(root + "/" + path);
    return new TextDecoder().decode(bytes);
}
// The QML files of the settings page: pages and their rows
function qmlFiles(path) {
    const d = GLib.Dir.open(path, 0);
    const names = [];
    let n;
    while ((n = d.read_name()) !== null)
        if (n.endsWith(".qml"))
            names.push(n);
    return names.sort();
}
const pageOf = file => { const m = /^(\w+)Page\.qml$/.exec(file); return m && m[1] !== "Category" ? m[1].toLowerCase() : null; };
const inIndex = new Map(Index.ENTRIES.map(e => [e.id, e]));

eq("every index id is unique", inIndex.size, Index.ENTRIES.length);
const used = new Set(["volumeKeys", "report"]);
for (const name of qmlFiles(root + "/components/settings")) {
    const src = read("components/settings/" + name);
    const keys = [...src.matchAll(/settingKey: "(\w+)"\s*\n/g)].map(m => m[1]).concat([...src.matchAll(/saveValue\("(\w+)"/g)].map(m => m[1]));
    for (const k of keys) {
        used.add(k);
        eq(name + " " + k + " is in the index", inIndex.has(k), true);
        if (pageOf(name))
            eq(name + " " + k + " is filed under its page", inIndex.get(k) && inIndex.get(k).category, pageOf(name));
    }
}
eq("the facts of the audio page are all there", Audiophile.INFOS.every(i => inIndex.has("factCard_" + i.key) && inIndex.has("factMore_" + i.key)), true);
eq("the audio page still builds the fact keys the index lists", /"factCard_" \+/.test(read("components/settings/AudioPage.qml")) && /"factMore_" \+/.test(read("components/settings/AudioPage.qml")), true);
for (const i of Audiophile.INFOS) { used.add("factCard_" + i.key); used.add("factMore_" + i.key); }
eq("the index lists nothing the pages no longer have", Index.ENTRIES.map(e => e.id).filter(id => !used.has(id)), []);
eq("the keyless rows exist in the pages", [/VolumeKeysRow \{/.test(read("components/settings/VolumePage.qml")), /ReportRow \{/.test(read("components/settings/ResetPage.qml"))], [true, true]);
eq("every entry has a label, a help line and keywords", Index.ENTRIES.filter(e => !e.label || !e.help || !e.keywords.length).map(e => e.id), []);
eq("every help is one short line", Index.ENTRIES.filter(e => e.help.length > 100).map(e => e.id), []);
// Label and help are worded once, in the index: a page that spells its own would drift from what a search matches
eq("pages take label and help from the index", qmlFiles(root + "/components/settings").filter(n => pageOf(n) && /^\s*(label|description): "/m.test(read("components/settings/" + n).replace(/\{[^{}]*\bvalue:[^{}]*\}/g, ""))), []);
// The rows that are not settings widgets word themselves from the index too
for (const [file, keys] of [["HabitsRow.qml", ["learnHabits", "togetherHabits"]], ["FineDelayRow.qml", ["togetherFineDelay"]]]) {
    const src = read("components/settings/" + file);
    eq(file + " reads its words from the index", Index.ENTRIES.filter(e => keys.includes(e.id) && (src.includes('"' + e.label + '"') || src.includes('"' + e.help + '"'))).map(e => e.id), []);
}
eq("byId finds an entry by its key", View.byId(Index.ENTRIES).volumeTick.label, "Volume tick");

// --- Categories and the view of a search ---------------------------------------
const cats = Index.CATEGORIES.map(c => c.id);
eq("ten categories, each with an icon, a name and a help line", [cats.length, Index.CATEGORIES.every(c => c.icon && c.name && c.help)], [10, true]);
eq("every entry sits in a known category", Index.ENTRIES.filter(e => !cats.includes(e.category)).map(e => e.id), []);
eq("every category has entries", cats.filter(c => !Index.ENTRIES.some(e => e.category === c)), []);
eq("every category has its page file", cats.filter(c => !qmlFiles(root + "/components/settings").includes(c[0].toUpperCase() + c.slice(1) + "Page.qml")), []);
eq("entries are listed in the order of the rail", Index.ENTRIES.map(e => cats.indexOf(e.category)).every((n, i, a) => i === 0 || a[i - 1] <= n), true);

const where = View.categoryOf(Index.ENTRIES);
const g = View.group(S.search(Index.ENTRIES, "tick"), where);
eq("a search groups its matches by category", [g.ids.volumeTick, g.counts.sounds >= 3, g.first.category], [true, true, "sounds"]);
eq("each category names its best match", [g.firsts.sounds, Object.keys(g.firsts).every(c => g.counts[c] > 0)], [S.search(Index.ENTRIES, "tick").find(r => where[r.id] === "sounds").id, true]);
eq("the first match is the best ranked", g.first.id, S.search(Index.ENTRIES, "tick")[0].id);
eq("no match gives empty groups", View.group(S.search(Index.ENTRIES, "zzzzqq"), where), { ids: {}, counts: {}, firsts: {}, first: null });
eq("junk results are ignored", View.group([{ id: "nope" }, null].filter(Boolean), where).first, null);
eq("a category is found by id", [View.find(Index.CATEGORIES, "popup").name, View.find(Index.CATEGORIES, "x")], ["Pop-up", null]);
eq("the old names still find their setting", [first(Index.ENTRIES, "Sounds"), first(Index.ENTRIES, "Device pictures"), ids(Index.ENTRIES, "Volume steps").includes("volumeSteps")], ["sounds", "realPictures", true]);

// --- Speed ---------------------------------------------------------------------
const prepared = S.prepare(Index.ENTRIES);
const t0 = GLib.get_monotonic_time();
for (let i = 0; i < 100; i++)
    S.search(prepared, "volume tick sound");
const per = (GLib.get_monotonic_time() - t0) / 100 / 1000;
eq("a search over the whole index takes under 1 ms (" + per.toFixed(3) + " ms)", per < 1, true);

done();
