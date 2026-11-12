.pragma library

// Where Orbit's widget sits in DMS's layout, read (never written) from three
// lists of SettingsData: the bars' widget sections, the Control Center's
// tiles and the desktop widget instances. Most people who install Orbit
// expect it to replace DMS's Bluetooth and never add a widget, so the
// settings open on "Getting started" while it is placed nowhere.
// DMS names the same plugin three ways: "orbitBluetooth" in a bar section,
// "plugin_orbitBluetooth" in the Control Center, and widgetType
// "orbitBluetooth" for a desktop instance. An entry is a bare id or an object
// with `id`; one switched off (enabled: false) does not count.

// A list from SettingsData as a plain array: anything else is empty
function _list(x) {
    return x && typeof x.length === "number" && typeof x !== "string" ? Array.from(x) : [];
}

function _on(entry, id) {
    if (typeof entry === "string")
        return entry === id;
    return !!entry && entry.enabled !== false && entry.id === id;
}

// { bar, cc, desktop, any } for `pluginId`. A bar's sections are every key
// ending in "Widgets" (left, center, right today), so a new section counts too.
function where(bars, ccWidgets, desktopInstances, pluginId) {
    const bar = _list(bars).some(b => !!b && b.enabled !== false
        && Object.keys(b).some(k => /Widgets$/.test(k) && _list(b[k]).some(w => _on(w, pluginId))));
    const cc = _list(ccWidgets).some(w => _on(w, "plugin_" + pluginId));
    const desktop = _list(desktopInstances).some(w => !!w && w.enabled !== false && w.widgetType === pluginId);
    return { "bar": bar, "cc": cc, "desktop": desktop, "any": bar || cc || desktop };
}
