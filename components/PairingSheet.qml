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
    signal renameRequested
    signal openOrbit
    signal modeRequested(string mode)

    readonly property bool busy: phase === "pairing" || phase === "connecting"
    readonly property Item card: card

    readonly property real cardWidth: 340
    readonly property real cardHeight: 520
    // Room for the shadow and the card peeking behind
    implicitWidth: cardWidth + 48
    implicitHeight: cardHeight + 64

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

    // --- The next device, peeking behind ------------------------------------------
    Rectangle {
        visible: root.stacked > 0
        width: root.cardWidth - 36
        height: root.cardHeight
        x: card.x + 18
        y: card.y + 20
        radius: card.radius
        color: skin.planetTop
        border.width: 1
        border.color: Theme.withAlpha(skin.accent, 0.3)
    }

    // --- Card ----------------------------------------------------------------------
    Item {
        id: card
        width: root.cardWidth
        height: root.cardHeight
        x: 24
        y: 12
        readonly property real radius: 30
        // Where the planet's limb crosses the middle of the card
        readonly property real horizon: 222

        // Shadow: neutral and deep on the night, soft and tinted on the pearl
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: skin.planetLow
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.light ? Qt.tint(Qt.rgba(0.1, 0.1, 0.16, 0.22), Theme.withAlpha(skin.accent, 0.12)) : Qt.rgba(0, 0, 0, 0.6)
                shadowBlur: 1
                shadowVerticalOffset: skin.light ? 14 : 12
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

            // Stars: many faint ones, a few brighter. Fixed (golden-ratio
            // scatter) so the sheet looks the same each time.
            Repeater {
                model: 70
                Rectangle {
                    required property int index
                    readonly property real u: (index * 0.6180339 + 0.137) % 1
                    readonly property real v: (index * 0.7548776 + 0.421) % 1
                    readonly property bool bright: index % 9 === 0
                    visible: v * card.height < card.horizon - 6
                    x: u * card.width
                    y: v * card.height
                    width: bright ? 1.8 : index % 3 === 0 ? 1.2 : 0.9
                    height: width
                    radius: width / 2
                    color: skin.ink(1)
                    opacity: skin.light ? (bright ? 0.45 : 0.1 + 0.2 * ((index * 0.31) % 1)) : (bright ? 0.85 : 0.18 + 0.4 * ((index * 0.31) % 1))
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

            // A thin orbit around the device: back half behind it, front half over it
            component OrbitHalf: Shape {
                property bool front: false
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                rotation: -9
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
            OrbitHalf {}

            Item {
                id: hero
                width: 150
                height: 150
                x: stage.cx - width / 2
                y: stage.deviceY - height / 2

                // Battery once connected: a ring around the device
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
                            sweepAngle: 3.6 * Math.max(0, root.battery)
                        }
                    }
                }

                // Night: the device glows. Pearl: it casts a soft shadow.
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
                        shadowOpacity: skin.light ? 0.3 : 0.9
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: skin.light ? 12 : 0
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
                        text: root.battery + " %"
                        color: skin.inkOnAccent
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.DemiBold
                    }
                }
            }

            OrbitHalf {
                front: true
            }

            // A small moon on the front of the orbit
            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                x: stage.cx + 70
                y: stage.deviceY + 32
                color: skin.accent
            }
        }

        // --- Identity, on the planet ----------------------------------------------------
        Column {
            id: identity
            y: card.horizon + 22
            width: card.width
            spacing: 2

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.name
                    color: skin.ink(0.96)
                    font.pixelSize: Theme.fontSizeLarge + 10
                    font.weight: Font.Bold
                    font.letterSpacing: -0.4
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, card.width - 80)
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
                        onClicked: root.renameRequested()
                    }
                }
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.phase === "failed" ? "Could not connect. Is it still in pairing mode?" : root.subtitle
                color: root.phase === "failed" ? Theme.error : skin.ink(0.5)
                font.pixelSize: Theme.fontSizeSmall
                font.letterSpacing: 0.2
            }
        }

        // --- Middle: tiles, steps or quick actions -----------------------------------------
        Item {
            id: middle
            x: 16
            y: 324
            width: card.width - 32
            height: 76

            // What you get
            Row {
                visible: root.phase === "offer"
                spacing: 8
                Repeater {
                    model: root.features
                    Rectangle {
                        id: tile
                        required property var modelData
                        width: (middle.width - 16) / 3
                        height: middle.height
                        radius: 18
                        color: skin.tileFill
                        border.width: 1
                        border.color: skin.tileBorder
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: tile.modelData.icon
                                size: 19
                                color: skin.accent
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.value
                                color: skin.ink(0.92)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                color: skin.ink(0.5)
                                font.pixelSize: Theme.fontSizeSmall - 2
                            }
                        }
                    }
                }
            }

            // Pairing steps
            Item {
                id: steps
                anchors.fill: parent
                visible: root.busy || root.phase === "failed"
                readonly property int step: root.phase === "connecting" ? 1 : 0
                readonly property var labels: ["Pair", "Connect", "Ready"]

                Rectangle {
                    x: parent.width / 6
                    width: parent.width * 2 / 3
                    y: 15
                    height: 2
                    radius: 1
                    color: skin.ink(0.1)
                    Rectangle {
                        height: parent.height
                        radius: 1
                        width: parent.width * (steps.step / 2 + (root.busy ? 0.25 : 0))
                        color: skin.accent
                    }
                }
                Repeater {
                    model: 3
                    Column {
                        id: stepItem
                        required property int index
                        readonly property bool passed: index < steps.step
                        readonly property bool current: index === steps.step && root.phase !== "failed"
                        x: steps.width * (index * 2 + 1) / 6 - width / 2
                        width: 70
                        spacing: 6
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 32
                            height: 32
                            radius: 16
                            color: stepItem.passed ? skin.accent : skin.planetLow
                            border.width: stepItem.passed ? 0 : 1.5
                            border.color: stepItem.current ? skin.accent : root.phase === "failed" && stepItem.index === 0 ? Theme.error : skin.ink(0.16)
                            DankIcon {
                                anchors.centerIn: parent
                                name: stepItem.passed ? "check" : ["link", "bluetooth", "headphones"][stepItem.index]
                                size: 16
                                color: stepItem.passed ? skin.inkOnAccent : stepItem.current ? skin.accent : skin.ink(0.4)
                            }
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: steps.labels[stepItem.index]
                            color: stepItem.current ? skin.ink(0.92) : skin.ink(0.5)
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: stepItem.current ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }

            // Once connected: noise-control mode
            Column {
                anchors.fill: parent
                visible: root.phase === "done"
                spacing: 8

                Rectangle {
                    visible: root.ancModes.length > 0
                    width: parent.width
                    height: 44
                    radius: 22
                    color: skin.tileFill
                    border.width: 1
                    border.color: skin.tileBorder
                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        Repeater {
                            model: root.ancModes
                            Rectangle {
                                id: modeItem
                                required property var modelData
                                readonly property bool on: modelData.id === root.ancMode
                                width: parent.width / root.ancModes.length
                                height: parent.height
                                radius: height / 2
                                color: on ? skin.accent : "transparent"
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modeItem.modelData.icon
                                        size: 17
                                        color: modeItem.on ? skin.inkOnAccent : skin.ink(0.5)
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: modeItem.on
                                        text: modeItem.modelData.label
                                        color: skin.inkOnAccent
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.weight: Font.DemiBold
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.modeRequested(modeItem.modelData.id)
                                }
                            }
                        }
                    }
                }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.ancModes.length ? "Noise control" : "Ready to use"
                    color: skin.ink(0.5)
                    font.pixelSize: Theme.fontSizeSmall - 1
                }
            }
        }

        // --- Main button ---------------------------------------------------------------
        // Its own light under it: a glow on the night, a tinted shadow on the pearl
        Light {
            visible: !root.busy
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

            // Progress while pairing and connecting
            Rectangle {
                visible: root.busy
                height: parent.height
                radius: parent.radius
                width: parent.width * (root.phase === "pairing" ? 0.38 : 0.72)
                color: Theme.withAlpha(skin.accent, 0.35)
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
                onClicked: root.phase === "failed" ? root.retry() : root.phase === "done" ? root.later() : root.accepted()
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: mainButton.y + mainButton.height + 6
            height: 28
            spacing: 4

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
                visible: root.busy
                text: "Cancel"
                onClicked: root.cancelled()
            }
            Quiet {
                visible: root.phase === "done"
                text: "Open in Orbit"
                onClicked: root.openOrbit()
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
