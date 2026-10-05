import QtQuick
import qs.Common
import "components/volume"
import "mock"

// Test of TwoLevels listening together (D254, D277): with the device among
// the outputs sharing the sound, `members` lists them in the order they
// joined (two to four) each with its own level, mute, icon and name, and
// this PC's shared level is the one the face shows; a gesture on a part
// writes through the route (the shared half reaches every copy) and keeps
// DMS's own pop-up quiet; an output that is not among them, or alone, is
// not split. Run with tests/qml/run.sh.
Item {
    id: h

    FakeRoute {
        id: route
        focusDevice: ({
                "address": "02:00:00:00:10:06",
                "name": "Headset",
                "icon": "audio-headphones"
            })
    }
    TwoLevels {
        id: levels
        route: route
        dev: route.find("02:00:00:00:10:06")
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function near(a, b) {
        return Math.abs(a - b) < 1e-9;
    }
    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"
    readonly property string three: "02:00:00:00:20:03"

    Component.onCompleted: {
        check("alone: not split, no members", [levels.split, levels.members], [false, []]);
        check("alone: the device's own level and this PC's", [levels.deviceLevel, levels.pcLevel], [0.62, 0.85]);

        route.sharing = [h.headset];
        check("one output is not listening together", levels.split, false);
        route.sharing = [h.one, h.two];
        check("the device not among the outputs: not split", [levels.split, levels.members.length], [false, 0]);

        route.sharing = [h.headset, h.one, h.two];
        check("three outputs: split, in the order they joined", [levels.split, levels.members.map(m => m.part), levels.members.map(m => m.address)], [true, ["m0", "m1", "m2"], [h.headset, h.one, h.two]]);
        check("each has its own level", levels.members.map(m => m.level), [0.62, 0.3, 0.8]);
        check("each has its own name, shown", levels.members.map(m => m.label), ["Headset", "Speaker 1", "Speaker 2"]);
        check("each has its own icon", levels.members.map(m => m.icon), ["headphones", "speaker", "speaker"]);
        check("the device has no level of its own any more; this PC's is the shared one", [levels.deviceLevel, levels.pcLevel], [-1, 0.85]);
        check("watched: this PC's and each member's audio", levels.audios.length, 4);
        check("heard as the loudest member is", near(levels.heardLevel, 0.8 * 0.85), true);

        route.sharing = [h.headset, h.one, h.two, h.three];
        check("four outputs: the muted one says so", levels.members.map(m => m.muted), [false, false, false, true]);
        check("four outputs: four parts", levels.members.map(m => m.part), ["m0", "m1", "m2", "m3"]);

        // A gesture writes through the route and keeps DMS's pop-up quiet
        const quiet = SessionData.quiet;
        levels.setLevel("m1", 0.5);
        check("a member's level is written", route.otherOne.audio.volume, 0.5);
        check("DMS's own pop-up is kept quiet", SessionData.quiet, quiet + 1);
        levels.setLevel("m2", 2);
        check("a level is kept in range", route.otherTwo.audio.volume, 1);
        levels.setLevel("pc", 0.4);
        check("this PC's shared level reaches every copy", [route.shared.audio.volume, route.copyOne.audio.volume], [0.4, 0.4]);
        levels.toggleMute("pc");
        check("muting this PC's half mutes every copy", [route.shared.audio.muted, route.copyOne.audio.muted], [true, true]);
        levels.setLevel("pc", 0.6);
        check("a level written unmutes, as a slider does", [route.shared.audio.muted, route.copyOne.audio.muted], [false, false]);
        levels.toggleMute("m3");
        check("a member's mute is its own", [route.otherThree.audio.muted, route.otherOne.audio.muted], [false, false]);
        levels.stepLevel("m1", 1);
        check("a wheel step is the route's smart step", near(route.otherOne.audio.volume, 0.55), true);
        const before = SessionData.quiet;
        levels.setLevel("m9", 0.5);
        levels.stepLevel("device", 1);
        check("a part that is not there is ignored", SessionData.quiet, before);

        // Back to the device alone
        route.sharing = [];
        check("no longer split: the device's own again", [levels.split, levels.members.length, levels.deviceLevel], [false, 0, 0.62]);
        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }
}
