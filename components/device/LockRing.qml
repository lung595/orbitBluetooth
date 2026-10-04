import QtQuick

// The ring that collapses onto a device when a connection lands, and the
// one that opens out when it lets go.
Rectangle {
    id: ring
    anchors.centerIn: parent
    width: parent.width
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 1.5
    border.color: ring.body.night.primary
    opacity: 0
    required property var body

    function lock() {
        lockAnim.restart();
    }
    function release() {
        releaseAnim.restart();
    }

    ParallelAnimation {
        id: lockAnim
        NumberAnimation {
            target: ring
            property: "scale"
            from: 1.9
            to: 1
            duration: 520
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation {
                target: ring
                property: "opacity"
                from: 0
                to: 0.9
                duration: 180
            }
            NumberAnimation {
                target: ring
                property: "opacity"
                to: 0
                duration: 520
                easing.type: Easing.InQuad
            }
        }
    }

    ParallelAnimation {
        id: releaseAnim
        NumberAnimation {
            target: ring
            property: "scale"
            from: 1
            to: 2
            duration: 560
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: ring
            property: "opacity"
            from: 0.8
            to: 0
            duration: 560
            easing.type: Easing.OutQuad
        }
    }
}
