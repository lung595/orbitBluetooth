import QtQuick
import Quickshell.Services.Pipewire
import qs.Common
import qs.Widgets

// Output volume of a connected audio device (headphones, speakers). Bluetooth
// itself has no volume the shell can set; the audio server does, so this
// finds the device's PipeWire sink by its address and drives that one.
// Hidden when the device has no sink (mouse, keyboard, not connected).
// Local only: it talks to the sound server over its socket, nothing else.
Item {
    id: row
    readonly property PaperColors paper: PaperColors {}

    required property string address
    readonly property color ink: row.paper.ink

    // The sink's name carries the address with underscores
    // (bluez_output.AA_BB_CC_DD_EE_FF.1)
    readonly property string needle: address.replace(/:/g, "_").toLowerCase()
    readonly property var sink: {
        const nodes = Pipewire.nodes.values;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.isSink && !n.isStream && n.name && n.name.toLowerCase().indexOf(row.needle) >= 0)
                return n;
        }
        return null;
    }

    PwObjectTracker {
        objects: row.sink ? [row.sink] : []
    }

    readonly property bool ready: !!sink && !!sink.audio
    property real dragValue: -1
    readonly property real value: dragValue >= 0 ? dragValue : (ready ? Math.min(1, sink.audio.volume) : 0)
    readonly property bool muted: ready && sink.audio.muted

    visible: ready && needle !== ""
    height: visible ? 22 : 0

    DankIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        name: row.muted || row.value <= 0 ? "volume_off" : row.value < 0.5 ? "volume_down" : "volume_up"
        size: 17
        color: row.muted ? row.paper.fg(0.42) : Theme.primary

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.ready)
                row.sink.audio.muted = !row.muted
        }
    }
    StyledText {
        id: percent
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(row.value * 100) + "%"
        color: row.ink
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
    }
    Item {
        id: track
        anchors.left: icon.right
        anchors.right: percent.left
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        height: parent.height
        opacity: row.muted ? 0.45 : 1

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: row.paper.fg(0.1)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * row.value
            height: 4
            radius: 2
            color: Theme.primary
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * row.value - width / 2
            width: 14
            height: 14
            radius: 7
            color: row.ink
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            function valueAt(mx) {
                return Math.max(0, Math.min(1, (mx - 6) / track.width));
            }
            // Applied live: the sound server handles it cheaply and the
            // person hears the change while dragging
            function apply(mx) {
                row.dragValue = valueAt(mx);
                if (row.ready) {
                    row.sink.audio.muted = false;
                    row.sink.audio.volume = row.dragValue;
                }
            }
            onPressed: m => apply(m.x)
            onPositionChanged: m => apply(m.x)
            onReleased: row.dragValue = -1
        }
    }
}
