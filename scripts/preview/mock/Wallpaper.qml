import QtQuick

// Synthetic "wallpaper" for the desktop shots (no personal imagery)
Item {
    id: wallpaper

    // Pale, busy variant: sky, clouds and bright patches under the labels
    // (the hardest case for label contrast)
    property bool bright: false

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#2F5D62"
            }
            GradientStop {
                position: 0.55
                color: "#A7C4A0"
            }
            GradientStop {
                position: 1
                color: "#E8C07D"
            }
        }
    }
    Rectangle {
        x: -120
        y: 300
        width: 700
        height: 420
        radius: 210
        color: "#5E8B5A"
        opacity: 0.55
    }
    Rectangle {
        x: 380
        y: 360
        width: 600
        height: 360
        radius: 180
        color: "#3D6B45"
        opacity: 0.5
    }

    Item {
        anchors.fill: parent
        visible: wallpaper.bright
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#DCE8F2"
                }
                GradientStop {
                    position: 0.6
                    color: "#F4EFE4"
                }
                GradientStop {
                    position: 1
                    color: "#C9D9B8"
                }
            }
        }
        Repeater {
            model: [[40, 60, 260, 90], [420, 30, 300, 110], [120, 420, 340, 120], [520, 380, 260, 150], [300, 220, 200, 70]]
            Rectangle {
                required property var modelData
                required property int index
                x: modelData[0]
                y: modelData[1]
                width: modelData[2]
                height: modelData[3]
                radius: height / 2
                color: index % 2 ? "#FFFFFF" : "#8FA7B8"
                opacity: 0.8
            }
        }
    }
}
