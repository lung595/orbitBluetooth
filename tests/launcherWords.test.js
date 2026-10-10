// The words that start a launcher phrase: one table, validated word by word (D424).
// Run from the plugin root: gjs tests/launcherWords.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const W = load("LauncherWords.js");

eq("defaults", W.resolve(undefined), { "disconnect": ["deco", "off", "disconnect"] });
eq("an emptied list restores the defaults", [W.resolve({ "disconnect": [] }), W.resolve({ "disconnect": [" ", ""] }), W.resolve({ "disconnect": "x" })], [W.DEFAULTS, W.DEFAULTS, W.DEFAULTS]);
eq("a meaningless word is accepted", W.check("zz", "disconnect", undefined), { "ok": true, "word": "zz" });
eq("trimmed and lowercased", W.check("  DeCo ", "disconnect", undefined), { "ok": true, "word": "deco" });
eq("two words for one action", W.setList(undefined, "disconnect", "zz, coupe").table, { "disconnect": ["zz", "coupe"] });
eq("each refusal has its code", [
    W.check("", "disconnect", {}).why, W.check("a".repeat(25), "disconnect", {}).why, W.check("a b", "disconnect", {}).why,
    W.check("30", "disconnect", {}).why, W.check("1,5", "disconnect", {}).why, W.check("MIN", "disconnect", {}).why, W.check("heures", "disconnect", {}).why
], ["empty", "long", "space", "number", "number", "unit", "unit"]);
eq("24 characters pass", W.check("a".repeat(24), "disconnect", {}).ok, true);
eq("a word used by another action is refused", [W.check("go", "disconnect", { "other": ["go"] }).why, W.check("go", "other", { "other": ["go"] }).ok], ["used", true]);
eq("the same action may keep its own word", W.check("deco", "disconnect", undefined).ok, true);
const list = W.setList(undefined, "disconnect", "zz,zz,30,min,a b,coupe");
eq("a list keeps what passes once and says why for the rest", [list.table.disconnect, list.refused], [["zz", "coupe"], [{ "word": "30", "why": "number" }, { "word": "min", "why": "unit" }, { "word": "a b", "why": "space" }]]);
const many = W.setList(undefined, "disconnect", "a,b,c,d,e,f,g,x,i,j");
eq("at most 8 words", [many.table.disconnect.length, many.refused], [8, [{ "word": "i", "why": "full" }, { "word": "j", "why": "full" }]]);
eq("an empty csv gives the defaults back", W.setList({ "disconnect": ["zz"] }, "disconnect", "").table, W.DEFAULTS);
eq("an unknown action is refused", W.setList(undefined, "nope", "zz").ok, false);
eq("not a text", W.setList(undefined, "disconnect", null).table, W.DEFAULTS);
done();
