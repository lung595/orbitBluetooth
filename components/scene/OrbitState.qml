import QtQuick
import qs.Common
import qs.Services
import "../common"

// The scene's own state, as the base type of OrbitScene: what the host sets,
// the geometry the size gives, the clocks, the black hole's state and the
// preferences. Kept apart so OrbitScene only holds the parts and their entry
// points. Rule: nothing here reads a part of the scene (a card, the radar,
// the world, the device list...); only the size, the preferences and the
// shell services. What reads a part (cardOpen, awake, the aliases) stays in
// OrbitScene. tests/structure.test.js checks it.
Item {
    readonly property NightColors night: NightColors {}

    // --- Inputs ----------------------------------------------------------------
    property bool active: true               // visible to the user right now
    property bool autoScan: true             // start discovery when active
    property bool freezeWhenIdle: false      // desktop: stop animating when idle
    property bool covered: false             // desktop: hidden behind a window, Ambient pauses
    property bool interacting: false         // desktop: pointer is over the widget
    property bool glass: false               // desktop: frameless, fades into the wallpaper
    property bool foldVolume: false          // menus: the card's two volumes start folded into a thin line
    property bool volumeUnfolded: false      // ...until clicked; kept while the shell runs, never saved
    property real cornerRadius: 0            // rounded hosts (Control Center, popout)
    property var previewDevices: []          // fake device objects, for previews and tests
    readonly property alias prefs: prefsObj
    readonly property alias sounds: soundFx

    Prefs {
        id: prefsObj
    }
    SoundFx {
        id: soundFx
        enabled: prefsObj.sounds
        volume: prefsObj.soundVolume
    }

    // --- Geometry --------------------------------------------------------------
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real rx: Math.max(40, width / 2 - bodySize * 0.8)
    readonly property real ry: Math.max(30, height / 2 - bodySize * 1.25)
    readonly property real innerNorm: 0.56     // connected orbit
    // Perspective: a tilted circle is still an ellipse, just shifted. The
    // connected ring keeps its near (bottom) edge and its far (top) edge
    // reaches the host core's edge, so devices on the far side pass behind it
    readonly property real innerFrontRy: ry * innerNorm
    readonly property real innerBackRy: Math.min(innerFrontRy, coreSize * 0.5)
    readonly property real ringRy: (innerFrontRy + innerBackRy) / 2
    readonly property real ringCy: cy + (innerFrontRy - innerBackRy) / 2
    readonly property real outerMinNorm: 0.8  // strongest signal
    readonly property real snapNorm: 0.7      // magnet engages inside this
    readonly property real detachNorm: Math.max(0.8, innerNorm + 0.1)   // pulling a connected device past this disconnects
    readonly property real coreSize: Math.round(Math.min(width, height) * 0.17)
    readonly property real bodySize: Math.round(Math.max(34, Math.min(width, height) * 0.135))

    // --- Bodies, gestures and clocks ---------------------------------------------
    // The body that flew to the card: the detail card's device, or the radar's hero
    // when it is a Bluetooth member
    property var focusBody: null
    property var dragBody: null
    property real dragX: 0
    property real dragY: 0
    // The device the dragged one is over, when dropping would be about listening together
    property var togetherDrop: null
    property bool renaming: false
    property real clock: 0
    property real fxTime: 0
    // When the black hole last swallowed a shooting star (effects clock)
    property real holeFlashAt: -10
    property real orbitTime: 0
    property bool settled: false

    function wake() {
        settled = false;
    }

    // --- Black hole ("Hidden") -----------------------------------------------
    // It drifts in the outer belt like a device nobody paired: it takes a
    // slot there and step() moves it with the same spring as the bodies.
    property real holeX: cx
    property real holeY: cy + ry
    property bool hiddenOpen: false
    property real holeFeed: 0      // 0..1, how close the dragged device is
    property bool holeEye: false   // a device is carried to it from the group chooser
    property real holeSpin: 0      // tesseract phase (0 = the classic cube-in-cube), advanced by step()
    // address -> {x, y}: where a device reappears (spat out of the hole)
    property var spawnFrom: ({})
    readonly property int hiddenCount: Object.keys(prefs.hiddenDevices).length

    // --- Shell services ----------------------------------------------------------
    readonly property var adapter: BluetoothService.adapter
    readonly property bool btOn: BluetoothService.enabled
    readonly property bool discovering: BluetoothService.discovering
    readonly property bool motion: !prefs.reduceMotion
    // Nobody can see the screen: session locked or monitors powered off
    readonly property bool screenAsleep: SessionService.locked || IdleService.isShellLocked || IdleService.monitorsOff
    // The two volumes (the daemon's AudioRoute, D249). Not read-only: the
    // offscreen previews give a made-up one
    property var audioRoute: PluginService.pluginDaemonInstances[prefs.pluginId]?.route ?? null

    // What did not work, said under the core (OrbitNote), null when nothing
    property var note: null
    function explain(info) {
        note = info;
    }
}
