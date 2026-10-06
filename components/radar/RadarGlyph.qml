import QtQuick
import qs.Widgets
import "../centre/WiredSign.js" as Sign
import "../device"

// The picture a card carries when its hero has no planet of its own to fly there:
// the group's (a disc) or a wired output's (a rounded square, like its planet).
// It rises out of the card's top edge at the place and size a flown planet has, with
// the same pop (a pause, then a grow that overshoots a little), and goes the way
// a planet does when the hero is a Bluetooth device (that planet flies instead).
// `key` says which hero it is: another one pops again. Brief, Reduce motion none.
Item {
    id: glyph

    required property var night
    // What the hero is drawn with: a Material symbol (`icon`) or a device glyph (`glyph`)
    required property var info
    property bool round: true
    property bool carried: false
    property string key: ""
    property bool motion: true
    property real size: 72

    // How far it has grown (0..1)
    property real grown: 0
    width: size
    height: size
    scale: grown
    visible: grown > 0.001

    function _settle() {
        grow.stop();
        shrink.stop();
        if (!motion)
            grown = carried ? 1 : 0;
        else if (carried)
            grow.restart();
        else
            shrink.restart();
    }
    onCarriedChanged: _settle()
    onKeyChanged: {
        if (carried) {
            grown = 0;
            _settle();
        }
    }
    Component.onCompleted: _settle()

    SequentialAnimation {
        id: grow
        PauseAnimation {
            duration: 140
        }
        NumberAnimation {
            target: glyph
            property: "grown"
            to: 1
            duration: 520
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }
    NumberAnimation {
        id: shrink
        target: glyph
        property: "grown"
        to: 0
        duration: 340
        easing.type: Easing.OutCubic
    }

    Rectangle {
        anchors.fill: parent
        radius: glyph.round ? width / 2 : width * Sign.CORNER
        color: glyph.night.connectedFill
        border.width: 1
        border.color: glyph.night.connectedEdge
    }
    DankIcon {
        anchors.centerIn: parent
        visible: !!glyph.info.icon
        name: glyph.info.icon ?? ""
        size: Math.round(glyph.size * 0.5)
        color: glyph.night.ink(0.9)
    }
    DeviceGlyph {
        anchors.centerIn: parent
        visible: !glyph.info.icon
        width: Math.round(glyph.size * 0.5)
        height: width
        kind: glyph.info.glyph ?? ""
        color: glyph.night.ink(0.9)
        stroke: 1.6
    }
}
