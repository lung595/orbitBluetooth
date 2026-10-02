import QtQuick
import qs.Common

// A puff of stardust from the volume ring's moon, once per 5 % step. Each
// spark is thrown along the moon's path (the way the volume went), then
// pulled back toward the planet like a small body in its gravity:
// position = start + speed * t + gravity * t² / 2.
// One short animation per puff; nothing runs between steps.
Item {
    id: dust

    property real centerX: 0
    property real centerY: 0
    property real radius: 0
    property real angle: 0 // radians, where the moon is
    property bool motion: true

    readonly property real duration: 0.6 // seconds
    readonly property real gravity: 140 // px/s², toward the planet

    // Where and which way the last puff left
    property real fromX: 0
    property real fromY: 0
    property real heading: 0
    property real t: 1 // 0..1 through the puff

    function puff(rising) {
        if (!motion)
            return;
        fromX = centerX + Math.cos(angle) * radius;
        fromY = centerY + Math.sin(angle) * radius;
        // Angles grow clockwise on screen, the way the level grows
        heading = angle + (rising ? 1 : -1) * Math.PI / 2;
        burst.restart();
    }

    NumberAnimation {
        id: burst
        target: dust
        property: "t"
        from: 0
        to: 1
        duration: dust.duration * 1000
    }

    visible: t < 1
    Repeater {
        model: 8
        Rectangle {
            required property int index
            // A fan of slightly different directions and speeds, fixed per
            // spark so every puff has the same pleasant shape
            readonly property real spread: (index - 3.5) * 0.26
            readonly property real speed: 46 + (index * 37 % 5) * 9
            readonly property real dir: dust.heading + spread
            readonly property real s: dust.t * dust.duration
            // Unit vector from the moon to the planet's center
            readonly property real ux: (dust.centerX - dust.fromX) / Math.max(1, dust.radius)
            readonly property real uy: (dust.centerY - dust.fromY) / Math.max(1, dust.radius)
            readonly property real px: dust.fromX + Math.cos(dir) * speed * s + ux * dust.gravity * s * s / 2
            readonly property real py: dust.fromY + Math.sin(dir) * speed * s + uy * dust.gravity * s * s / 2
            readonly property real d: index % 2 ? 3 : 4
            x: px - d / 2
            y: py - d / 2
            width: d
            height: d
            radius: d / 2
            color: index % 3 ? Theme.primary : Theme.surfaceText
            opacity: (1 - dust.t) * (1 - dust.t)
        }
    }
}
