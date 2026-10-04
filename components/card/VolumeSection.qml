import QtQuick
import qs.Common
import "../volume"

// The device's two volumes on the card (D250), on the same screen as the
// pop-up's: a thin line that unfolds into the scope. Menus start folded so
// the card fits without scrolling.
Column {
    id: section
    required property var card
    // The card's CardVolume: the two levels and the picture of the sound
    required property var levels

    visible: levels.ready && !card.picking
    spacing: 2

    VolumeStrip {
        visible: section.card.volumeFolded
        width: parent.width
        height: implicitHeight
        levels: section.levels
        onUnfold: section.card.scene.volumeUnfolded = true
        onStepped: (part, dir) => section.levels.stepLevel(part, dir)
    }
    ScopeScreen {
        id: scopeScreen
        objectName: "cardScope" // found by the offscreen previews
        visible: !section.card.volumeFolded
        width: parent.width
        height: Math.round(width * 0.44) + noteRoom
        noteBelow: true
        overlay: section.levels
        live: section.levels.live

        FoldButton {
            scope: scopeScreen
            visible: section.card.scene.foldVolume
            onClicked: section.card.scene.volumeUnfolded = false
        }
    }

    // One gap between the volumes and what follows
    Item {
        width: 1
        height: Theme.spacingS
    }
}
