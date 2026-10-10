// The history file on disk: the real write command run twice in a temporary
// folder (content of the second write, modes 0700/0600, no leftover) and the
// erase command. Run: gjs tests/historyDisk.test.js
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { eq, done } = imports.lib;
const { GLib, Gio } = imports.gi;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
const [, bytes] = GLib.file_get_contents(dir + "/components/battery/BatterySessions.js");
const S = new Function(new TextDecoder().decode(bytes).replace(".pragma library", "") + "; return { writeCommand, eraseCommand };")();

const work = GLib.dir_make_tmp("orbit-history-XXXXXX");
const folder = work + "/battery", file = folder + "/history.json";

function run(argv, input) {
    const p = new Gio.Subprocess({ argv, flags: Gio.SubprocessFlags.STDIN_PIPE });
    p.init(null);
    p.communicate_utf8(input || "", null);
    return p.get_exit_status();
}
const read = path => new TextDecoder().decode(GLib.file_get_contents(path)[1]);
const mode = path => (Gio.File.new_for_path(path).query_info("unix::mode", 0, null).get_attribute_uint32("unix::mode") & 0o777).toString(8);

// The shell's own umask must not matter
GLib.setenv("HOME", work, true);
eq("first write ok", run(S.writeCommand(folder, file), '{"n":1}'), 0);
eq("first content", read(file), '{"n":1}');
eq("second write ok", run(S.writeCommand(folder, file), '{"n":2}'), 0);
eq("second content replaces the first", read(file), '{"n":2}');
eq("folder 0700", mode(folder), "700");
eq("file 0600", mode(file), "600");
eq("no temporary file left", GLib.file_test(file + ".tmp", GLib.FileTest.EXISTS), false);

GLib.file_set_contents(file + ".tmp", "half");
eq("erase ok", run(S.eraseCommand(file)), 0);
eq("erase removes the file", GLib.file_test(file, GLib.FileTest.EXISTS), false);
eq("erase removes the temporary file", GLib.file_test(file + ".tmp", GLib.FileTest.EXISTS), false);
eq("erase of nothing is fine", run(S.eraseCommand(file)), 0);

run(["rm", "-rf", "--", work]);
done();
