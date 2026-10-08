// The scene's split by role: OrbitState, the base type of OrbitScene, holds the
// scene's own state and never reads one of its parts (the rule in its header), so
// a reader follows any state property in that one file.
// Run from the plugin root: gjs tests/structure.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { eq, done, root, GLib } = imports.lib;

function read(path) {
    const [, bytes] = GLib.file_get_contents(root + "/" + path);
    return new TextDecoder().decode(bytes);
}
// Code only: comments may name the parts to explain the rule
const code = src => src.split("\n").map(l => l.replace(/\/\/.*$/, "")).join("\n");

const scene = read("components/scene/OrbitScene.qml");
const state = code(read("components/scene/OrbitState.qml"));

eq("OrbitScene builds on OrbitState", /^OrbitState \{$/m.test(scene), true);

// Every id OrbitScene gives a part, and the aliases it publishes for them
const parts = [...scene.matchAll(/^\s+id: (\w+)$/gm)].map(m => m[1]).filter(id => id !== "scene");
const aliases = [...scene.matchAll(/property alias (\w+):/g)].map(m => m[1]);
eq("the scene names its parts", parts.length > 10, true);
for (const name of parts.concat(aliases, ["orbitRoot", "cardOpen", "detailOpen", "awake", "canStepBack", "menuOpen"]))
    eq("OrbitState does not read " + name, new RegExp("\\b" + name + "\\b").test(state), false);

// No property is declared in both files
const declared = src => [...code(src).matchAll(/property (?:alias|\w+) (\w+)/g)].map(m => m[1]);
const both = declared(scene).filter(p => declared(read("components/scene/OrbitState.qml")).includes(p));
eq("no property declared twice", both.join(","), "");

done();
