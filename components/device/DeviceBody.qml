import QtQuick
import "../card"
import "../centre"
import "../scene"
import "DeviceCatalog.js" as Catalog
import "../card/Charge.js" as Charge
import "../common/Pictures.js" as Pictures
import "../card/Endurance.js" as Endurance

// One orbiting device. Purely presentational + input: the owning OrbitScene
// integrates physics for every body in a single pass per frame and writes
// px/py/vx/vy directly, so there is no per-body timer or animation driver.
Item {
    id: body
    readonly property NightColors night: NightColors {}
    readonly property PaperColors paper: PaperColors {}

    required property var scene
    required property string address
    required property bool leaving

    readonly property var device: scene.deviceMap[address] ?? null
    readonly property string name: Catalog.deviceName(device) || address
    // Recognition only (see Catalog.modelName): never changes on rename
    readonly property string model: Catalog.modelName(device) || address
    readonly property string kind: Catalog.resolve(device, scene.prefs.glyphOverrides)
    // Real picture of the model (opt-in); the query is empty for anything
    // that must not be looked up, see Pictures.js
    readonly property string pictureQuery: scene.prefs.realPictures ? Pictures.queryFor(Catalog.modelName(device), paired || connected) : ""
    readonly property var picture: pictureQuery ? scene.pictureFor(pictureQuery) : null
    onPictureQueryChanged: scene.requestPicture(pictureQuery)
    Component.onCompleted: scene.requestPicture(pictureQuery)
    readonly property bool connected: device?.connected ?? false
    readonly property bool paired: (device?.paired || device?.bonded) ?? false
    // The headset's own battery report (noise-control helper), trusted while
    // its session is live or for ten minutes after: UPower often has no
    // charging state for headphones, and waiting for the level to rise is slow
    readonly property var ancInfo: scene.ancFor(address)
    readonly property bool ancFresh: !!ancInfo && (ancInfo.live || scene.now - (ancInfo.at || 0) < 600000)
    // The headset itself or an earbud charging (a charging case alone does
    // not make the earbuds "charging")
    readonly property bool headsetCharging: {
        const parts = ancFresh ? ancInfo.state?.battery : null;
        return !!parts && ["single", "left", "right"].some(k => parts[k]?.charging);
    }
    // Level from the headset's report when BlueZ has none (e.g. some earbuds):
    // the headphones, or the lower earbud
    readonly property int ancLevel: {
        const parts = ancFresh ? ancInfo.state?.battery : null;
        if (!parts)
            return -1;
        if (parts.single)
            return parts.single.level;
        const buds = [parts.left, parts.right].filter(p => p);
        return buds.length ? Math.min(...buds.map(p => p.level)) : -1;
    }
    readonly property var power: {
        const p = scene.powerFor(address);
        return headsetCharging ? Object.assign({}, p || {}, {
            "state": 1      // UPower's "charging"
        }) : p;
    }
    readonly property int battery: device?.batteryAvailable ? Math.round(device.battery * 100) : connected ? (power?.percentage ?? ancLevel) : -1
    // Rated life depends only on the model and mode: looked up once, not on every clock tick
    readonly property real ratedHours: Endurance.ratedHours(model, kind, ancMode)
    readonly property var charge: connected && battery >= 0 ? Charge.analyze(scene.batteryLogFor(address), battery, power, scene.now, ratedHours) : null
    // Time until empty, when discharging and known ("≈" unless the system says it)
    readonly property real minutesLeft: charge && !charging ? charge.minutesLeft : 0
    readonly property bool charging: charge?.state === "charging"
    // Noise control, when the headset speaks a known vendor protocol
    readonly property bool ancCapable: scene.ancCapable(body)
    onAncCapableChanged: Qt.callLater(scene.ancSyncViews)
    readonly property string ancMode: ancCapable ? (scene.ancFor(address)?.state?.mode ?? "") : ""
    readonly property real rawSignal: (device?.signalStrength ?? 0) > 0 ? device.signalStrength / 100 : 0
    // Only remembered devices can be out of range; discovered ones are nearby
    readonly property bool dormant: !connected && paired && rawSignal <= 0

    // "idle" | "connecting" | "disconnecting"
    property string phase: "idle"
    readonly property bool inSlot: (connected && phase !== "disconnecting") || phase === "connecting"
    // Held by the host's gravity: connected, or on its way to be
    readonly property bool holding: connected || phase === "connecting"
    property double cancelledAt: 0

    // Physics state (scene coordinates of the body center)
    property real px: 0
    property real py: 0
    property real vx: 0
    property real vy: 0
    property bool spawned: false
    property real homeHash: Catalog.hash01(address)

    // Smoothed signal so distance/size glide instead of jumping on each RSSI update
    property real signal: rawSignal > 0 ? rawSignal : (paired ? 0.12 : 0.2)
    Behavior on signal {
        NumberAnimation {
            duration: 900
            easing.type: Easing.OutCubic
        }
    }

    property bool dragging: false
    property bool armed: false          // inside the snap/detach zone while dragging
    property bool hideArmed: false      // dragged over the black hole: release hides it
    property bool swallowing: false     // falling into the black hole
    property real swallowScale: 1
    property real hideMix: hideArmed ? 0.7 : 1
    Behavior on hideMix {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    property real depth: 0              // -1 (behind) .. 1 (front), for orbiting bodies
    // Its part in a Listen together group at the centre of the scene
    // (OrbitCentre): "source", "copy" or "". roleMix (0..1) blends the disc
    // from its ring size to roleDiameter (px).
    property string role: ""
    property real roleMix: 0
    property real roleDiameter: 0
    property real popScale: 1
    property real shakeX: 0

    // Focus mode: the glyph flies to the card and grows, breaking out of its
    // frame. Driven by explicit animations (not a Behavior) so leaving focus
    // always lands back on exactly 1.
    readonly property bool focused: scene.focusBody === body
    property real focusScale: 1
    onFocusedChanged: {
        focusGrow.stop();
        focusShrink.stop();
        (focused ? focusGrow : focusShrink).restart();
    }
    SequentialAnimation {
        id: focusGrow
        PauseAnimation {
            duration: 140
        }
        NumberAnimation {
            target: body
            property: "focusScale"
            to: body.scene.focusGlyphScale
            duration: 520
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }
    NumberAnimation {
        id: focusShrink
        target: body
        property: "focusScale"
        to: 1
        duration: 340
        easing.type: Easing.OutCubic
    }
    Connections {
        target: body.scene
        enabled: body.focused
        function onFocusGlyphScaleChanged() {
            if (!focusGrow.running)
                body.focusScale = body.scene.focusGlyphScale;
        }
    }

    // Scale = orbit placement x hover x pop x focus. Only the discrete
    // transitions are smoothed; per-frame depth changes stay unanimated.
    property real slotMix: inSlot ? 1 : 0
    Behavior on slotMix {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }
    property real hoverScale: hovered || dragging ? 1.07 : 1
    Behavior on hoverScale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    // Connected devices shrink by 15%: the ring stays airy with several of them
    property real connectedMix: connected ? 0.85 : 1
    Behavior on connectedMix {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    readonly property real diameter: scene.bodySize
    // On the connected ring, depth runs from -1 (behind the host) to 1 (in
    // front): full size in front, half size behind, for a sense of depth
    readonly property real depthScale: 0.75 + 0.25 * depth
    // The desktop widget floats over the wallpaper: its devices are a
    // quarter smaller than in the panels, the host keeps its size
    readonly property real ringScale: (slotMix * depthScale + (1 - slotMix) * (0.66 + 0.34 * signal)) * connectedMix * (scene.glass ? 0.75 : 1)
    readonly property real baseScale: focused ? 1 : ringScale + (roleDiameter / diameter - ringScale) * roleMix
    readonly property bool hovered: mouse.containsMouse && !scene.focusBody && !scene.hiddenOpen

    width: diameter
    height: diameter
    x: px - width / 2 + shakeX
    y: py - height / 2
    // Bodies on the far side of the ring pass behind the host core (z 50)
    z: focused ? 20000 : dragging ? 10000 : inSlot && depth < 0 ? 10 + py * 0.01 : 100 + py
    opacity: leaving ? 0 : (spawned ? 1 : 0) * ((scene.focusBody && scene.focusBody !== body) || scene.hiddenOpen ? 0.1 : 1) * (inSlot ? 1 : dormant ? 0.75 : 0.8 + 0.2 * signal)

    Behavior on opacity {
        NumberAnimation {
            id: fadeAnim
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    onLeavingChanged: if (leaving)
        removeTimer.start()
    Timer {
        id: removeTimer
        interval: 420
        onTriggered: body.scene.finalizeRemoval(body.address)
    }

    onConnectedChanged: scene.onBodyConnectionChanged(body, connected)

    function pop() {
        popAnim.restart();
    }
    function celebrate() {
        lockRing.lock();
        tetherPulse.restart();
    }
    function release() {
        lockRing.release();
    }
    function shake() {
        shakeAnim.restart();
    }
    // Spirals into the black hole, then the scene hides it for good
    function swallow() {
        swallowing = true;
        swallowAnim.restart();
    }

    ParallelAnimation {
        id: swallowAnim
        readonly property int duration: body.scene.motion ? 560 : 200
        NumberAnimation {
            target: body
            property: "swallowScale"
            to: 0
            duration: swallowAnim.duration
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: visual
            property: "rotation"
            to: body.scene.motion ? 420 : 0
            duration: swallowAnim.duration
            easing.type: Easing.InCubic
        }
        onFinished: body.scene.finishHide(body)
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation {
            target: body
            property: "popScale"
            to: 1.14
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: body
            property: "popScale"
            to: 1
            duration: 420
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }
    }

    SequentialAnimation {
        id: shakeAnim
        loops: 1
        NumberAnimation {
            target: body
            property: "shakeX"
            to: -6
            duration: 50
        }
        NumberAnimation {
            target: body
            property: "shakeX"
            to: 5
            duration: 70
        }
        NumberAnimation {
            target: body
            property: "shakeX"
            to: -3
            duration: 70
        }
        NumberAnimation {
            target: body
            property: "shakeX"
            to: 0
            duration: 90
        }
    }

    // --- Tether to the host core (lives in the scene's tether layer) ---------
    BodyTether {
        id: tetherRoot
        body: body
    }

    // --- Charging: an energy beam from the host to the device --------------
    ChargeBeam {
        body: body
        rotation: tetherRoot.rotation
        dist: tetherRoot.dist
    }

    // --- Visual ---------------------------------------------------------------
    Item {
        id: visual
        anchors.fill: parent
        scale: body.baseScale * body.popScale * body.focusScale * body.hoverScale * body.hideMix * body.swallowScale
        // Slightly dimmer on the far side. Changes every frame, so it lives
        // here and not in the body's opacity (whose Behavior would restart
        // endlessly and never finish fading in)
        opacity: body.inSlot && !body.focused ? 0.8 + 0.2 * body.depthScale : 1

        BodyFace {
            body: body
        }

        ConnectingFx {
            body: body
        }

        LockRing {
            id: lockRing
            body: body
        }

        // A copy's own level while the pointer is on it (OrbitCentre)
        Loader {
            anchors.centerIn: parent
            active: body.role === "copy" && body.hovered
            sourceComponent: MemberLevel {
                body: body
            }
        }
    }

    // The tether thickens as a connection lands
    SequentialAnimation {
        id: tetherPulse
        NumberAnimation {
            target: tetherRoot
            property: "thickness"
            to: 3.2
            duration: 160
        }
        NumberAnimation {
            target: tetherRoot
            property: "thickness"
            to: 1.5
            duration: 600
            easing.type: Easing.OutCubic
        }
    }

    BodyLabel {
        anchors.fill: parent
        body: body
    }

    QuickDisconnect {
        body: body
    }

    BodyPointer {
        id: mouse
        body: body
    }

    // The wheel sets a group member's level (OrbitCentre)
    BodyWheel {
        body: body
    }
}
