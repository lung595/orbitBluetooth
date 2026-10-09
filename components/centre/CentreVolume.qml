import QtQuick
import qs.Common
import "MasterVolume.js" as Master
import "../common/Guide.js" as Guide
import "../device/DeviceCatalog.js" as Catalog
import "../volume/Steps.js" as Steps

// The volumes of the listening group at the centre (D284): the general level,
// which moves every member and keeps the gaps between them, and each copy's
// own level. Nothing here runs by itself: it answers the ring and the wheel
// and reads the levels the daemon's AudioRoute already tracks.
Item {
    id: volume

    required property var scene
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
            route.writeLevel(nodes[0], to);
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
            route.stepNode(nodes[0], dir);
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

    // A member's own level node (AudioRoute.ownNode)
    function ownNode(address) {
        return route ? route.ownNode(address) : null;
    }
    // Its level 0..1, or -1 when it has none
    function ownLevel(address) {
        const node = ownNode(address);
        return node ? node.audio.volume : -1;
    }

    // The wheel over a member: the source moves the general level, a copy its
    // own, and a copy with none says why instead of staying silent (value 10)
    function turn(address, dir) {
        if (address === session.source) {
            step(dir);
            return;
        }
        const node = ownNode(address);
        if (node) {
            SessionData.suppressOSDTemporarily();
            route.touch(address);
            route.stepNode(node, dir);
        } else if (!scene.note || scene.note.anchor !== "the-volume-at-the-center")
            scene.explain(Guide.copyLevelNote(Catalog.deviceName(scene.deviceMap[address]) || session.nameOf(address)));
    }
}
