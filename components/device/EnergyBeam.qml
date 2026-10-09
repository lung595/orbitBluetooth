import QtQuick
import qs.Common
import "../scene"

// The Filament charging beam along the item's width (see shaders/beam.frag):
// three thin strands weaving between both ends, their colour shifting from the
// host's to the device's. `amplitude` is the first strand's swing, the others
// swing 5/3 and 7/3 as much. The wave phase
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
    // From the host's colour to the charge colour (the battery arc's, the bolt's)
    property color color: beam.night.primary
    property color endColor: beam.night.charging
    // White-hot lines on dark backgrounds; deepened on light cards
    property real whiteCore: 1
    readonly property real lengthPx: width
    readonly property real heightPx: height

    fragmentShader: Qt.resolvedUrl("../../shaders/beam.frag.qsb")
}
