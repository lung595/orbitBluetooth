import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "Palette.js" as Palette

// The pairing sheet: a tall card that unfolds from the bar when new
// headphones are in pairing mode. NewDeviceWatch owns the state and the
// actions; this is the look.
//
// One scene, two skins chosen by the DMS light/dark mode. The device floats
// above the horizon of a planet whose limb is lit by the theme's accent; the
// content sits on the planet.
// - Dark, "deep space": blue-black sky, fine stars, a dark planet with a
//   glowing atmosphere, a luminous device.
// - Light, "stratosphere": pearly sky tinted by the accent, ink-dot stars
//   and a thin constellation, a porcelain planet with a coloured rim, the
//   device in deep accent with a real drop shadow, like a product on stage.
// The DMS palette only enters through the accent, which each skin moves to
// a readable contrast (Palette.js), so any palette works on either skin.
Item {
    id: root

    // "offer", "pairing", "connecting", "done" or "failed"
    property string phase: "offer"
    property string name: ""
    property string subtitle: ""
    // Shown when pairing failed, in plain words (Offer.errorText)
    property string errorText: "Could not connect. Is it still in pairing mode?"
    property string kind: "headphonesSlim"
    property url pictureSource: ""
    property string credit: ""
    property int battery: -1
    // [{icon, value, label}] from Offer.features
    property var features: []
    // Noise-control modes offered once connected, and the current one
    property var ancModes: []
    property string ancMode: ""
    // 1 -> 0 while the offer waits for an answer
    property real life: 1
    // Devices waiting behind this one
    property int stacked: 0
    property bool shown: true
    property bool reduceMotion: false
    // Follows DMS; the preview can force it
    property bool light: Theme.isLightMode

    signal accepted
    signal later
    signal ignored
    signal retry
    signal cancelled
    // "Pair anyway" after the keyboard-profile question (phase "confirm")
    signal confirmed
    signal renamed(string text)
    signal modeRequested(string mode)

    readonly property bool busy: phase === "pairing" || phase === "connecting"
    readonly property Item card: card
    // Where clicks are taken: the card's resting place. The card itself is
    // scaled while it unfolds, and a window mask built from it kept that
    // squashed size, so the bottom of the card (Connect, Don't offer again)
    // let clicks through to the window below.
    readonly property Item hitArea: hitArea
    Item {
        id: hitArea
        x: root.pad
        y: root.topGap
        width: root.cardWidth
        height: root.cardHeight
    }
    readonly property bool hovered: hover.hovered
    // Typing a new name (the window gives the sheet the keyboard meanwhile)
    property bool renaming: false
    // Leaving after a connection: the sheet folds back into the bar's corner
    property bool exitToBar: false

    // --- Motion -----------------------------------------------------------------------
    // Locked or screens off (set by the window): the loop would redraw the
    // whole shell at the screen's rate for nobody
    property bool asleep: false
    readonly property bool moving: shown && !reduceMotion && !asleep
    // Seconds since the sheet appeared: drives every loop (float, moon,
    // twinkle, sonar, shooting star) from one animation
    property real clock: 0
    NumberAnimation on clock {
        running: root.moving
        from: 0
        to: 3600
        duration: 3600000
        loops: Animation.Infinite
    }
    // 0 -> 1: the card unfolds (springy on the way in, quick on the way out)
    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.reduceMotion ? 0 : root.shown ? 700 : 300
            easing.type: root.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 1.15
        }
    }
    // 0 -> 1: the sections come in one after another
    property real intro: 0
    // 0 -> 1: the device falls out of the bar along a comet trail
    property real fall: 0
    // 0 -> 1: caught by the orbit (flash, then sonar and moon)
    property real arrived: 0
    // 0 -> 1: star burst when connected, and the battery ring filling
    property real burst: 0
    property real shownBattery: 0
    // Pointer tilt of the device, in degrees
    property real tiltX: hover.hovered && moving ? -((hover.point.position.y / cardHeight) - 0.3) * 12 : 0
    property real tiltY: hover.hovered && moving ? ((hover.point.position.x / cardWidth) - 0.5) * 18 : 0
    Behavior on tiltX {
        SmoothedAnimation {
            velocity: 30
        }
    }
    Behavior on tiltY {
        SmoothedAnimation {
            velocity: 40
        }
    }
    readonly property real floatY: arrived * 6 * Math.sin(clock * 1.6)
    readonly property real floatTurn: arrived * 1.8 * Math.sin(clock * 1.05)

    function stagger(i) {
        return Math.max(0, Math.min(1, (intro - i * 0.09) / 0.4));
    }

    SequentialAnimation {
        id: enter
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "intro"
                from: 0
                to: 1
                duration: 1300
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 260
                }
                NumberAnimation {
                    target: root
                    property: "fall"
                    from: 0
                    to: 1
                    duration: 1000
                    easing.type: Easing.OutCubic
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: flash
                        property: "scale"
                        from: 1
                        to: 2.1
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: flash
                        property: "opacity"
                        from: 0.9
                        to: 0
                        duration: 600
                    }
                    NumberAnimation {
                        target: root
                        property: "arrived"
                        from: 0
                        to: 1
                        duration: 700
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: celebrate
        NumberAnimation {
            target: root
            property: "burst"
            from: 0
            to: 1
            duration: 1100
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "shownBattery"
            from: 0
            to: Math.max(0, root.battery)
            duration: 1300
            easing.type: Easing.OutCubic
        }
    }

    function start() {
        enter.stop();
        if (reduceMotion) {
            intro = 1;
            fall = 1;
            arrived = 1;
            return;
        }
        intro = 0;
        fall = 0;
        arrived = 0;
        enter.restart();
    }
    onShownChanged: if (shown)
        start()
    Component.onCompleted: if (shown)
        start()
    onPhaseChanged: {
        if (phase === "done") {
            if (reduceMotion) {
                burst = 1;
                shownBattery = Math.max(0, battery);
            } else {
                celebrate.restart();
            }
        } else {
            burst = 0;
            shownBattery = 0;
        }
    }
    onBatteryChanged: if (phase === "done" && !celebrate.running)
        shownBattery = Math.max(0, battery)

    // Enter: connect (or retry, or done); Escape: later (or cancel)
    focus: true
    Keys.onPressed: event => {
        if (renaming)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (phase === "offer")
                accepted();
            else if (phase === "failed")
                retry();
            else if (phase === "done")
                later();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (busy)
                cancelled();
            else
                later();
            event.accepted = true;
        }
    }

    readonly property real cardWidth: 340
    readonly property real cardHeight: 520
    // Room for the shadow (kept short so the card can sit close to the screen
    // edge) and the cards peeking below
    readonly property real pad: 16
    // Gap between the card and the screen's right edge: the bar's own, so
    // both line up (the shadow simply runs off the screen there)
    property real rightGap: pad
    // Gap under the bar
    property real topGap: 6
    implicitWidth: cardWidth + pad + rightGap
    implicitHeight: cardHeight + pad + 44

    // --- Skin ------------------------------------------------------------------------
    function rgb(o) {
        return Qt.rgba(o.r, o.g, o.b, 1);
    }

    QtObject {
        id: skin
        readonly property bool light: root.light

        // A grey theme accent borrows the picture's colour when there is one
        readonly property color seed: Palette.isGrey(Theme.primary) && probe.found.a > 0 ? probe.found : Theme.primary
        readonly property color seed2: Palette.isGrey(Theme.tertiary) ? seed : Theme.tertiary
        readonly property real hue: Palette.toHsl(seed).h

        // Sky, top to horizon
        readonly property color skyTop: light ? Qt.tint("#FFFFFF", Theme.withAlpha(seed, 0.07)) : Qt.tint("#04050A", Theme.withAlpha(seed, 0.05))
        readonly property color skyLow: light ? Qt.tint("#F1F2F7", Theme.withAlpha(seed, 0.12)) : Qt.tint("#0A0C14", Theme.withAlpha(seed, 0.08))
        // Planet, limb to the bottom of the card
        readonly property color planetTop: light ? Qt.tint("#E6E8EF", Theme.withAlpha(seed, 0.1)) : Qt.tint("#0E1119", Theme.withAlpha(seed, 0.12))
        readonly property color planetLow: light ? Qt.tint("#F7F8FB", Theme.withAlpha(seed, 0.03)) : "#06070B"

        // Accents: lifted to glow on the night, deepened to read on the pearl
        readonly property color accent: light ? root.rgb(Palette.ensureContrast(seed, planetTop, 4.5)) : root.rgb(Palette.ensureContrast(Palette.lift(seed, 0.66), skyLow, 6))
        readonly property color accent2: light ? root.rgb(Palette.ensureContrast(seed2, planetTop, 3)) : root.rgb(Palette.ensureContrast(Palette.lift(seed2, 0.6), skyLow, 4))
        // The device's own colour (picture) leads the light when known
        readonly property color glow: probe.found.a > 0 ? (light ? root.rgb(Palette.ensureContrast(probe.found, planetTop, 3)) : root.rgb(Palette.ensureContrast(Palette.lift(probe.found, 0.6), skyLow, 4))) : accent
        readonly property color inkOnAccent: root.rgb(Palette.onColor(accent))
        // Light itself (aurora, atmosphere, glows): on the pearl a dark accent
        // would look like smoke, so the light is a bright, saturated pastel
        readonly property color haze: light ? root.rgb(Palette.fromHsl(Palette.toHsl(glow).h, Math.max(Palette.toHsl(glow).s, 0.55), 0.68)) : glow

        // Ink: white on the night, a deep shade of the accent's hue on the pearl
        readonly property color inkBase: light ? root.rgb(Palette.fromHsl(hue, 0.22, 0.1)) : "#FFFFFF"
        function ink(a) {
            return Theme.withAlpha(inkBase, a);
        }
        readonly property color tileFill: light ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(1, 1, 1, 0.05)
        readonly property color tileBorder: ink(light ? 0.07 : 0.08)
    }

    // Average colour of the picture's saturated pixels
    Canvas {
        id: probe
        width: 12
        height: 12
        opacity: 0
        property color found: "transparent"
        property url src: root.pictureSource
        onSrcChanged: {
            found = "transparent";
            if (src.toString() !== "")
                loadImage(src);
        }
        onImageLoaded: requestPaint()
        onPaint: {
            if (src.toString() === "" || !isImageLoaded(src))
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(src, 0, 0, width, height);
            const px = ctx.getImageData(0, 0, width, height).data;
            let r = 0, g = 0, b = 0, total = 0;
            for (let i = 0; i < px.length; i += 4) {
                const c = Qt.rgba(px[i] / 255, px[i + 1] / 255, px[i + 2] / 255, 1);
                const w = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 2) * (px[i + 3] / 255);
                r += c.r * w;
                g += c.g * w;
                b += c.b * w;
                total += w;
            }
            found = total > 4 ? Qt.rgba(r / total, g / total, b / total, 1) : "transparent";
        }
    }

    // A round light, squashed vertically when flatter than wide: the
    // gradient reaches zero exactly at the edge, so it never shows a rim
    component Light: Shape {
        property color tint
        property real strength: 0.4
        property real squash: 1
        height: width
        transform: Scale {
            origin.y: 0
            yScale: squash
        }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: width / 2
                centerY: height / 2
                centerRadius: width / 2
                focalX: centerX
                focalY: centerY
                GradientStop {
                    position: 0
                    color: Theme.withAlpha(tint, strength)
                }
                GradientStop {
                    position: 0.3
                    color: Theme.withAlpha(tint, strength * 0.62)
                }
                GradientStop {
                    position: 0.6
                    color: Theme.withAlpha(tint, strength * 0.22)
                }
                GradientStop {
                    position: 1
                    color: Theme.withAlpha(tint, 0)
                }
            }
            PathAngleArc {
                centerX: width / 2
                centerY: height / 2
                radiusX: width / 2
                radiusY: height / 2
                sweepAngle: 360
            }
        }
    }

    // --- The next devices, peeking below like a stack of cards ------------------
    Repeater {
        model: Math.min(2, root.stacked)
        Rectangle {
            id: peek
            required property int index
            readonly property real k: index + 1
            width: root.cardWidth * (1 - 0.06 * k)
            height: 40
            x: card.x + (root.cardWidth - width) / 2
            y: card.y + root.cardHeight - height + 7 * k
            z: -k
            radius: card.radius * (1 - 0.06 * k)
            color: Qt.tint(skin.planetLow, Theme.withAlpha(skin.inkBase, skin.light ? 0.02 + 0.03 * k : 0.04 + 0.03 * k))
            border.width: 1
            border.color: skin.ink(skin.light ? 0.08 : 0.1)
            opacity: root.reveal * (1 - 0.25 * peek.index)
        }
    }

    // --- Card ----------------------------------------------------------------------
    Item {
        id: card
        width: root.cardWidth
        height: root.cardHeight
        x: root.pad
        y: root.topGap
        readonly property real radius: 28
        // Where the planet's limb crosses the middle of the card
        readonly property real horizon: 222
        // Unfolds downwards from the bar; after a connection it folds back
        // into the corner it came from
        opacity: Math.min(1, root.reveal * 1.6)
        transform: [
            Scale {
                origin.x: root.exitToBar ? card.width : card.width / 2
                origin.y: 0
                xScale: root.exitToBar ? 0.12 + 0.88 * root.reveal : 0.93 + 0.07 * root.reveal
                yScale: root.exitToBar ? 0.12 + 0.88 * root.reveal : 0.78 + 0.22 * root.reveal
            },
            Translate {
                y: root.exitToBar ? 0 : -16 * (1 - root.reveal)
            }
        ]

        HoverHandler {
            id: hover
        }

        // A click on the card's background takes the focus back from the
        // name field, which keeps what was typed
        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                root.forceActiveFocus();
                mouse.accepted = false;
            }
        }

        // Shadow: neutral and deep on the night, soft and tinted on the pearl
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: skin.planetLow
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.light ? Qt.tint(Qt.rgba(0.1, 0.1, 0.16, 0.22), Theme.withAlpha(skin.accent, 0.12)) : Qt.rgba(0, 0, 0, 0.55)
                // Short enough to fit in the sheet's own margin
                blurMax: 24
                shadowBlur: 0.7
                shadowVerticalOffset: 8
            }
        }

        // Everything painted inside the rounded card
        Item {
            id: inside
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
            }

            // Sky
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: skin.skyTop
                    }
                    GradientStop {
                        position: card.horizon / card.height
                        color: skin.skyLow
                    }
                }
            }

            // One wide light behind the device, in the accent
            Light {
                width: 420
                squash: 0.8
                x: card.width / 2 - width / 2
                y: 0
                tint: skin.haze
                strength: skin.light ? 0.4 : 0.3
            }
            Light {
                width: 260
                x: 170
                y: -120
                tint: skin.accent2
                strength: skin.light ? 0.16 : 0.18
            }

            // Stars, in three depths that drift a little with the pointer
            // tilt. Fixed scatter (golden ratio), so the sky is the same each
            // time; one in six twinkles.
            Repeater {
                model: [[150, 0.9, 0.4], [70, 1.3, 0.8], [18, 1.9, 1.3]]
                Item {
                    id: layerOfStars
                    required property var modelData
                    required property int index
                    anchors.fill: parent
                    transform: Translate {
                        x: -root.tiltY * layerOfStars.modelData[2]
                        y: root.tiltX * layerOfStars.modelData[2]
                    }
                    Repeater {
                        model: layerOfStars.modelData[0]
                        Rectangle {
                            id: star
                            required property int index
                            readonly property real u: (index * 0.6180339 + 0.137 + layerOfStars.index * 0.29) % 1
                            readonly property real v: (index * 0.7548776 + 0.421 + layerOfStars.index * 0.53) % 1
                            readonly property real base: skin.light ? 0.08 + 0.14 * ((index * 0.31) % 1) + 0.12 * layerOfStars.index : 0.14 + 0.32 * ((index * 0.31) % 1) + 0.2 * layerOfStars.index
                            readonly property bool twinkles: index % 6 === 0
                            visible: v * card.height < card.horizon - 4
                            x: u * card.width
                            y: v * card.height
                            width: layerOfStars.modelData[1]
                            height: width
                            radius: width / 2
                            color: skin.ink(1)
                            opacity: twinkles ? base * (0.5 + 0.5 * Math.sin(root.clock * (1.3 + (index % 5) * 0.35) + index)) : base
                        }
                    }
                }
            }

            // Now and then a shooting star crosses the sky
            Item {
                id: meteor
                readonly property real period: 7.5
                readonly property int n: Math.floor(root.clock / period)
                readonly property real p: ((root.clock % period) / period) / 0.12
                visible: root.moving && root.clock > 2.5 && p < 1
                x: 150 + (n * 67) % 160 - p * 170
                y: 18 + (n * 41) % 70 + p * 80
                Rectangle {
                    width: 70
                    height: 1.4
                    radius: 0.7
                    transformOrigin: Item.Left
                    rotation: -25
                    opacity: meteor.p < 0.25 ? meteor.p / 0.25 : 1 - (meteor.p - 0.25) / 0.75
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: skin.ink(skin.light ? 0.6 : 0.95)
                        }
                        GradientStop {
                            position: 1
                            color: skin.ink(0)
                        }
                    }
                }
            }

            // Two small constellations, drawn like a star chart
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: skin.light ? 0.22 : 0.16
                ShapePath {
                    strokeColor: skin.ink(1)
                    strokeWidth: 0.8
                    fillColor: "transparent"
                    startX: 34
                    startY: 120
                    PathLine {
                        x: 62
                        y: 92
                    }
                    PathLine {
                        x: 96
                        y: 104
                    }
                    PathLine {
                        x: 84
                        y: 140
                    }
                    PathLine {
                        x: 62
                        y: 92
                    }
                }
            }
            Repeater {
                model: [[34, 120], [62, 92], [96, 104], [84, 140]]
                Rectangle {
                    required property var modelData
                    width: 3
                    height: 3
                    radius: 1.5
                    x: modelData[0] - 1.5
                    y: modelData[1] - 1.5
                    color: skin.ink(skin.light ? 0.4 : 0.75)
                }
            }

            // Atmosphere: the accent glowing along the limb
            Light {
                width: 520
                squash: 0.32
                x: card.width / 2 - width / 2
                y: card.horizon - width * squash / 2
                tint: skin.haze
                strength: skin.light ? 0.55 : 0.55
            }

            // The planet, much wider than the card: only its top shows
            Rectangle {
                id: planet
                readonly property real r: 560
                width: r * 2
                height: r * 2
                radius: r
                x: card.width / 2 - r
                y: card.horizon
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: skin.planetTop
                    }
                    GradientStop {
                        position: 0.25
                        color: skin.planetLow
                    }
                }
            }

            // Lit limb: bright in the middle, fading towards the edges (a
            // horizontal mask, since a stroke cannot take a gradient in Qt 6.9)
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: limbMask
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 1.6
                        strokeColor: skin.light ? skin.accent : Qt.lighter(skin.accent, 1.2)
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: card.width / 2
                            centerY: card.horizon + planet.r
                            radiusX: planet.r
                            radiusY: planet.r
                            startAngle: 240
                            sweepAngle: 60
                        }
                    }
                }
            }
            Rectangle {
                id: limbMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.02
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: "white"
                    }
                    GradientStop {
                        position: 0.98
                        color: "transparent"
                    }
                }
            }
        }

        Rectangle {
            id: cardMask
            anchors.fill: parent
            radius: card.radius
            visible: false
            layer.enabled: true
        }

        // Hairline outline
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            border.width: 1
            border.color: skin.ink(skin.light ? 0.08 : 0.09)
        }

        // --- Header ---------------------------------------------------------------
        Rectangle {
            id: statusPill
            x: 16
            y: 16
            opacity: root.stagger(0)
            height: 28
            width: statusRow.implicitWidth + 22
            radius: 14
            color: skin.light ? Qt.rgba(1, 1, 1, 0.7) : skin.ink(0.06)
            border.width: 1
            border.color: skin.ink(skin.light ? 0.07 : 0.1)

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.phase === "failed" ? Theme.error : skin.accent
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({
                            "offer": "Pairing mode",
                            "pairing": "Pairing…",
                            "connecting": "Connecting…",
                            "done": "Connected",
                            "failed": "Not connected"
                        })[root.phase] || ""
                    color: skin.ink(0.85)
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.Medium
                }
            }
        }

        Rectangle {
            visible: root.stacked > 0
            anchors.right: closeButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: closeButton.verticalCenter
            height: 24
            width: moreText.implicitWidth + 16
            radius: 12
            color: Theme.withAlpha(skin.accent, 0.16)
            StyledText {
                id: moreText
                anchors.centerIn: parent
                text: "+" + root.stacked
                color: skin.accent
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.DemiBold
            }
        }

        // Close, with the time left as a ring around it
        Item {
            id: closeButton
            opacity: root.stagger(0)
            width: 32
            height: 32
            x: card.width - width - 14
            y: 14

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: skin.light ? Qt.rgba(1, 1, 1, closeArea.containsMouse ? 0.95 : 0.7) : skin.ink(closeArea.containsMouse ? 0.14 : 0.06)
            }
            Shape {
                anchors.fill: parent
                visible: root.phase === "offer"
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: skin.accent
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 16
                        centerY: 16
                        radiusX: 15
                        radiusY: 15
                        startAngle: -90
                        sweepAngle: 360 * root.life
                    }
                }
            }
            DankIcon {
                anchors.centerIn: parent
                name: "close"
                size: 17
                color: skin.ink(0.8)
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.later()
            }
        }

        // --- Stage --------------------------------------------------------------------
        Item {
            id: stage
            y: 46
            width: card.width
            height: card.horizon - y
            readonly property real cx: width / 2
            readonly property real deviceY: 86

            // Where the device is now: out of the bar (fall 0), in orbit (1)
            function along(t) {
                const u = 1 - t;
                return Qt.point(u * u * 150 + 2 * u * t * -120, u * u * -210 + 2 * u * t * -20);
            }

            // A thin orbit around the device: back half behind it, front half over it
            component OrbitHalf: Shape {
                property bool front: false
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                rotation: -9
                opacity: root.arrived
                ShapePath {
                    strokeColor: Theme.withAlpha(skin.accent, front ? (skin.light ? 0.55 : 0.7) : (skin.light ? 0.22 : 0.28))
                    strokeWidth: front ? 1.3 : 1
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: stage.cx
                        centerY: stage.deviceY + 18
                        radiusX: 116
                        radiusY: 24
                        startAngle: front ? 0 : 180
                        sweepAngle: 180
                    }
                }
            }
            OrbitHalf {
                z: 0
            }

            // Sonar: rings leaving the device while it waits, faster while pairing
            Repeater {
                model: 2
                Rectangle {
                    id: ring
                    required property int index
                    readonly property real speed: root.busy ? 0.75 : 0.38
                    readonly property real f: (root.clock * speed + index * 0.5) % 1
                    z: 0
                    width: 120
                    height: 120
                    radius: 60
                    x: stage.cx - 60
                    y: stage.deviceY - 60 + root.floatY
                    scale: 1 + f * 1.1
                    color: "transparent"
                    border.width: 1.2 / scale
                    border.color: skin.accent
                    visible: root.moving && root.phase !== "done" && root.phase !== "failed"
                    opacity: root.arrived * (1 - f) * (skin.light ? 0.35 : 0.45)
                }
            }

            // Comet trail: ghosts of where the device just was
            Repeater {
                model: 9
                Rectangle {
                    id: ghost
                    required property int index
                    readonly property point at: stage.along(Math.max(0, root.fall - (index + 1) * 0.045))
                    z: 0
                    width: 30 - index * 2.6
                    height: width
                    radius: width / 2
                    x: stage.cx + at.x - width / 2
                    y: stage.deviceY + at.y - height / 2
                    color: skin.haze
                    opacity: root.fall > 0 && root.fall < 1 ? (0.4 - index * 0.04) * Math.min(1, (1 - root.fall) * 4) : 0
                }
            }

            // Flash when the orbit catches it
            Rectangle {
                id: flash
                z: 0
                width: 110
                height: 110
                radius: 55
                x: stage.cx - 55
                y: stage.deviceY - 55
                color: "transparent"
                border.width: 1.5
                border.color: skin.accent
                opacity: 0
            }

            Item {
                id: hero
                z: 1
                width: 150
                height: 150
                readonly property point at: stage.along(root.fall)
                x: stage.cx - width / 2
                y: stage.deviceY - height / 2
                scale: 0.45 + 0.55 * root.fall
                opacity: Math.min(1, root.fall * 3)
                transform: [
                    Translate {
                        x: hero.at.x
                        y: hero.at.y + root.floatY
                    },
                    Rotation {
                        origin.x: 75
                        origin.y: 75
                        axis.x: 1
                        axis.y: 0
                        axis.z: 0
                        angle: root.tiltX
                    },
                    Rotation {
                        origin.x: 75
                        origin.y: 75
                        axis.x: 0
                        axis.y: 1
                        axis.z: 0
                        angle: root.tiltY
                    },
                    Rotation {
                        origin.x: 75
                        origin.y: 75
                        angle: root.floatTurn
                    }
                ]

                // Battery once connected: a ring around the device, filling up
                Shape {
                    anchors.fill: parent
                    visible: root.phase === "done" && root.battery >= 0
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: skin.ink(0.1)
                        strokeWidth: 4
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: 75
                            centerY: 75
                            radiusX: 72
                            radiusY: 72
                            sweepAngle: 360
                        }
                    }
                    ShapePath {
                        strokeColor: skin.accent
                        strokeWidth: 4
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 75
                            centerY: 75
                            radiusX: 72
                            radiusY: 72
                            startAngle: -90
                            sweepAngle: 3.6 * root.shownBattery
                        }
                    }
                }

                // Night: the device glows. Pearl: it casts a soft shadow that
                // stretches as it floats up.
                DeviceGlyph {
                    id: glyph
                    anchors.centerIn: parent
                    width: pictureShown ? 128 : 108
                    height: width
                    kind: root.kind
                    pictureSource: root.pictureSource
                    color: skin.light ? skin.accent : Qt.lighter(skin.accent, 1.08)
                    stroke: skin.light ? 1.35 : 1.15
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: skin.light ? Qt.tint(Qt.rgba(0.08, 0.08, 0.14, 1), Theme.withAlpha(skin.accent, 0.3)) : skin.glow
                        shadowBlur: 1
                        shadowOpacity: skin.light ? 0.3 + root.floatY * 0.012 : 0.85 - root.floatY * 0.02
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: skin.light ? 13 - root.floatY * 1.2 : 0
                    }
                }

                Rectangle {
                    visible: root.phase === "done" && root.battery >= 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 16
                    height: 24
                    width: batteryText.implicitWidth + 18
                    radius: 12
                    color: skin.accent
                    StyledText {
                        id: batteryText
                        anchors.centerIn: parent
                        text: Math.round(root.shownBattery) + " %"
                        color: skin.inkOnAccent
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.DemiBold
                    }
                }
            }

            OrbitHalf {
                front: true
                z: 2
            }

            // A small moon going round: in front of the device, then behind it
            Rectangle {
                readonly property real a: root.clock * 0.8 + 0.6
                readonly property real px: 116 * Math.cos(a)
                readonly property real py: 24 * Math.sin(a)
                readonly property real t: -9 * Math.PI / 180
                z: Math.sin(a) > 0 ? 3 : 0.5
                width: 7
                height: 7
                radius: 3.5
                x: stage.cx + px * Math.cos(t) - py * Math.sin(t) - 3.5
                y: stage.deviceY + 18 + px * Math.sin(t) + py * Math.cos(t) - 3.5
                color: skin.accent
                opacity: root.arrived * (Math.sin(a) > 0 ? 1 : 0.45)
            }

            // Connected: a burst of stars out of the device
            Repeater {
                model: 16
                Rectangle {
                    id: spark
                    required property int index
                    readonly property real a: index * Math.PI * 2 / 16 + (index % 2) * 0.2
                    readonly property real d: 46 + root.burst * (60 + (index % 3) * 22)
                    z: 3
                    visible: root.burst > 0 && root.burst < 1
                    width: index % 3 === 0 ? 4 : 2.6
                    height: width
                    radius: width / 2
                    x: stage.cx + d * Math.cos(a) - width / 2
                    y: stage.deviceY + d * Math.sin(a) * 0.8 - height / 2
                    color: index % 2 ? skin.accent : skin.ink(1)
                    opacity: 1 - root.burst
                }
            }
        }

        // --- Identity, on the planet ----------------------------------------------------
        Column {
            id: identity
            y: card.horizon + 22
            width: card.width
            spacing: 2
            opacity: root.stagger(3)
            transform: Translate {
                y: (1 - root.stagger(3)) * 14
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.renaming ? card.width - 48 : nameRow.implicitWidth
                height: nameRow.implicitHeight

                Row {
                    id: nameRow
                    visible: !root.renaming
                    spacing: 6
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.name
                        color: skin.ink(0.96)
                        font.pixelSize: Theme.fontSizeLarge + 10
                        font.weight: Font.Bold
                        font.letterSpacing: -0.4
                        // One line: a long name (an alias) is cut, never wrapped
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, card.width - 76)
                    }
                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.phase === "offer"
                        name: "edit"
                        size: 16
                        color: skin.ink(0.4)
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                nameInput.text = root.name;
                                root.renaming = true;
                                nameInput.forceActiveFocus();
                                nameInput.selectAll();
                            }
                        }
                    }
                }

                // Rename before connecting: Enter keeps it, Escape cancels
                Rectangle {
                    visible: root.renaming
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: 12
                    color: skin.tileFill
                    border.width: 1
                    border.color: skin.accent
                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        color: skin.ink(0.96)
                        selectionColor: Theme.withAlpha(skin.accent, 0.4)
                        font.pixelSize: Theme.fontSizeLarge + 6
                        font.weight: Font.Bold
                        maximumLength: 40
                        clip: true
                        // Leaving the field keeps what was typed: Enter, a click
                        // elsewhere on the sheet, or another window taking the
                        // keyboard. Only Escape gives the old name back.
                        property bool hadFocus: false
                        function commit() {
                            if (!root.renaming)
                                return;
                            root.renaming = false;
                            hadFocus = false;
                            root.renamed(text.trim());
                            root.forceActiveFocus();
                        }
                        onActiveFocusChanged: {
                            if (activeFocus)
                                hadFocus = true;
                            else if (hadFocus)
                                commit();
                        }
                        Keys.onReturnPressed: commit()
                        Keys.onEnterPressed: commit()
                        Keys.onEscapePressed: {
                            hadFocus = false;
                            root.renaming = false;
                            root.forceActiveFocus();
                        }
                    }
                }
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.phase === "failed" ? root.errorText : root.phase === "confirm" ? "It can also send key presses, often for its buttons. Only continue if it is yours." : root.renaming ? "Enter or click away to keep · Escape to cancel" : root.subtitle
                color: root.phase === "failed" ? Theme.error : root.phase === "confirm" ? skin.ink(0.78) : skin.ink(0.5)
                width: Math.min(implicitWidth, root.width - 48)
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall
                font.letterSpacing: 0.2
            }
        }

        // --- Middle: tiles, steps or quick actions (PairingMiddle.qml) ------------------
        PairingMiddle {
            id: middle
            x: 16
            y: 324
            width: card.width - 32
            height: 76
            opacity: root.stagger(4)
            transform: Translate {
                y: (1 - root.stagger(4)) * 14
            }
            sheet: root
            look: skin
        }

        // --- Main button ---------------------------------------------------------------
        // Its own light under it: a glow on the night, a tinted shadow on the pearl
        Light {
            visible: !root.busy
            opacity: root.stagger(5)
            width: card.width - 60
            squash: 0.2
            x: 30
            y: mainButton.y + mainButton.height - 10
            tint: skin.haze
            strength: skin.light ? 0.45 : 0.32
        }

        Rectangle {
            id: mainButton
            x: 16
            y: 420
            opacity: root.stagger(5)
            transform: Translate {
                y: (1 - root.stagger(5)) * 14
            }
            width: card.width - 32
            height: 50
            radius: 25
            readonly property bool quiet: root.busy
            color: quiet ? Theme.withAlpha(skin.accent, 0.14) : skin.accent
            gradient: quiet ? null : shine
            Gradient {
                id: shine
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: skin.accent
                }
                GradientStop {
                    position: 1
                    color: Qt.tint(skin.accent, Theme.withAlpha(skin.accent2, 0.4))
                }
            }

            // Progress while pairing and connecting, with a sheen running across
            Rectangle {
                visible: root.busy
                height: parent.height
                radius: parent.radius
                width: parent.width * (root.phase === "pairing" ? 0.38 : root.phase === "connecting" ? 0.72 : 0)
                color: Theme.withAlpha(skin.accent, 0.35)
                Behavior on width {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Item {
                anchors.fill: parent
                visible: root.busy && root.moving
                clip: true
                Rectangle {
                    width: 90
                    height: parent.height
                    x: ((root.clock * 0.7) % 1) * (parent.width + 180) - 180
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.5
                            color: Theme.withAlpha(skin.accent, 0.35)
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: ({
                            "offer": "bluetooth",
                            "pairing": "bluetooth_searching",
                            "connecting": "bluetooth_searching",
                            "done": "check",
                            "confirm": "keyboard",
                            "failed": "refresh"
                        })[root.phase] || "bluetooth"
                    size: 19
                    color: mainButton.quiet ? skin.ink(0.92) : skin.inkOnAccent
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({
                            "offer": "Connect",
                            "pairing": "Pairing",
                            "connecting": "Connecting",
                            "done": "Done",
                            "confirm": "Pair anyway",
                            "failed": "Try again"
                        })[root.phase] || ""
                    color: mainButton.quiet ? skin.ink(0.92) : skin.inkOnAccent
                    font.pixelSize: Theme.fontSizeMedium + 1
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !root.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: root.phase === "failed" ? root.retry() : root.phase === "done" ? root.later() : root.phase === "confirm" ? root.confirmed() : root.accepted()
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: mainButton.y + mainButton.height + 6
            height: 28
            spacing: 4
            opacity: root.stagger(6)

            component Quiet: StyledText {
                id: quiet
                signal clicked
                height: 28
                leftPadding: 10
                rightPadding: 10
                verticalAlignment: Text.AlignVCenter
                color: skin.ink(quietArea.containsMouse ? 0.92 : 0.5)
                font.pixelSize: Theme.fontSizeSmall
                MouseArea {
                    id: quietArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: quiet.clicked()
                }
            }

            Quiet {
                visible: root.phase === "offer" || root.phase === "failed"
                text: "Later"
                onClicked: root.later()
            }
            StyledText {
                visible: root.phase === "offer" || root.phase === "failed"
                text: "·"
                height: 28
                verticalAlignment: Text.AlignVCenter
                color: skin.ink(0.35)
            }
            Quiet {
                visible: root.phase === "offer" || root.phase === "failed"
                text: "Don't offer again"
                onClicked: root.ignored()
            }
            Quiet {
                visible: root.busy || root.phase === "confirm"
                text: "Cancel"
                onClicked: root.cancelled()
            }
        }

        // Credit of a downloaded picture: its license asks for it
        StyledText {
            visible: root.credit !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: card.horizon - 18
            width: card.width - 40
            horizontalAlignment: Text.AlignHCenter
            text: "Picture " + root.credit
            elide: Text.ElideMiddle
            color: skin.ink(0.32)
            font.pixelSize: Theme.fontSizeSmall - 3
        }
    }
}
