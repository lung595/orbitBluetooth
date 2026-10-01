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
// It is a piece of Orbit's night sky in every theme: stars, an aurora in the
// theme's accents, the device floating above a perspective orbit. One end of
// the card melts into the theme's own surface with a long, eased fade, so it
// still belongs to a white, pastel or dark DMS:
// - fade "up": night above, the theme's surface under the buttons
// - fade "down": the theme's surface at the top (it unfolds out of the bar),
//   night below
// - fade "none": night from top to bottom
//
// Accents are pushed to a readable contrast against what lies under them
// (Palette.js): the night for the sky, the theme surface for the rest.
Item {
    id: root

    // "offer", "pairing", "connecting", "done" or "failed"
    property string phase: "offer"
    property string fade: "up"
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
    implicitHeight: cardHeight + 60

    // Which ends of the card sit on the theme's surface
    readonly property bool themeTop: fade === "down"
    readonly property bool themeBottom: fade === "up"

    NightColors {
        id: night
    }

    // --- Colours -------------------------------------------------------------------
    function rgb(o) {
        return Qt.rgba(o.r, o.g, o.b, 1);
    }

    // The theme's surface, where a fade lands
    QtObject {
        id: pal
        readonly property color surface: Theme.surfaceContainer
        readonly property color text: Theme.surfaceText
        readonly property bool light: Palette.luminance(surface) > 0.35
        readonly property color accent: root.rgb(Palette.ensureContrast(sky.seed, surface, 3.2))
        readonly property color accent2: root.rgb(Palette.ensureContrast(sky.seed2, surface, 2.4))
        readonly property color onAccent: root.rgb(Palette.onColor(accent))
        readonly property color line: Theme.withAlpha(text, light ? 0.12 : 0.1)
        function fg(a) {
            return Theme.withAlpha(text, a);
        }
    }

    // The night sky, whatever the theme
    QtObject {
        id: sky
        readonly property color base: night.sky
        readonly property color deep: night.skyDeep
        // A grey theme accent borrows the picture's colour when there is one
        readonly property color seed: Palette.isGrey(Theme.primary) && probe.found.a > 0 ? probe.found : Theme.primary
        readonly property color seed2: Palette.isGrey(Theme.tertiary) ? seed : Theme.tertiary
        // Lifted like the rest of Orbit's night, then checked for contrast
        readonly property color accent: root.rgb(Palette.ensureContrast(Palette.lift(seed, 0.68), base, 6))
        readonly property color accent2: root.rgb(Palette.ensureContrast(Palette.lift(seed2, 0.62), base, 4))
        // The device's own colour (picture) leads the aurora when known
        readonly property color glow: probe.found.a > 0 ? root.rgb(Palette.ensureContrast(Palette.lift(probe.found, 0.62), base, 4)) : accent
        readonly property color onAccent: root.rgb(Palette.onColor(accent))
        readonly property color line: night.ink(0.1)
        function fg(a) {
            return night.ink(a);
        }
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
        color: root.themeBottom ? Qt.tint(pal.surface, Theme.withAlpha(pal.accent, 0.1)) : Qt.tint(sky.base, Theme.withAlpha(sky.accent, 0.1))
        border.width: 1
        border.color: Theme.withAlpha(root.themeBottom ? pal.accent : sky.accent, 0.3)
    }

    // --- Card ----------------------------------------------------------------------
    Item {
        id: card
        width: root.cardWidth
        height: root.cardHeight
        x: 24
        y: 12
        readonly property real radius: 30

        // Shadow
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: sky.base
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, pal.light ? 0.3 : 0.6)
                shadowBlur: 1
                shadowVerticalOffset: 12
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

            // Night, a touch deeper at the top
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: sky.deep
                    }
                    GradientStop {
                        position: 1
                        color: sky.base
                    }
                }
            }

            // Aurora in the theme's accents, and the device's colour under it
            Light {
                width: 420
                x: -190
                y: -150
                tint: sky.accent
                strength: 0.4
            }
            Light {
                width: 400
                x: 140
                y: -130
                tint: sky.accent2
                strength: 0.36
            }
            Light {
                width: 320
                squash: 0.62
                x: 10
                y: 70
                tint: sky.glow
                strength: 0.34
            }
            // A faint band of the milky way across the sky
            Light {
                width: 560
                squash: 0.16
                x: -110
                y: 150
                rotation: -24
                tint: night.ink(1)
                strength: 0.05
            }

            // Stars: many faint ones, a few brighter, three with a soft flare.
            // Fixed (golden-ratio scatter) so the sheet looks the same each time.
            Repeater {
                model: 90
                Rectangle {
                    required property int index
                    readonly property real u: (index * 0.6180339 + 0.137) % 1
                    readonly property real v: (index * 0.7548776 + 0.421) % 1
                    readonly property bool bright: index % 9 === 0
                    x: u * card.width
                    y: v * card.height
                    width: bright ? 1.8 : index % 3 === 0 ? 1.2 : 0.9
                    height: width
                    radius: width / 2
                    color: night.ink(1)
                    opacity: bright ? 0.85 : 0.18 + 0.4 * ((index * 0.31) % 1)
                }
            }
            Repeater {
                model: [[0.12, 0.2], [0.84, 0.31], [0.71, 0.08]]
                Item {
                    id: flare
                    required property var modelData
                    required property int index
                    x: modelData[0] * card.width
                    y: modelData[1] * card.height
                    Light {
                        width: 18
                        x: -9
                        y: -9
                        tint: night.ink(1)
                        strength: 0.5
                    }
                    Rectangle {
                        width: 14 - flare.index * 3
                        height: 1
                        x: -width / 2
                        y: -0.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: night.ink(0)
                            }
                            GradientStop {
                                position: 0.5
                                color: night.ink(0.9)
                            }
                            GradientStop {
                                position: 1
                                color: night.ink(0)
                            }
                        }
                    }
                    Rectangle {
                        width: 1
                        height: 14 - flare.index * 3
                        x: -0.5
                        y: -height / 2
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: night.ink(0)
                            }
                            GradientStop {
                                position: 0.5
                                color: night.ink(0.9)
                            }
                            GradientStop {
                                position: 1
                                color: night.ink(0)
                            }
                        }
                    }
                }
            }

            // The theme's surface melting into the night. Many stops on an
            // eased curve (smoothstep), so the long fade never bands.
            Rectangle {
                id: fadeLayer
                visible: root.fade !== "none"
                anchors.fill: parent
                readonly property real from: root.themeTop ? 0.04 : 0.78
                readonly property real to: root.themeTop ? 0.38 : 0.93
                gradient: Gradient {
                    id: fadeGradient
                }
                function build() {
                    const stops = [fadeStop.createObject(fadeGradient, {
                            "position": 0,
                            "color": Theme.withAlpha(pal.surface, root.themeTop ? 1 : 0)
                        })];
                    for (let i = 0; i <= 16; i++) {
                        const t = i / 16;
                        const eased = t * t * (3 - 2 * t);
                        stops.push(fadeStop.createObject(fadeGradient, {
                            "position": from + (to - from) * t,
                            "color": Theme.withAlpha(pal.surface, root.themeTop ? 1 - eased : eased)
                        }));
                    }
                    stops.push(fadeStop.createObject(fadeGradient, {
                        "position": 1,
                        "color": Theme.withAlpha(pal.surface, root.themeTop ? 0 : 1)
                    }));
                    fadeGradient.stops = stops;
                }
                Component.onCompleted: build()
                Connections {
                    target: root
                    function onFadeChanged() {
                        fadeLayer.build();
                    }
                }
                Connections {
                    target: pal
                    function onSurfaceChanged() {
                        fadeLayer.build();
                    }
                }
                Component {
                    id: fadeStop
                    GradientStop {}
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
            border.color: pal.light && root.fade !== "none" ? pal.line : night.ink(0.09)
        }

        // --- Header ---------------------------------------------------------------
        // On the night, or on the theme's surface when it unfolds from the bar
        readonly property QtObject topInk: root.themeTop ? pal : sky

        Rectangle {
            id: statusPill
            x: 16
            y: 16
            height: 28
            width: statusRow.implicitWidth + 22
            radius: 14
            color: card.topInk.fg(0.07)
            border.width: 1
            border.color: card.topInk.line

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.phase === "failed" ? night.error : card.topInk.accent
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
                    color: card.topInk.fg(0.88)
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
            color: Theme.withAlpha(card.topInk.accent, 0.18)
            StyledText {
                id: moreText
                anchors.centerIn: parent
                text: "+" + root.stacked
                color: card.topInk.accent
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
                color: card.topInk.fg(closeArea.containsMouse ? 0.14 : 0.07)
            }
            Shape {
                anchors.fill: parent
                visible: root.phase === "offer"
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: card.topInk.accent
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
                color: card.topInk.fg(0.85)
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
            height: 210
            readonly property real cx: width / 2
            readonly property real floorY: 182
            readonly property real deviceY: 98

            // A pool of light on the floor
            Light {
                width: 220
                squash: 0.22
                x: stage.cx - width / 2
                y: stage.floorY - width * squash / 2
                tint: sky.glow
                strength: 0.32
            }

            // Sonar rings spreading on the floor
            Repeater {
                model: 3
                Shape {
                    id: ring
                    required property int index
                    readonly property real k: 0.6 + index * 0.32
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    opacity: root.phase === "done" ? 0 : 0.5 - index * 0.15
                    ShapePath {
                        strokeColor: sky.accent
                        strokeWidth: 1.2
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: stage.cx
                            centerY: stage.floorY
                            radiusX: 104 * ring.k
                            radiusY: 19 * ring.k
                            sweepAngle: 360
                        }
                    }
                }
            }

            // The orbit: its back half behind the device, its front half over it
            component OrbitHalf: Shape {
                property bool front: false
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                rotation: -7
                ShapePath {
                    strokeColor: Theme.withAlpha(sky.accent, front ? 0.7 : 0.3)
                    strokeWidth: front ? 1.4 : 1
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: stage.cx
                        centerY: stage.deviceY + 22
                        radiusX: 122
                        radiusY: 28
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
                        strokeColor: night.ink(0.1)
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
                        strokeColor: sky.accent
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

                DeviceGlyph {
                    id: glyph
                    anchors.centerIn: parent
                    width: pictureShown ? 128 : 112
                    height: width
                    kind: root.kind
                    pictureSource: root.pictureSource
                    color: Qt.lighter(sky.accent, 1.08)
                    stroke: 1.15
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: sky.glow
                        shadowBlur: 1
                        shadowOpacity: 0.9
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                Rectangle {
                    visible: root.phase === "done" && root.battery >= 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 16
                    height: 24
                    width: batteryText.implicitWidth + 18
                    radius: 12
                    color: sky.accent
                    StyledText {
                        id: batteryText
                        anchors.centerIn: parent
                        text: root.battery + " %"
                        color: sky.onAccent
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
                x: stage.cx + 74
                y: stage.deviceY + 39
                color: sky.accent
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: sky.accent
                    shadowBlur: 0.6
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                }
            }
        }

        // --- Identity -----------------------------------------------------------------
        Column {
            id: identity
            y: stage.y + stage.height + 2
            width: card.width
            spacing: 3

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.name
                    color: night.ink(0.97)
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
                    color: night.ink(0.45)
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
                color: root.phase === "failed" ? night.error : night.ink(0.55)
                font.pixelSize: Theme.fontSizeSmall
                font.letterSpacing: 0.2
            }
        }

        // --- Middle: tiles, steps or quick actions, on the night ---------------------------
        Item {
            id: middle
            x: 16
            y: 326
            width: card.width - 32
            height: 72

            // What you get: glass tiles
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
                        color: night.ink(0.05)
                        border.width: 1
                        border.color: night.ink(0.08)
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: tile.modelData.icon
                                size: 19
                                color: sky.accent
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.value
                                color: night.ink(0.95)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                color: night.ink(0.5)
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
                    color: night.ink(0.12)
                    Rectangle {
                        height: parent.height
                        radius: 1
                        width: parent.width * (steps.step / 2 + (root.busy ? 0.25 : 0))
                        color: sky.accent
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
                            color: stepItem.passed ? sky.accent : sky.base
                            border.width: stepItem.passed ? 0 : 1.5
                            border.color: stepItem.current ? sky.accent : root.phase === "failed" && stepItem.index === 0 ? night.error : night.ink(0.18)
                            DankIcon {
                                anchors.centerIn: parent
                                name: stepItem.passed ? "check" : ["link", "bluetooth", "headphones"][stepItem.index]
                                size: 16
                                color: stepItem.passed ? sky.onAccent : stepItem.current ? sky.accent : night.ink(0.45)
                            }
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: steps.labels[stepItem.index]
                            color: stepItem.current ? night.ink(0.95) : night.ink(0.5)
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
                    color: night.ink(0.05)
                    border.width: 1
                    border.color: night.ink(0.08)
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
                                color: on ? sky.accent : "transparent"
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modeItem.modelData.icon
                                        size: 17
                                        color: modeItem.on ? sky.onAccent : night.ink(0.55)
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: modeItem.on
                                        text: modeItem.modelData.label
                                        color: sky.onAccent
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
                    color: night.ink(0.5)
                    font.pixelSize: Theme.fontSizeSmall - 1
                }
            }
        }

        // --- Bottom: on the theme's surface when the night fades up into it -----------------
        readonly property QtObject bottomInk: root.themeBottom ? pal : sky

        Rectangle {
            id: mainButton
            x: 16
            y: 420
            width: card.width - 32
            height: 50
            radius: 25
            readonly property bool quiet: root.busy
            color: quiet ? Theme.withAlpha(card.bottomInk.accent, 0.16) : card.bottomInk.accent
            gradient: quiet ? null : shine
            Gradient {
                id: shine
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: card.bottomInk.accent
                }
                GradientStop {
                    position: 1
                    color: Qt.tint(card.bottomInk.accent, Theme.withAlpha(card.bottomInk.accent2, 0.45))
                }
            }

            // Progress while pairing and connecting
            Rectangle {
                visible: root.busy
                height: parent.height
                radius: parent.radius
                width: parent.width * (root.phase === "pairing" ? 0.38 : 0.72)
                color: Theme.withAlpha(card.bottomInk.accent, 0.4)
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
                    color: mainButton.quiet ? card.bottomInk.fg(0.95) : card.bottomInk.onAccent
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
                    color: mainButton.quiet ? card.bottomInk.fg(0.95) : card.bottomInk.onAccent
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
                color: card.bottomInk.fg(quietArea.containsMouse ? 0.95 : 0.55)
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
                color: card.bottomInk.fg(0.4)
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
            y: stage.y + stage.height - 14
            width: card.width - 40
            horizontalAlignment: Text.AlignHCenter
            text: "Picture " + root.credit
            elide: Text.ElideMiddle
            color: night.ink(0.32)
            font.pixelSize: Theme.fontSizeSmall - 3
        }
    }
}
