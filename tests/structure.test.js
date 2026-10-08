// The split by role of the two big types: OrbitState (base of OrbitScene) and
// BodyState (base of DeviceBody) hold the state and never read one of the
// parts (the rule in their headers), so a reader follows any state property
// in that one file.
// Run from the plugin root: gjs tests/structure.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { eq, done, root, GLib } = imports.lib;

function read(path) {
    const [, bytes] = GLib.file_get_contents(root + "/" + path);
    return new TextDecoder().decode(bytes);
}
// Code only: comments may name the parts to explain the rule
const code = src => src.split("\n").map(l => l.replace(/\/\/.*$/, "")).join("\n");

// A base type never reads the parts its derived type names (ids, aliases and
// the extra names given), and no property is declared in both files
function split(derivedPath, basePath, extra) {
    const derived = read(derivedPath);
    const baseSrc = read(basePath);
    const base = code(baseSrc);
    const derivedName = derivedPath.replace(/^.*\/|\.qml$/g, "");
    const baseName = basePath.replace(/^.*\/|\.qml$/g, "");
    eq(derivedName + " builds on " + baseName, new RegExp("^" + baseName + " \\{$", "m").test(derived), true);
    const parts = [...derived.matchAll(/^\s+id: (\w+)$/gm)].map(m => m[1]).filter(id => id !== "scene" && id !== "body");
    const aliases = [...derived.matchAll(/property alias (\w+):/g)].map(m => m[1]);
    eq(derivedName + " names its parts", parts.length > 5, true);
    for (const name of parts.concat(aliases, extra))
        eq(baseName + " does not read " + name, new RegExp("\\b" + name + "\\b").test(base), false);
    const declared = src => [...code(src).matchAll(/property (?:alias|\w+) (\w+)/g)].map(m => m[1]);
    const both = declared(derived).filter(p => declared(baseSrc).includes(p));
    eq(derivedName + ": no property declared twice", both.join(","), "");
}

split("components/scene/OrbitScene.qml", "components/scene/OrbitState.qml", ["orbitRoot", "cardOpen", "detailOpen", "awake", "canStepBack", "menuOpen"]);
// The body's motion writes these; its state never depends on them
split("components/device/DeviceBody.qml", "components/device/BodyState.qml", ["focused", "focusScale", "popScale", "shakeX", "swallowScale", "hovered", "dragging"]);

done();
