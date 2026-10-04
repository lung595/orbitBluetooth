pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import "Invite.js" as Invite

// The invitation to listen together, while a connected audio device is
// carried: each device it could join breathes a halo, and a thread of light
// runs from the carried device to the nearest, stronger as they come closer
// and solid while the pointer is over it. Everything is placed from the
// scene's effects clock (no looping animation) and the world creates this
// only while such a device is carried, so nothing runs at rest (value 6).
Item {
    id: invite

    required property var scene
    required property var targets   // the bodies the carried device could join

    readonly property var night: scene.night
    readonly property var carried: scene.dragBody
    readonly property var over: scene.togetherDrop
    readonly property real t: scene.fxTime
    // Only while the device is still held to the ring: torn off to disconnect, or over the
    // black hole, the invitation is not what it is about
    readonly property bool showing: !!carried && !carried.armed && !carried.hideArmed
    readonly property int nearIndex: carried ? Invite.nearest(carried, targets) : -1
    readonly property var nearBody: nearIndex >= 0 ? targets[nearIndex] : null
    readonly property var thread: carried && nearBody ? Invite.thread(carried, radiusOf(carried), nearBody, radiusOf(nearBody)) : null
    readonly property bool locked: !!nearBody && over === nearBody

    function radiusOf(b) {
        return b.diameter * b.baseScale / 2;
    }

    anchors.fill: parent
    opacity: showing ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 200
        }
    }

    // A halo around each device it could join
    Repeater {
        model: invite.targets

        delegate: Rectangle {
            id: halo

            required property var modelData
            required property int index
            readonly property bool taken: invite.over === modelData
            readonly property real breath: invite.scene.motion ? Invite.breath(invite.t, index) : 0.5
            readonly property real size: invite.radiusOf(modelData) * 2 + (taken ? 14 : 10 + 6 * breath)

            x: modelData.px - size / 2
            y: modelData.py - size / 2
            width: size
            height: size
            radius: size / 2
            color: taken ? Theme.withAlpha(invite.night.primary, 0.1) : "transparent"
            border.width: taken ? 2 : 1.2
            border.color: Theme.withAlpha(invite.night.primary, taken ? 0.9 : 0.2 + 0.3 * breath)
        }
    }

    // The thread of light, toward the nearest device
    Item {
        visible: !!invite.thread
        x: invite.thread ? invite.thread.x : 0
        y: invite.thread ? invite.thread.y : 0
        rotation: invite.thread ? invite.thread.angle : 0
        transformOrigin: Item.TopLeft
        opacity: invite.thread ? Invite.strength(invite.thread.length, invite.scene.bodySize) : 0

        // Once the pointer is over it, the thread is whole
        Rectangle {
            visible: invite.locked
            y: -1
            width: invite.thread ? invite.thread.length : 0
            height: 2
            radius: 1
            color: Theme.withAlpha(invite.night.primary, 0.85)
        }

        Repeater {
            model: invite.locked ? 0 : Invite.DOTS

            delegate: Rectangle {
                required property int index
                readonly property real u: Invite.dotAt(invite.t, index, invite.scene.motion)

                x: u * (invite.thread ? invite.thread.length : 0) - 2
                y: -2
                width: 4
                height: 4
                radius: 2
                color: Theme.withAlpha(invite.night.primary, 0.9)
                opacity: Invite.dotAlpha(u)
            }
        }
    }
}
