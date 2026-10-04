import QtQuick

// Switches DMS's own volume OSD off while `active`, so that Orbit's pop-up
// is the only one (D273): the OSD on screens without a Dank Island and the
// volume face the island opens by itself both follow DMS's "Volume" switch
// (Settings > On-screen Displays). It is forced in memory only, and Qt gives
// DMS's own value back as soon as `active` ends or this object goes with its
// owner (plugin off, uninstall): nothing is written by Orbit (value 12).
// The one exception, said in the README and the settings: DMS saves all of
// its settings whenever one of them changes, so a save that happens while
// this holds takes the forced value along (P143).
QtObject {
    id: off

    // DMS's SettingsData (null: nothing to do)
    required property var settings
    property bool active: false
    // A Binding deleted along with its owner gives nothing back (DMS's OSD
    // would stay off for good), so it is let go of first
    Component.onDestruction: active = false

    property Binding volumeOsd: Binding {
        target: off.settings
        property: "osdVolumeEnabled"
        value: false
        when: off.active && off.settings !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
