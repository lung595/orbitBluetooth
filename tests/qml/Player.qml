import QtQuick
import Quickshell.Services.Mpris

// A media player as Quickshell exposes it, reduced to what Wear reads, with
// a count of what was asked of it
QtObject {
    property string identity: ""
    property string desktopEntry: ""
    property string dbusName: ""
    property bool canPause: true
    property bool canPlay: true
    property int playbackState: MprisPlaybackState.Playing
    readonly property bool isPlaying: playbackState === MprisPlaybackState.Playing
    property int pauses: 0
    property int plays: 0
    function pause() {
        pauses++;
        playbackState = MprisPlaybackState.Paused;
    }
    function play() {
        plays++;
        playbackState = MprisPlaybackState.Playing;
    }
}
