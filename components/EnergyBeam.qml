import QtQuick
import qs.Common

// A charging beam along the item's width (see shaders/beam.frag): faint
// magnetic field lines fanning out between both ends, pulses flowing along. The wave phase is
// animated on the render thread, only while `running` and visible.
ShaderEffect {
    id: beam
    readonly property NightColors night: NightColors {}

    property bool running: true
    property real amplitude: 3
    property real wavelength: 38
    property real phase: 0
    property color color: beam.night.primary
    readonly property real lengthPx: width
    readonly property real heightPx: height

    fragmentShader: Qt.resolvedUrl("../shaders/beam.frag.qsb")

    UniformAnimator {
        target: beam
        uniform: "phase"
        from: 0
        to: 6.28318530718
        duration: 4000
        loops: Animation.Infinite
        running: beam.running && beam.visible && beam.width > 1
    }
}
