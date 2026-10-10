import QtQuick
import qs.Common
import "MasterVolume.js" as Master
import "../volume/Route.js" as Route
import "../volume/Steps.js" as Steps

// The general level of the listening group (D284), without any display: it
// moves every member and keeps the gaps between them. The ring and the wheel
// (CentreVolume) and `dms ipc call orbitBluetooth togetherVolume` (OrbitIpc)
// share it, so both follow the same rules. Nothing here runs by itself: it
// answers its callers and reads the levels the daemon's AudioRoute already
// tracks.
QtObject {
    id: volume

    // The daemon's TogetherSession; null until the daemon is up
    property var session: null

    readonly property var route: session ? session.route : null

    // Members share one PC level through Orbit's filters (the general level is
    // that one); without it each plays at its own level and the general
    // level scales them all by the same ratio
    readonly property bool shared: !!session && session.sharedNodes.length > 0
    readonly property var nodes: {
        if (!session || !session.active)
            return [];
        const list = shared ? [session.sharedNode] : session.members.map(a => session.memberNode(a));
        return list.filter(n => !!n && !!n.audio);
    }
    readonly property var levels: nodes.map(n => n.audio.volume)
    readonly property real level: shared ? (levels[0] ?? 0) : Master.general(levels)
    readonly property bool ready: nodes.length > 0
    readonly property bool muted: ready && nodes.every(n => n.audio.muted)

    // Sets the general level (a drag on the ring), in whole percents; a move
    // too small to change one writes nothing
    function set(value) {
        const to = Math.round(Math.max(0, Math.min(1, value)) * 100) / 100;
        if (!ready || Math.abs(to - level) < 0.005)
            return;
        route.touch("");
        // Orbit shows the level itself: DMS's own pop-up waits a moment
        SessionData.suppressOSDTemporarily();
        if (shared) {
            route.writeLevel(nodes[0], to, true);
            return;
        }
        // The members keep their gaps; the group's level is everyone's tick
        route.writeLevels(nodes, Master.scale(levels, level, to), level, to);
    }

    // One smart step of the general level (the wheel, D264)
    function step(dir) {
        if (!ready)
            return;
        route.touch("");
        if (shared) {
            SessionData.suppressOSDTemporarily();
            route.stepNode(nodes[0], dir, true);
        } else
            set(Steps.apply(level, dir, route.stepFor(dir, level)));
    }

    // The speaker on the ring: mutes the whole group, or lets it speak again,
    // without moving any level
    function toggleMute() {
        if (!ready)
            return;
        SessionData.suppressOSDTemporarily();
        const to = !muted;
        nodes.forEach(n => route.writeMuted(n, to));
    }

    // Sets the general level from `dms ipc call orbitBluetooth togetherVolume`
    // ("up" / "down" take a smart step, else a level 0..100 or a signed
    // change); returns "" or why it could not
    function setLevel(arg) {
        if (!ready)
            return "no-group";
        const a = String(arg === undefined || arg === null ? "" : arg).trim().toLowerCase();
        if (a === "up" || a === "down") {
            step(a === "up" ? 1 : -1);
            return "";
        }
        const to = Route.ipcLevel(arg, level);
        if (to < 0)
            return "bad-level";
        set(to);
        return "";
    }

    // A member's own level node (AudioRoute.ownNode)
    function ownNode(address) {
        return route ? route.ownNode(address) : null;
    }
    // Its level 0..1, or -1 when it has none
    function ownLevel(address) {
        const node = ownNode(address);
        return node ? node.audio.volume : -1;
    }
}
