// Shared by every tests/*.test.js: loads the pure modules of components/<feature>/*.js
// and counts the checks. Each test file ends with done().
var GLib = imports.gi.GLib;

var root = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/run.test.js", GLib.get_current_dir())));

// The modules live in feature folders: components/<feature>/<Name>.js
const features = ["card", "centre", "common", "device", "noise", "pairing", "radar", "radio", "scene", "together", "volume", "wear"];
function pathOf(file) {
    const folder = features.find(f => GLib.file_test(root + "/components/" + f + "/" + file, GLib.FileTest.EXISTS));
    return root + "/components/" + folder + "/" + file;
}

// QML ".pragma library" files are plain JS once the pragma is removed. One
// that imports another (`.import "x/Name.js" as Name`) gets it as a constant
// holding every function and top-level `var` the other declares.
function load(file, names) {
    const [, bytes] = GLib.file_get_contents(pathOf(file));
    const src = new TextDecoder().decode(bytes)
        .replace(".pragma library", "")
        .replace(/^\.import "(?:[^"]*\/)?([^"\/]+\.js)" as (\w+)$/gm, (_, dep, name) => "const " + name + " = load(" + JSON.stringify(dep) + ");");
    const declared = [...src.matchAll(/^(?:function|var) (\w+)/gm)].map(m => m[1]);
    return new Function("load", src + "; return { " + (names || declared).join(", ") + " };")(load);
}

let count = 0, failures = 0;
function eq(what, got, expected) {
    count++;
    if (JSON.stringify(got) !== JSON.stringify(expected)) {
        failures++;
        print("\u2717 " + what + "\n    expected: " + JSON.stringify(expected) + "\n    got:      " + JSON.stringify(got));
    }
}

// Prints the tally and ends with a non-zero status if a check failed
function done() {
    print(failures ? failures + "/" + count + " failed" : count + " tests passed");
    imports.system.exit(failures ? 1 : 0);
}
