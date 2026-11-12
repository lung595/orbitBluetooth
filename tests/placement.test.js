// Where Orbit's widget sits in DMS's layout (components/settings/Placement.js):
// the settings open on "Getting started" while it is placed nowhere.
// Run from the plugin root: gjs tests/placement.test.js
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

function read(path) {
    const [, bytes] = GLib.file_get_contents(root + "/" + path);
    return new TextDecoder().decode(bytes);
}

const P = load("Placement.js");
const id = "orbitBluetooth";
const none = { bar: false, cc: false, desktop: false, any: false };

// DMS's defaults on a fresh install (Common/settings/SettingsSpec.js): Orbit nowhere
const bars = [{ id: "default", enabled: true, leftWidgets: ["launcherButton", "workspaceSwitcher"], centerWidgets: ["clock"], rightWidgets: ["systemTray", "controlCenterButton"] }];
const cc = [{ id: "user", enabled: true, w: 5, h: 1 }, { id: "bluetooth", enabled: true }];
eq("a fresh install has Orbit nowhere", P.where(bars, cc, [], id), none);
eq("nothing at all (no lists yet) is nowhere too", P.where(undefined, null, "x", id), none);

eq("in a bar section, as a bare id", P.where([{ rightWidgets: ["clock", id] }], [], [], id).bar, true);
eq("in a bar section, as an object", P.where([{ leftWidgets: [{ id: id, enabled: true }] }], [], [], id).bar, true);
eq("a section DMS adds later counts too", P.where([{ topWidgets: [id] }], [], [], id).bar, true);
eq("a bar widget switched off does not count", P.where([{ rightWidgets: [{ id: id, enabled: false }] }], [], [], id).any, false);
eq("on a bar that is switched off it does not count", P.where([{ enabled: false, rightWidgets: [id] }], [], [], id).any, false);
eq("on the second bar it counts", P.where([bars[0], { id: "b2", centerWidgets: [id] }], [], [], id).bar, true);

eq("in the Control Center as plugin_<id>", P.where([], [{ id: "plugin_" + id, enabled: true }], [], id), { bar: false, cc: true, desktop: false, any: true });
eq("in the Control Center as a bare id (older layouts)", P.where([], ["wifi", "plugin_" + id], [], id).cc, true);
eq("the bare id is not the Control Center's name for it", P.where([], [id], [], id).cc, false);
eq("a Control Center tile switched off does not count", P.where([], [{ id: "plugin_" + id, enabled: false }], [], id).cc, false);

eq("on the desktop by widgetType", P.where([], [], [{ id: "dw_1", widgetType: id, enabled: true, config: {} }], id).desktop, true);
eq("another desktop widget is not Orbit", P.where([], [], [{ id: "dw_2", widgetType: "activateLinux", enabled: true }], id).any, false);
eq("a desktop widget switched off does not count", P.where([], [], [{ widgetType: id, enabled: false }], id).desktop, false);
eq("a junk entry is skipped", P.where([null, { rightWidgets: [null, 3] }], [null], [null], id), none);
eq("everywhere at once", P.where([{ rightWidgets: [id] }], ["plugin_" + id], [{ widgetType: id }], id), { bar: true, cc: true, desktop: true, any: true });

// The page explains; it never changes the owner's layout
const page = read("components/settings/StartPage.qml") + read("components/settings/WidgetSketch.qml") + read("components/settings/Placement.js");
eq("Getting started only reads DMS's layout", /SettingsData\.\w+\s*(=[^=]|\()|saveSettings|createDesktopWidget|updateDesktopWidget/.test(page), false);
eq("and has no button", /Button|onClicked/.test(read("components/settings/StartPage.qml")), false);

done();
