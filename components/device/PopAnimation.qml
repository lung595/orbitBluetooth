import QtQuick

// The little pop of a body that says "here": it swells, then settles back with
// a small overshoot. A drop target that is ready to take the dragged device
// pops, and so does a device whose connection lands. One definition for the
// Bluetooth bodies and the wired members of a group; the body keeps the scale
// in its own `popScale`.
SequentialAnimation {
    id: pop

    required property Item body

    NumberAnimation {
        target: pop.body
        property: "popScale"
        to: 1.14
        duration: 110
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        target: pop.body
        property: "popScale"
        to: 1
        duration: 420
        easing.type: Easing.OutBack
        easing.overshoot: 2.2
    }
}
