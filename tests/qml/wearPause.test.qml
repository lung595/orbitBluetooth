import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "components/wear"

// Test of the pause on removal (D277), from the headset's wearing status to
// the media player: only the players fed to the headset are paused, only
// by a clear "both removed", and only those are resumed, if nobody touched
// them meanwhile; the first reading is a reference and never pauses; a
// disconnection or the option switched off forgets everything. The players
// and PipeWire streams are stand-ins; nothing talks to a headset.
// One step every 100 ms. Run with tests/qml/run.sh.
Item {
    id: h

    // The address of the headset the PipeWire stand-in has a sink for
    readonly property string addr: "02:00:00:00:10:06"

    // What AncService offers WearPause, reduced to what it reads
    QtObject {
        id: anc
        property var snapshots: ({})
        function deviceFor(address) {
            return {
                "deviceName": "WH-1000XM6"
            };
        }
        function familyFor(device) {
            return "sony";
        }
    }

    WearPause {
        id: wear
        ancService: anc
    }

    Component {
        id: playerType
        Player {}
    }
    function player(identity, entry, bus) {
        return playerType.createObject(h, {
            "identity": identity,
            "desktopEntry": entry,
            "dbusName": bus
        });
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // What the headset's session reports, with this wearing status
    function report(code) {
        anc.snapshots = {
            [h.addr]: {
                "status": "ready",
                "features": {
                    "wear": true
                },
                "state": {
                    "wearing": code
                }
            }
        };
    }
    // The applications whose sound reaches the headset, by PipeWire name
    function streams(names) {
        const sink = Pipewire.nodes.values[0];
        const streams = wear._headsets[h.addr].children[0];
        for (let i = 0; i < streams.data.length; i++)
            if (streams.data[i].node === sink)
                streams.data[i].linkGroups = names.map(name => ({
                            "source": {
                                "properties": {
                                    "application.name": name
                                }
                            },
                            "target": sink
                        }));
    }
    function status() {
        return wear.statusOf(h.addr);
    }

    property var spotify: null
    property var firefox: null
    property var mpd: null
    property var spotify2: null
    property var steps: [() => {
            h.spotify = player("Spotify", "spotify", "org.mpris.MediaPlayer2.spotify");
            h.firefox = player("Mozilla Firefox", "firefox", "org.mpris.MediaPlayer2.firefox.instance_1_42");
            h.mpd = player("mpd", "", "org.mpris.MediaPlayer2.mpd");
            h.mpd.playbackState = MprisPlaybackState.Paused;
            Mpris.players.values = [h.spotify, h.firefox, h.mpd];
            check("nothing is followed before a headset reports a sensor", [wear._addresses, status()], [[],
                {
                    "state": "waiting"
                }
            ]);
            h.report(0);
        }, () => {
            check("a headset with a sensor is followed", wear._addresses, [h.addr]);
            h.streams(["Spotify"]);
            check("the first reading says worn, and does nothing", [status(), h.spotify.pauses], [
                {
                    "state": "worn",
                    "code": 0,
                    "holding": 0
                },
                0]);
            h.report(4);
        }, () => {
            check("both removed: the player on the headset pauses", [h.spotify.pauses, h.spotify.isPlaying], [1, false]);
            check("another player is left alone", [h.firefox.pauses, h.mpd.pauses], [0, 0]);
            check("it is kept to be resumed", status(), {
                "state": "removed",
                "code": 4,
                "holding": 1
            });
            h.report(1);
        }, () => {
            check("one earbud back: nothing changes", [h.spotify.plays, status().holding, status().state], [0, 1, "unclear"]);
            h.report(0);
        }, () => {
            check("both worn: it resumes", [h.spotify.plays, h.spotify.isPlaying, status().holding], [1, true, 0]);
            check("nothing else starts", [h.firefox.plays, h.mpd.plays, h.mpd.isPlaying], [0, 0, false]);
            h.report(4);
        }, () => {
            check("removed again: paused again", h.spotify.pauses, 2);
            h.spotify.playbackState = MprisPlaybackState.Playing;
            h.report(0);
        }, () => {
            check("played by hand meanwhile: left as it is", h.spotify.plays, 1);
            h.report(4);
        }, () => {
            h.spotify2 = h.player("Spotify", "spotify", "org.mpris.MediaPlayer2.spotify");
            Mpris.players.values = [h.spotify2, h.firefox, h.mpd];
            h.report(0);
        }, () => {
            check("a new player under the same name is not the one paused", [h.spotify.plays, h.spotify2.plays], [1, 0]);
            h.streams([]);
            h.report(4);
        }, () => {
            check("nothing plays on the headset: nothing to pause", [h.spotify2.pauses, status().holding], [0, 0]);
            h.report(0);
        }, () => {
            check("and nothing to resume, nothing started", [h.spotify2.plays, h.mpd.plays], [0, 0]);
            h.firefox.canPause = false;
            h.streams(["firefox"]);
            h.report(4);
        }, () => {
            check("a player that cannot pause is not asked", [h.firefox.pauses, status().holding], [0, 0]);
            h.report(0);
        }, () => {
            h.streams(["Spotify"]);
            h.report(4);
        }, () => {
            check("paused once more", [h.spotify2.pauses, status().holding], [1, 1]);
            anc.snapshots = {};
        }, () => {
            check("the headset leaves in the middle of a pause: forgotten", [wear._addresses, wear._headsets, status().state], [[],
                {},
                "waiting"]);
            h.report(0);
        }, () => {
            check("back, its first reading is a reference: no resuming", [h.spotify2.plays, status().holding], [0, 0]);
            wear.active = false;
        }, () => {
            check("option off: nothing followed", [wear._addresses, status()], [[],
                {
                    "state": "off"
                }
            ]);
            h.report(4);
            wear.active = true;
        }, () => {
            check("option on with the headset already off: no pause", [h.spotify2.pauses, status().state], [1, "removed"]);
            h.report(0);
        }, () => {
            h.spotify2.playbackState = MprisPlaybackState.Playing;
            h.streams(["Spotify"]);
            h.report(4);
        }, () => {
            check("removed: paused and held", [h.spotify2.pauses, status().holding], [2, 1]);
            h.spotify2.playbackState = MprisPlaybackState.Playing;
        }, () => {
            check("played by hand: no longer held", status().holding, 0);
            h.spotify2.playbackState = MprisPlaybackState.Paused;
            h.report(0);
        }, () => {
            check("paused again by hand: the headset coming back does not resume it", [h.spotify2.plays, h.spotify2.isPlaying], [0, false]);
            h.spotify2.playbackState = MprisPlaybackState.Playing;
            h.streams(["Spotify"]);
            h.report(4);
        }, () => {
            check("a second headset follows: the first keeps what it holds", status().holding, 1);
            anc.snapshots = Object.assign({}, anc.snapshots, {
                "02:00:00:00:10:07": {
                    "status": "ready",
                    "features": {
                        "wear": true
                    },
                    "state": {
                        "wearing": 0
                    }
                }
            });
        }, () => {
            check("both are followed, the first was not rebuilt", [wear._addresses.length, status().holding], [2, 1]);
        }]
    property int i: 0
    // A step that throws is a failure, not a test that never ends
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            try {
                h.steps[h.i++]();
            } catch (e) {
                h.failures++;
                print("FAIL step " + h.i + " threw: " + e);
            }
            if (h.i >= h.steps.length) {
                print(h.failures ? h.failures + " failure(s)" : "all passed");
                Qt.exit(h.failures ? 1 : 0);
            }
        }
    }
}
