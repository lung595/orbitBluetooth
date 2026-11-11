import QtQuick

// Holds DMS's own volume sound quiet while Orbit's tick plays (D360): DMS's
// "Volume Changed" sound (Settings > Sounds) waits while Orbit moves a level
// and a moment after the last one, so that Orbit's tick is the only sound.
// Only with `replaceSound` (the tick is on and the user asked for it alone)
// and only around Orbit's own writes (`hold`): DMS's sliders and keys keep
// their sound where no tick plays. Forced in memory only: Qt gives DMS's own
// value back as soon as the switch ends or this object goes with its owner
// (plugin off, uninstall): nothing is written by Orbit (value 12).
// DMS writes every setting that differs from its default each time one of
// them changes, and once when it starts, so a forced value would reach
// settings.json and stay there after an uninstall (P143). The switches are
// therefore let go for the instant of each save: DMS raises its `_selfWrite`
// flag just before it serialises, and lowers it when its file watcher has
// seen its own write.
QtObject {
    id: quiet

    // DMS's SettingsData (null: nothing to do)
    required property var settings
    // Orbit's tick plays instead of DMS's volume sound: `hold` may silence it
    property bool replaceSound: false
    // How long DMS's sound waits after the last level Orbit wrote (ms): more
    // than PipeWire takes to report a level back, less than a pause
    property int soundWait: 400
    // A level of Orbit's is moving, or just moved: DMS's sound waits
    readonly property bool holding: replaceSound && wait.running
    // DMS's "I am writing settings.json" flag; if a DMS update removes it,
    // this reads false and the switch simply stays on
    readonly property bool writing: settings?._selfWrite === true
    // True for the instant of a DMS save: the switch lets go
    property bool saving: false
    // A DMS update may rename the sound's flag: then there is nothing to hold
    // (a Binding on a property that is not there would warn at every level)
    readonly property bool hasSoundFlag: settings?.soundVolumeChanged !== undefined

    // A level is about to move by Orbit's hand: DMS's sound waits, for as long
    // as the levels keep moving and `soundWait` after the last one. Called
    // before each write, since DMS may hear it at once; one timer restarted at
    // each call, stopped at rest.
    function hold() {
        if (replaceSound)
            wait.restart();
    }

    onWritingChanged: _sync()
    onHoldingChanged: _sync()
    Component.onCompleted: _sync()
    // A Binding deleted along with its owner gives nothing back (DMS's sound
    // would stay off for good), so the switch is let go of first
    Component.onDestruction: wait.stop()
    onReplaceSoundChanged: {
        if (!replaceSound)
            wait.stop();
    }

    function _sync() {
        saving = holding && writing;
        if (saving)
            releaseWindow.restart();
        else
            releaseWindow.stop();
    }

    // How long DMS's sound waits: runs only between the levels Orbit writes
    property Timer wait: Timer {
        interval: quiet.soundWait
    }

    // A save that changes nothing (the one DMS makes at start-up, or a
    // setting set to its own value) raises the flag and no file event ever
    // lowers it. The instant is therefore bounded, and the flag is lowered
    // here so that the next save shows its rising edge again.
    property Timer releaseWindow: Timer {
        interval: 250
        onTriggered: {
            if (quiet.writing)
                quiet.settings._selfWrite = false;
            quiet.saving = false;
        }
    }

    property Binding volumeSound: Binding {
        target: quiet.settings
        property: "soundVolumeChanged"
        value: false
        when: quiet.holding && quiet.hasSoundFlag && !quiet.saving
        restoreMode: Binding.RestoreBindingOrValue
    }
}
