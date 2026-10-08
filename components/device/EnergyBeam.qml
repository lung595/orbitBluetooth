import QtQuick
import qs.Common
import "../scene"

// A charging beam along the item's width (see shaders/beam.frag): faint
// magnetic field lines fanning out between both ends, pulses flowing along. The wave phase
// follows `time` (the scene's effects clock, one cycle every 4 s), and only while `running`:
// no looping QML animation, which would redraw every shell window at the display rate.
ShaderEffect {
    id: beam
    readonly property NightColors night: NightColors {}

    property bool running: true
    property real amplitude: 3
    property real wavelength: 38
    property real time: 0
    readonly property real phase: running ? (time % 4) / 4 * 6.28318530718 : 0
    // The charge colour, one for the beam, the bolt and the battery arc
    property color color: beam.night.charging
    // White-hot lines on dark backgrounds; deepened on light cards
    property real whiteCore: 1
    readonly property real lengthPx: width
    readonly property real heightPx: height

    fragmentShader: Qt.resolvedUrl("../../shaders/beam.frag.qsb")
}
