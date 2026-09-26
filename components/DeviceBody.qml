import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "DeviceCatalog.js" as Catalog
import "Charge.js" as Charge
import "Endurance.js" as Endurance

// One orbiting device. Purely presentational + input: the owning OrbitScene
// integrates physics for every body in a single pass per frame and writes
// px/py/vx/vy directly, so there is no per-body timer or animation driver.
Item {
    id: body

    required property var scene
    required property string address
    required property bool leaving

    readonly property var device: scene.deviceMap[address] ?? null
    readonly property string name: Catalog.deviceName(device) || address
    readonly property string kind: Catalog.resolve(device, scene.prefs.glyphOverrides)
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
    readonly property real ratedHours: Endurance.ratedHours(name, kind, ancMode)
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
    readonly property real baseScale: focused ? 1 : (slotMix * depthScale + (1 - slotMix) * (0.66 + 0.34 * signal)) * connectedMix
    readonly property bool hovered: mouse.containsMouse && !scene.focusBody && !scene.hiddenOpen

    width: diameter
    height: diameter
    x: px - width / 2 + shakeX
    y: py - height / 2
    // Bodies on the far side of the ring pass behind the host core (z 50)
    z: focused ? 20000 : dragging ? 10000 : inSlot && depth < 0 ? 10 + py * 0.01 : 100 + py
    opacity: leaving ? 0 : (spawned ? 1 : 0) * ((scene.focusBody && scene.focusBody !== body) || scene.hiddenOpen ? 0.1 : 1) * (inSlot ? 1 : dormant ? 0.5 : 0.6 + 0.4 * signal)

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
        lockAnim.restart();
    }
    function release() {
        releaseAnim.restart();
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
    Item {
        id: tetherRoot
        parent: body.scene.tetherLayer
        visible: opacity > 0.01
        x: body.scene.cx
        y: body.scene.cy
        rotation: Math.atan2(body.py - body.scene.cy, body.px - body.scene.cx) * 180 / Math.PI
        opacity: body.leaving || body.focused || body.swallowing ? 0 : tetherAlpha * (body.scene.focusBody || body.scene.hiddenOpen ? 0.15 : 1)

        readonly property real dist: Math.hypot(body.px - body.scene.cx, body.py - body.scene.cy)
        readonly property real tetherAlpha: {
            if (body.dragging && body.holding)
                return body.armed ? 0.25 : 0.7;
            if (body.phase === "connecting")
                return 0.35 + 0.35 * Math.abs(Math.sin(body.scene.clock * 4));
            if (body.connected)
                return body.charging ? 0 : 0.4;   // the energy beam replaces it
            return 0;
        }
        property real reach: 1   // animated to retract / extend
        property real thickness: 1.5

        Behavior on opacity {
            NumberAnimation {
                duration: 260
            }
        }

        Rectangle {
            x: body.scene.coreSize / 2
            y: -height / 2
            height: tetherRoot.thickness * (body.dragging && body.holding ? Math.max(0.4, 1.4 - (tetherRoot.dist / (body.scene.rx * body.scene.innerNorm) - 1) * 1.2) : 1)
            width: Math.max(0, (tetherRoot.dist - body.scene.coreSize / 2 - body.diameter * body.baseScale / 2) * tetherRoot.reach)
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: body.armed && body.holding ? Theme.withAlpha(Theme.error, 0.9) : Theme.withAlpha(Theme.primary, 0.9)
                }
                GradientStop {
                    position: 1
                    color: body.armed && body.holding ? Theme.withAlpha(Theme.error, 0.15) : Theme.withAlpha(Theme.primary, 0.2)
                }
            }
        }
    }

    // --- Charging: an energy beam from the host to the device --------------
    // A softly waving beam (EnergyBeam) with a flare where it leaves the host.
    // Its animation runs on the render thread, only while someone is looking.
    Item {
        id: chargeFlow
        // Above the host's halo, below every device
        parent: body.scene.world
        z: 60
        x: body.scene.cx
        y: body.scene.cy
        rotation: tetherRoot.rotation
        opacity: body.charging && !body.leaving && !body.focused ? (body.scene.focusBody ? 0.15 : 1) : 0
        visible: opacity > 0.01

        readonly property real start: body.scene.coreSize / 2
        readonly property real span: Math.max(0, tetherRoot.dist - start - body.diameter * body.baseScale / 2)
        readonly property bool running: visible && body.scene.awake && body.scene.motion
        readonly property color glow: Theme.primary

        Behavior on opacity {
            NumberAnimation {
                duration: 500
            }
        }

        // The beam itself: waving light strands with pulses flowing toward
        // the device (shaders/beam.frag), animated only while visible
        EnergyBeam {
            x: chargeFlow.start
            y: -height / 2
            width: chargeFlow.span
            height: 44
            amplitude: 2
            wavelength: 38
            running: chargeFlow.running
        }

        // Source flare where the beam leaves the host
        Rectangle {
            x: chargeFlow.start - width / 2
            y: -height / 2
            width: 12
            height: width
            radius: width / 2
            color: Theme.withAlpha(chargeFlow.glow, 0.35)
            Rectangle {
                anchors.centerIn: parent
                width: 4
                height: 4
                radius: 2
                color: "white"
            }
        }
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

        // Halo for connected devices
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.55
            height: width
            radius: width / 2
            color: Theme.withAlpha(Theme.primary, 0.07)
            opacity: body.connected && !body.focused ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }
        }

        // Soft glow behind the glyph while it floats above the focus card
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.9
            height: width
            radius: width / 2
            color: Theme.withAlpha(Theme.primary, 0.05)
            opacity: body.focused ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }
        }

        Rectangle {
            id: disc
            anchors.fill: parent
            radius: width / 2
            opacity: body.focused ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: 260
                }
            }
            color: body.connected ? Qt.tint(Qt.rgba(0.06, 0.07, 0.09, 0.92), Theme.withAlpha(Theme.primary, 0.16)) : Qt.rgba(1, 1, 1, body.dormant ? 0.035 : 0.07)
            border.width: 1
            border.color: body.armed && body.holding ? Theme.withAlpha(Theme.error, 0.8) : body.armed ? Theme.withAlpha(Theme.primary, 0.9) : body.connected ? Theme.withAlpha(Theme.primary, 0.55) : Qt.rgba(1, 1, 1, body.dormant ? 0.08 : 0.14)

            Behavior on color {
                ColorAnimation {
                    duration: 350
                }
            }
        }

        DeviceGlyph {
            anchors.centerIn: parent
            width: parent.width * 0.52
            height: width
            kind: body.kind
            imageSource: body.scene.prefs.imageFor(body.device)
            color: body.focused ? "#F2F5EE" : body.connected ? Qt.lighter(Theme.primary, 1.12) : Qt.rgba(1, 1, 1, 0.86)
            stroke: body.focused ? 1.05 : 1.5
            Behavior on color {
                ColorAnimation {
                    duration: 300
                }
            }
        }

        // Noise-control halo: solid = cancelling, dashed = ambient,
        // double = adaptive; nothing when off or unknown. Static art, it only
        // fades when the mode changes.
        Shape {
            id: ancHalo
            anchors.centerIn: parent
            width: parent.width + 17
            height: width
            opacity: body.ancMode && body.ancMode !== "off" && !body.focused ? 1 : 0
            visible: opacity > 0
            preferredRendererType: Shape.CurveRenderer
            readonly property real r: width / 2 - 1.5
            Behavior on opacity {
                enabled: body.scene.motion
                NumberAnimation {
                    duration: 260
                }
            }

            ShapePath {
                strokeColor: Theme.withAlpha(Theme.primary, body.ancMode === "nc" ? 0.75 : 0.6)
                strokeWidth: 1.5
                strokeStyle: body.ancMode === "ambient" ? ShapePath.DashLine : ShapePath.SolidLine
                dashPattern: [1.5, 3]
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ancHalo.width / 2
                    centerY: centerX
                    radiusX: ancHalo.r
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 359.9
                }
            }
            ShapePath {
                strokeColor: body.ancMode === "adaptive" ? Theme.withAlpha(Theme.primary, 0.35) : "transparent"
                strokeWidth: 1
                fillColor: "transparent"
                PathAngleArc {
                    centerX: ancHalo.width / 2
                    centerY: centerX
                    radiusX: ancHalo.r + 3.5
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 359.9
                }
            }
        }

        // Battery arc (connected devices that report a level)
        Shape {
            anchors.centerIn: parent
            width: parent.width + 7
            height: width
            visible: body.connected && body.battery >= 0 && !body.focused
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.rgba(1, 1, 1, 0.08)
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: (body.diameter + 7) / 2
                    centerY: centerX
                    radiusX: centerX - 1
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 359.9
                }
            }
            ShapePath {
                strokeColor: body.battery <= 15 ? Theme.error : Theme.primary
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: (body.diameter + 7) / 2
                    centerY: centerX
                    radiusX: centerX - 1
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0.02, body.battery / 100)
                }
            }
        }

        // Charging: the level arc breathes (render-thread animator)
        Shape {
            id: chargeGlow
            anchors.centerIn: parent
            width: parent.width + 7
            height: width
            visible: body.charging && !body.focused
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.withAlpha(Theme.primary, 0.55)
                strokeWidth: 5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: (body.diameter + 7) / 2
                    centerY: centerX
                    radiusX: centerX - 1
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0.02, body.battery / 100)
                }
            }

            SequentialAnimation on opacity {
                running: chargeGlow.visible && body.scene.awake && body.scene.motion
                loops: Animation.Infinite
                OpacityAnimator {
                    from: 0.15
                    to: 1
                    duration: 900
                    easing.type: Easing.InOutSine
                }
                OpacityAnimator {
                    from: 1
                    to: 0.15
                    duration: 900
                    easing.type: Easing.InOutSine
                }
            }
        }

        // Charging badge
        Rectangle {
            width: Math.round(body.diameter * 0.34)
            height: width
            radius: width / 2
            x: parent.width * 0.86 - width / 2
            y: parent.height * 0.86 - height / 2
            color: Theme.primary
            border.width: 2
            border.color: Qt.rgba(0.04, 0.045, 0.06, 1)
            visible: body.charging && !body.focused

            DankIcon {
                anchors.centerIn: parent
                name: "bolt"
                size: parent.width * 0.78
                color: Theme.primaryText ?? "black"
            }
        }

        // Connecting: a comet circles the device. Its tapered tail is static
        // geometry (rebuilt only on resize); two render-thread animators turn
        // it: a steady orbit plus a slow sway, so it speeds up and eases off
        // like a breath. Nothing runs outside a connection attempt.
        Item {
            id: comet
            anchors.centerIn: parent
            width: parent.width + 14
            height: width
            visible: body.phase === "connecting"
            readonly property real r: width / 2 - 2.5
            readonly property real span: 200 * Math.PI / 180   // tail length, radians

            RotationAnimator on rotation {
                running: comet.visible
                from: 0
                to: 360
                duration: 1500
                loops: Animation.Infinite
            }

            Item {
                id: sway
                anchors.fill: parent

                SequentialAnimation {
                    running: comet.visible && body.scene.motion
                    loops: Animation.Infinite
                    RotationAnimator {
                        target: sway
                        from: -22
                        to: 22
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                    RotationAnimator {
                        target: sway
                        from: 22
                        to: -22
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                }

                // Tail: a crescent that thins to nothing, brightest at the head
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        fillGradient: ConicalGradient {
                            centerX: comet.width / 2
                            centerY: comet.height / 2
                            angle: 0
                            GradientStop {
                                position: 0
                                color: Theme.withAlpha(Theme.primary, 0.95)
                            }
                            GradientStop {
                                position: 0.3
                                color: Theme.withAlpha(Theme.primary, 0.4)
                            }
                            GradientStop {
                                position: 0.56
                                color: Theme.withAlpha(Theme.primary, 0)
                            }
                            GradientStop {
                                position: 1
                                color: Theme.withAlpha(Theme.primary, 0)
                            }
                        }
                        PathPolyline {
                            path: {
                                const c = comet.width / 2, r = comet.r, n = 28;
                                const outer = [], inner = [];
                                for (let i = 0; i <= n; i++) {
                                    const t = i / n;
                                    const a = -t * comet.span;           // behind the head
                                    const w = 2.6 * Math.pow(1 - t, 1.3) + 0.05;
                                    outer.push(Qt.point(c + Math.cos(a) * (r + w / 2), c + Math.sin(a) * (r + w / 2)));
                                    inner.push(Qt.point(c + Math.cos(a) * (r - w / 2), c + Math.sin(a) * (r - w / 2)));
                                }
                                return outer.concat(inner.reverse());
                            }
                        }
                    }
                }

                // Head: a bright core in a soft glow
                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    x: comet.width / 2 + comet.r - width / 2
                    y: comet.height / 2 - height / 2
                    color: Theme.withAlpha(Theme.primary, 0.28)
                }
                Rectangle {
                    width: 4.2
                    height: 4.2
                    radius: 2.1
                    x: comet.width / 2 + comet.r - width / 2
                    y: comet.height / 2 - height / 2
                    color: Qt.lighter(Theme.primary, 1.6)
                }
            }
        }

        // Lock ring: collapses onto the disc when a connection lands
        Rectangle {
            id: lockRing
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: Theme.primary
            opacity: 0
        }
    }

    ParallelAnimation {
        id: lockAnim
        NumberAnimation {
            target: lockRing
            property: "scale"
            from: 1.9
            to: 1
            duration: 520
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation {
                target: lockRing
                property: "opacity"
                from: 0
                to: 0.9
                duration: 180
            }
            NumberAnimation {
                target: lockRing
                property: "opacity"
                to: 0
                duration: 520
                easing.type: Easing.InQuad
            }
        }
        SequentialAnimation {
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
    }

    ParallelAnimation {
        id: releaseAnim
        NumberAnimation {
            target: lockRing
            property: "scale"
            from: 1
            to: 2
            duration: 560
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: lockRing
            property: "opacity"
            from: 0.8
            to: 0
            duration: 560
            easing.type: Easing.OutQuad
        }
    }

    // Name + connection timer. Orbiting bodies in the upper half put their
    // label above so it never collides with the host core.
    Column {
        readonly property bool above: body.inSlot && body.py < body.scene.cy
        readonly property real gap: body.diameter * body.baseScale / 2 + 5
        y: above ? body.height / 2 - gap - height : body.height / 2 + gap
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1
        visible: body.scene.prefs.showLabels || body.hovered || body.dragging
        opacity: body.scene.focusBody || body.scene.hiddenOpen || body.swallowing || body.hideArmed ? 0 : 1

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, body.diameter * 2.1)
            horizontalAlignment: Text.AlignHCenter
            text: body.name
            elide: Text.ElideRight
            color: Qt.rgba(1, 1, 1, body.connected || body.hovered ? 0.88 : 0.5)
            font.pixelSize: Math.max(9, Math.round(body.diameter * 0.2))
            font.weight: body.connected ? Font.Medium : Font.Normal
        }

        // Time left under the name: a bolt and the time to full while
        // charging, an hourglass and the time to empty on battery (the
        // level itself is the arc around the device). Replaces the
        // connection timer, which stays in the detail card.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            readonly property real minutes: body.charging ? (body.charge?.minutesToFull ?? 0) : body.minutesLeft
            visible: minutes > 0

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: body.charging ? "bolt" : "hourglass_bottom"
                size: timeText.font.pixelSize + 1
                color: Theme.withAlpha(Theme.primary, 0.8)
            }
            StyledText {
                id: timeText
                anchors.verticalCenter: parent.verticalCenter
                text: Charge.formatShort(parent.minutes)
                color: Theme.withAlpha(Theme.primary, 0.8)
                font.pixelSize: Math.max(8, Math.round(body.diameter * 0.18))
                font.weight: Font.Medium
                font.features: {
                    "tnum": 1
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !body.charging && !(body.minutesLeft > 0) && body.connected && body.scene.sinceFor(body.address) > 0 && !(body.charge?.minutesToFull > 0)
            text: Catalog.formatDuration(body.scene.now - body.scene.sinceFor(body.address))
            color: Theme.withAlpha(Theme.primary, 0.75)
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(body.diameter * 0.17))
        }
    }

    // Quick disconnect
    Rectangle {
        width: Math.round(body.diameter * 0.36)
        height: width
        radius: width / 2
        x: body.width * (0.5 + 0.36 * body.baseScale) - width / 2
        y: body.height * (0.5 - 0.36 * body.baseScale) - height / 2
        z: 2
        color: closeArea.containsMouse ? Theme.error : Qt.rgba(0.1, 0.1, 0.12, 0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        opacity: body.connected && (body.hovered || closeArea.containsMouse) && !body.dragging ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: parent.width * 0.7
            color: closeArea.containsMouse ? Theme.errorText ?? "white" : Qt.rgba(1, 1, 1, 0.8)
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: body.scene.startDisconnect(body)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: !body.leaving && !body.swallowing && !body.scene.focusBody && !body.scene.hiddenOpen
        cursorShape: body.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property point pressPoint
        property double pressTime: 0

        function worldPoint(m) {
            return mapToItem(body.scene.world, m.x, m.y);
        }

        onPressed: m => {
            pressPoint = worldPoint(m);
            pressTime = Date.now();
            // Right click: the device menu (connect, noise control, hide)
            if (m.button === Qt.RightButton)
                body.scene.openMenu(body, mapToItem(body.scene, m.x, m.y));
        }
        onPositionChanged: m => {
            if (!pressed || pressedButtons & Qt.RightButton)
                return;
            const p = worldPoint(m);
            if (!body.dragging && Math.hypot(p.x - pressPoint.x, p.y - pressPoint.y) > 5)
                body.scene.beginDrag(body, p);
            if (body.dragging)
                body.scene.updateDrag(p);
        }
        onReleased: m => {
            if (m.button === Qt.RightButton)
                return;
            if (body.dragging)
                body.scene.endDrag();
            else if (Date.now() - pressTime < 450)
                body.scene.focusOn(body);
        }
        onCanceled: if (body.dragging)
            body.scene.endDrag()
        onContainsMouseChanged: body.scene.wake()
    }
}
