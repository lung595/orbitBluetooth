pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris
import "Wear.js" as Wear

// Pause on removal for one headset: reads its wearing status, and when it
// goes from worn to removed pauses the players playing on it; when it comes
// back, resumes only those it paused and that nobody touched since. Never
// starts music, never touches a player on another output. One instance per
// followed headset (WearPause); it goes with the headset, so a disconnect in
// the middle of a pause forgets it.
Item {
    id: root

    required property string address
    // The headset's wearing status byte, null until it has answered
    property var wearing: null
    // One list of names per stream playing on the headset (HeadsetStreams)
    property var apps: streams.apps
    // The players Orbit paused and has not resumed yet
    property var held: []
    // "worn" or "removed" as last decided; "" before the first reading
    property string last: ""

    HeadsetStreams {
        id: streams
        address: root.address
    }

    function _read() {
        const result = Wear.step(last, wearing);
        last = result.last;
        if (result.action === "pause")
            _pause();
        else if (result.action === "resume")
            _resume();
    }

    // Called twice with the same reading when the instance is created with
    // one already: harmless, a repeated state does nothing
    onWearingChanged: _read()
    Component.onCompleted: _read()

    function _pause() {
        const playing = Wear.pausable(Mpris.players.values, apps);
        playing.forEach(player => player.pause());
        held = playing;
    }

    // Once a held player leaves "Paused" somebody took it over: it is let go,
    // so playing then pausing it by hand is not undone when the headset comes
    // back. Only the held players are watched, so nothing exists at rest.
    Instantiator {
        model: root.held

        delegate: Connections {
            required property var modelData
            target: modelData
            // Later: the handler's own delegate goes away with the new list
            function onPlaybackStateChanged() {
                Qt.callLater(root._release);
            }
        }
    }

    function _release() {
        held = Wear.stillPaused(held, MprisPlaybackState.Paused);
    }

    function _resume() {
        const back = Wear.resumable(held, Mpris.players.values, MprisPlaybackState.Paused);
        held = [];
        back.forEach(player => player.play());
    }
}
