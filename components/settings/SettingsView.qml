import QtQuick
import qs.Common
import "Placement.js" as Placement
import "SettingsIndex.js" as Index
import "SettingsSearch.js" as Search
import "SettingsView.js" as View

// The state of the settings page: which category is open, what is typed in
// the search field and what it matches. Pure bindings, no timer: the page
// does nothing until someone types or clicks.
QtObject {
    id: view

    readonly property var categories: Index.CATEGORIES
    property string pluginId: "orbitBluetooth"
    // Where Orbit's widget is placed in DMS's layout (read only, see Placement.js)
    readonly property var placed: Placement.where(SettingsData.barConfigs, SettingsData.controlCenterWidgets, SettingsData.desktopWidgetInstances, pluginId)
    // Opens on "Getting started" while the widget is placed nowhere, on the
    // Orbit settings otherwise. Set once: adding a widget while the page is
    // open must not move the page under the pointer.
    property string current: ""
    Component.onCompleted: current = placed.any ? "orbit" : "start"
    property string query: ""
    // A narrow page (the plugin settings of a small window): icons only
    property bool compact: false
    // The setting a search just opened, to light it. The counter moves on every
    // opening so that opening the same setting twice lights it twice.
    property string litKey: ""
    property int litCount: 0

    readonly property var _entries: View.byId(Index.ENTRIES)
    readonly property var _categoryOf: View.categoryOf(Index.ENTRIES)

    readonly property bool filtering: query.trim() !== ""
    // Searching the 70-odd entries takes well under a millisecond: nothing is kept
    readonly property var found: filtering ? View.group(Search.search(Index.ENTRIES, query), _categoryOf) : View.group([], {})
    readonly property var hits: found.ids
    readonly property var counts: found.counts
    readonly property var firsts: found.firsts
    readonly property bool hasResults: found.first !== null

    // The label and the one-line help of a setting, as the index words them
    function label(key) {
        return _entries[key].label;
    }

    function help(key) {
        return _entries[key].help;
    }

    function info(id) {
        return View.find(categories, id);
    }

    // Leaves the search and opens a category, optionally lighting one of its settings
    function open(category, key) {
        query = "";
        current = category;
        if (key) {
            litKey = key;
            litCount++;
        }
    }

    // A click on a category of the rail: while searching, it opens at the
    // best match it holds, otherwise it just opens
    function pick(category) {
        open(category, filtering ? firsts[category] : "");
    }

    // Enter in the search field: opens the best match and lights it
    function openFirst() {
        if (found.first)
            open(found.first.category, found.first.id);
    }
}
