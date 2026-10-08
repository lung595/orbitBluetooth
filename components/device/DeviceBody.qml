import QtQuick
import "../card"
import "../centre"
import "../scene"
import "DeviceCatalog.js" as Catalog
import "../centre/Centre.js" as Centre
import "../centre/Perspective.js" as Perspective

// One orbiting device: its place, size and fade on the orbit, and its parts.
// What it knows about the device lives in its base type BodyState, its
// one-shot motions in BodyMotion. Purely presentational + input: the owning
// OrbitScene integrates physics for every body in a single pass per frame and
// writes px/py/vx/vy directly, so there is no per-body timer or animation driver.
BodyState {
    id: body
    readonly property NightColors night: NightColors {}
    readonly property PaperColors paper: PaperColors {}

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

    // Focus mode: the glyph flies to the card and grows (BodyMotion)
    readonly property bool focused: scene.focusBody === body
    property real focusScale: 1

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
    // front): full size in front, smaller behind, for a sense of depth. In the
    // profile view of a Listen together the size is 1 / distance, and a body
    // of the outer belt leans the same way by how far down it is.
    readonly property real profile: scene.centre.profile
    readonly property real depthScale: Perspective.size(depth, profile)
    // The desktop widget floats over the wallpaper: its devices are a
    // quarter smaller than in the panels, the host keeps its size. They
    // shrink and grow with the host's system as it revolves around a group.
    readonly property real ringScale: (slotMix * depthScale + (1 - slotMix) * (0.66 + 0.34 * signal) * Perspective.lean(depth, profile)) * connectedMix * (scene.glass ? 0.75 : 1) * scene.centre.system.k
    readonly property real baseScale: focused ? 1 : ringScale + (roleDiameter / diameter - ringScale) * roleMix
    readonly property bool hovered: mouse.containsMouse && !scene.cardOpen
    // How whole it is drawn: a copy behind the source of a group is drawn over it, so
    // it keeps only a dashed outline there (whole again when it is picked: the
    // focus card shows it big)
    readonly property real solid: focused ? 1 : Centre.solidity(role, depth, roleMix)
    // The dashed outline of a copy, for the tests
    readonly property alias outline: behind

    width: diameter
    height: diameter
    x: px - width / 2 + shakeX
    y: py - height / 2
    // Bodies on the far side of the ring pass behind the host core (z 50); in
    // the profile view everything sorts by height (Centre.bodyZ)
    z: focused ? 20000 : dragging ? 10000 : Centre.bodyZ(body, scene.centre.grouped, scene.centre.groupZ)
    opacity: leaving ? 0 : (spawned ? 1 : 0) * ((scene.cardOpen && !focused) ? 0.1 : 1) * (inSlot ? 1 : dormant ? 0.75 : 0.8 + 0.2 * signal)

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
        motion.pop();
    }
    function celebrate() {
        lockRing.lock();
        motion.pulseTether();
    }
    function release() {
        lockRing.release();
    }
    function shake() {
        motion.shake();
    }
    // Spirals into the black hole, then the scene hides it for good
    function swallow() {
        swallowing = true;
        motion.swallow();
    }

    BodyMotion {
        id: motion
        body: body
        visual: visual
        tether: tetherRoot
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
        // Slightly dimmer on the far side (as dark as it is small in the profile
        // view). Changes every frame, so it lives here and not in the body's
        // opacity (whose Behavior would restart endlessly and never finish
        // fading in)
        opacity: body.inSlot && !body.focused ? Perspective.haze(body.depth, body.profile) : 1

        BodyFace {
            body: body
        }

        // A copy behind the source (it is drawn over it): the dashed outline stands in for the disc
        Loader {
            id: behind
            anchors.fill: parent
            active: body.role === "copy"
            sourceComponent: BehindOutline {
                solid: body.solid
                ink: body.night.behindInk
            }
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

    BodyLabel {
        anchors.fill: parent
        body: body
    }

    QuickDisconnect {
        body: body
    }

    readonly property alias pointer: mouse
    BodyPointer {
        id: mouse
        body: body
    }

    // The wheel sets a group member's level (OrbitCentre)
    BodyWheel {
        body: body
    }
}
