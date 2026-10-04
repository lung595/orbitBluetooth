pragma ComponentBehavior: Bound
import QtQuick
import "Depth.js" as Depth

// Puts one part of the sky out of focus while a Listen together has the centre
// (D294): the farther from the camera, the darker and the blurrier. Sits right
// above `source` in the same parent and covers it with a blurred, darkened
// copy kept as a texture (FrozenBlur). Outside a group there is nothing: no
// copy, no effect, no cost.
//
// The blur is rendered once, at full strength, and `depth` only fades the
// copy in (opacity, a binding on the value the scene's loop already moves:
// no animation). Once the copy is fully shown the live source is switched
// off in memory (its opacity, restored afterwards): it is neither drawn nor
// re-rendered, and the scene can stop animating it (`frozen`).
Item {
    id: root
    required property Item source
    // 0 = sharp, 1 = full depth of field (the camera's progress, already eased)
    property real depth: 0
    property bool motion: true
    // A gesture that needs the live part (a device carried to the black hole
    // lights it up): the copy fades out while it is true
    property bool hold: false
    // Any change of this value retakes the copy (the source's look changed)
    property var token: null

    readonly property real shown: Depth.level(depth, motion)
    // Fades with the gesture: a short move, only when `hold` changes
    property real mix: hold ? 0 : 1
    // True while the blurred copy exists (never outside a group)
    readonly property bool copied: copy.active
    readonly property bool ready: (copy.item as FrozenBlur)?.ready ?? false
    // True while the copy hides the live source completely
    readonly property bool frozen: Depth.covered(shown, ready, mix)

    x: source.x
    y: source.y
    width: source.width
    height: source.height

    Behavior on mix {
        enabled: root.motion
        NumberAnimation {
            duration: 200
        }
    }

    // The live source stops being drawn (it still gets the clicks)
    Binding {
        target: root.source
        property: "opacity"
        value: 0
        when: root.frozen
        restoreMode: Binding.RestoreBindingOrValue
    }

    Loader {
        id: copy
        anchors.fill: parent
        active: Depth.needsCopy(root.shown)
        visible: root.source.visible
        opacity: root.shown * root.mix
        sourceComponent: FrozenBlur {
            source: root.source
            radius: Depth.blurRadius(width, height)
            dim: Depth.DIM
            token: root.token
        }
    }
}
