import QtQuick

// Switches DMS's own volume OSD off while `active`, so that Orbit's pop-up
// is the only one (D273): the OSD on screens without a Dank Island and the
// volume face the island opens by itself both follow DMS's "Volume" switch
// (Settings > On-screen Displays). It is forced in memory only, and Qt gives
// DMS's own value back as soon as `active` ends or this object goes with its
// owner (plugin off, uninstall): nothing is written by Orbit (value 12).
// DMS writes every setting that differs from its default each time one of
// them changes, and once when it starts, so a forced value would reach
// settings.json and stay there after an uninstall (P143). The switch is
// therefore let go for the instant of each save: DMS raises its `_selfWrite`
// flag just before it serialises, and lowers it when its file watcher has
// seen its own write, a few milliseconds later.
QtObject {
    id: off

    // DMS's SettingsData (null: nothing to do)
    required property var settings
    property bool active: false
    // DMS's "saving" flag; if a DMS update removes it, this reads false and
    // the switch simply stays on
    readonly property bool saving: settings?._selfWrite === true
    // A Binding deleted along with its owner gives nothing back (DMS's OSD
    // would stay off for good), so it is let go of first
    Component.onDestruction: active = false

    property Binding volumeOsd: Binding {
        target: off.settings
        property: "osdVolumeEnabled"
        value: false
        when: off.active && off.settings !== null && !off.saving
        restoreMode: Binding.RestoreBindingOrValue
    }
}
