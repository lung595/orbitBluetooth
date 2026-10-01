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
// Top to bottom: a status pill and the close button (its ring is the time
// left), a stage where the device floats above a perspective orbit, its
// name, three "what you get" tiles (or the pairing steps, or quick actions
// once connected), the main button and two quiet ones.
//
// Every colour comes from the DMS theme. Accents are pushed to a readable
// contrast against the surface (Palette.js), so the sheet glows with a
// pastel, a neon or a monochrome palette, light or dark.
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
    property real volume: -1
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

    // --- Colours -------------------------------------------------------------------
    QtObject {
        id: pal
        readonly property color surface: Theme.surfaceContainer
        readonly property color raised: Theme.surfaceContainerHigh
        readonly property color text: Theme.surfaceText
        readonly property color muted: Theme.surfaceVariantText
        readonly property bool light: Palette.luminance(surface) > 0.35
        function rgb(o) {
            return Qt.rgba(o.r, o.g, o.b, 1);
        }
        // A grey theme accent borrows the picture's colour when there is one
        readonly property color seed: Palette.isGrey(Theme.primary) && probe.found.a > 0 ? probe.found : Theme.primary
        readonly property color accent: rgb(Palette.ensureContrast(seed, surface, 3.2))
        readonly property color accent2: rgb(Palette.ensureContrast(Palette.isGrey(Theme.tertiary) ? seed : Theme.tertiary, surface, 2.4))
        // The device's own colour (picture) leads the aurora when known
        readonly property color glow: probe.found.a > 0 ? rgb(Palette.ensureContrast(probe.found, surface, 2.4)) : accent
        readonly property color onAccent: rgb(Palette.onColor(accent))
        readonly property color line: Theme.withAlpha(text, light ? 0.1 : 0.08)
    }

    // Average colour of the picture's saturated pixels (see NewDevicePopup)
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

    // --- The next device, peeking behind ------------------------------------------
    Rectangle {
        visible: root.stacked > 0
        width: root.cardWidth - 36
        height: root.cardHeight
        x: card.x + 18
        y: card.y + 20
        radius: card.radius
        color: Qt.tint(pal.surface, Theme.withAlpha(pal.accent, 0.1))
        border.width: 1
        border.color: Theme.withAlpha(pal.accent, 0.3)
    }

    // --- Card ----------------------------------------------------------------------
    Item {
        id: card
        width: root.cardWidth
        height: root.cardHeight
        x: 24
        y: 12
        readonly property real radius: 30

        Rectangle {
            id: body
            anchors.fill: parent
            radius: card.radius
            color: pal.surface
            border.width: 1
            border.color: Theme.withAlpha(pal.accent, pal.light ? 0.22 : 0.18)
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, pal.light ? 0.28 : 0.55)
                shadowBlur: 1
                shadowVerticalOffset: 10
            }
        }

        // Light that must stay inside the rounded card
        Item {
            id: inside
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
            }

            // Aurora: soft lights in the theme's colours, and the device's own
            // colour under the stage
            // A round light, squashed vertically when flatter than wide: the
            // gradient must reach zero exactly at the edge, or it shows a rim
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
                            position: 0.55
                            color: Theme.withAlpha(tint, strength * 0.35)
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
            Light {
                width: 380
                x: -150
                y: -170
                tint: pal.accent
                strength: pal.light ? 0.42 : 0.5
            }
            Light {
                width: 360
                x: 150
                y: -150
                tint: pal.accent2
                strength: pal.light ? 0.36 : 0.42
            }
            Light {
                width: 300
                squash: 0.6
                x: 20
                y: 100
                tint: pal.glow
                strength: pal.light ? 0.4 : 0.45
            }

            // The lower half settles back to the plain surface
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.42
                        color: Theme.withAlpha(pal.surface, 0)
                    }
                    GradientStop {
                        position: 0.66
                        color: pal.surface
                    }
                }
            }

            // Dust in the light, fixed so the sheet looks the same each time
            Repeater {
                model: 22
                Rectangle {
                    required property int index
                    readonly property real h1: (index * 0.6180339 + 0.21) % 1
                    readonly property real h2: (index * 0.4142135 + 0.63) % 1
                    x: 14 + h1 * (card.width - 28)
                    y: 40 + h2 * 220
                    width: index % 6 === 0 ? 2.4 : 1.4
                    height: width
                    radius: width / 2
                    visible: !pal.light || index % 2 === 0
                    color: pal.light ? pal.accent : pal.text
                    opacity: (pal.light ? 0.18 : 0.22) + 0.3 * h2
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

        // --- Header ---------------------------------------------------------------
        Rectangle {
            id: statusPill
            x: 16
            y: 16
            height: 28
            width: statusRow.implicitWidth + 22
            radius: 14
            color: Theme.withAlpha(pal.surface, pal.light ? 0.6 : 0.45)
            border.width: 1
            border.color: pal.line

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.phase === "failed" ? Theme.error : pal.accent
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
                    color: pal.text
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
            color: Theme.withAlpha(pal.accent, 0.16)
            StyledText {
                id: moreText
                anchors.centerIn: parent
                text: "+" + root.stacked
                color: pal.accent
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
                color: closeArea.containsMouse ? Theme.withAlpha(pal.text, 0.12) : Theme.withAlpha(pal.surface, pal.light ? 0.6 : 0.45)
            }
            Shape {
                anchors.fill: parent
                visible: root.phase === "offer"
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: pal.accent
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
                color: pal.text
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
            readonly property real floorY: 180
            readonly property real deviceY: 96

            // Contact shadow on the floor
            Light {
                width: 180
                squash: 0.2
                x: stage.cx - width / 2
                y: stage.floorY - width * squash / 2
                tint: "black"
                strength: pal.light ? 0.22 : 0.6
            }

            // Sonar rings spreading on the floor
            Repeater {
                model: 3
                Shape {
                    required property int index
                    readonly property real k: 0.62 + index * 0.3
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    opacity: root.phase === "done" ? 0 : 0.55 - index * 0.17
                    ShapePath {
                        strokeColor: pal.accent
                        strokeWidth: 1.4
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: stage.cx
                            centerY: stage.floorY
                            radiusX: 104 * k
                            radiusY: 20 * k
                            sweepAngle: 360
                        }
                    }
                }
            }

            // Back half of the orbit, behind the device
            component OrbitHalf: Shape {
                property bool front: false
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                rotation: -7
                ShapePath {
                    strokeColor: Theme.withAlpha(pal.accent, front ? 0.75 : 0.35)
                    strokeWidth: front ? 1.6 : 1.2
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

            // The device, with a glow of its accent
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
                        strokeColor: Theme.withAlpha(pal.text, 0.1)
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
                        strokeColor: pal.accent
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
                    color: pal.light ? pal.accent : Qt.lighter(pal.accent, 1.15)
                    stroke: 1.15
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: pal.glow
                        shadowBlur: 1
                        shadowOpacity: pal.light ? 0.55 : 0.9
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                // Battery level under the device
                Rectangle {
                    visible: root.phase === "done" && root.battery >= 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 16
                    height: 24
                    width: batteryText.implicitWidth + 18
                    radius: 12
                    color: pal.accent
                    StyledText {
                        id: batteryText
                        anchors.centerIn: parent
                        text: root.battery + " %"
                        color: pal.onAccent
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
                width: 8
                height: 8
                radius: 4
                x: stage.cx + 78 - 4
                y: stage.deviceY + 22 + 21 - 4
                color: pal.accent
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: pal.accent
                    shadowBlur: 0.6
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                }
            }
        }

        // --- Identity -----------------------------------------------------------------
        Column {
            id: identity
            y: stage.y + stage.height + 4
            width: card.width
            spacing: 2

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.name
                    color: pal.text
                    font.pixelSize: Theme.fontSizeLarge + 9
                    font.weight: Font.Bold
                    font.letterSpacing: -0.3
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, card.width - 80)
                }
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.phase === "offer"
                    name: "edit"
                    size: 17
                    color: pal.muted
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
                color: root.phase === "failed" ? Theme.error : pal.muted
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // --- Middle: tiles, steps or quick actions --------------------------------------
        Item {
            id: middle
            x: 16
            y: 326
            width: card.width - 32
            height: 76

            // What you get
            Row {
                visible: root.phase === "offer"
                spacing: 8
                Repeater {
                    model: root.features
                    Rectangle {
                        required property var modelData
                        width: (middle.width - 16) / 3
                        height: middle.height
                        radius: 18
                        color: Theme.withAlpha(pal.raised, pal.light ? 0.85 : 0.7)
                        border.width: 1
                        border.color: pal.line
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: modelData.icon
                                size: 20
                                color: pal.accent
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.value
                                color: pal.text
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: pal.muted
                                font.pixelSize: Theme.fontSizeSmall - 2
                            }
                        }
                    }
                }
            }

            // Pairing steps
            Item {
                anchors.fill: parent
                visible: root.busy || root.phase === "failed"
                readonly property int step: root.phase === "pairing" ? 0 : root.phase === "connecting" ? 1 : root.phase === "done" ? 3 : 0
                readonly property var labels: ["Pair", "Connect", "Ready"]

                Rectangle {
                    x: parent.width / 6
                    width: parent.width * 2 / 3
                    y: 16
                    height: 2
                    radius: 1
                    color: Theme.withAlpha(pal.text, 0.12)
                    Rectangle {
                        height: parent.height
                        radius: 1
                        width: parent.width * Math.min(1, parent.parent.step / 2) + (root.busy ? parent.width * 0.25 : 0)
                        color: pal.accent
                    }
                }
                Repeater {
                    model: 3
                    Column {
                        required property int index
                        readonly property bool doneStep: index < parent.step
                        readonly property bool current: index === parent.step && root.phase !== "failed"
                        x: parent.width * (index * 2 + 1) / 6 - width / 2
                        width: 70
                        spacing: 6
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 32
                            height: 32
                            radius: 16
                            color: parent.doneStep ? pal.accent : pal.surface
                            border.width: parent.doneStep ? 0 : 2
                            border.color: parent.current ? pal.accent : root.phase === "failed" && parent.index === 0 ? Theme.error : Theme.withAlpha(pal.text, 0.18)
                            DankIcon {
                                anchors.centerIn: parent
                                name: parent.parent.doneStep ? "check" : ["link", "bluetooth", "headphones"][parent.parent.index]
                                size: 16
                                color: parent.parent.doneStep ? pal.onAccent : parent.parent.current ? pal.accent : pal.muted
                            }
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.labels[parent.index]
                            color: parent.current ? pal.text : pal.muted
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: parent.current ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }

            // Quick actions once connected: noise-control mode
            Column {
                anchors.fill: parent
                visible: root.phase === "done"
                spacing: 8

                Rectangle {
                    visible: root.ancModes.length > 0
                    width: parent.width
                    height: 44
                    radius: 22
                    color: Theme.withAlpha(pal.raised, pal.light ? 0.85 : 0.7)
                    border.width: 1
                    border.color: pal.line
                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        Repeater {
                            model: root.ancModes
                            Rectangle {
                                required property var modelData
                                readonly property bool on: modelData.id === root.ancMode
                                width: (parent.width) / root.ancModes.length
                                height: parent.height
                                radius: height / 2
                                color: on ? pal.accent : "transparent"
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.icon
                                        size: 17
                                        color: parent.parent.on ? pal.onAccent : pal.muted
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: parent.parent.on
                                        text: modelData.label
                                        color: pal.onAccent
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.weight: Font.DemiBold
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.modeRequested(modelData.id)
                                }
                            }
                        }
                    }
                }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.ancModes.length ? "Noise control" : "Ready to use"
                    color: pal.muted
                    font.pixelSize: Theme.fontSizeSmall - 1
                }
            }
        }

        // --- Main button ---------------------------------------------------------------
        Rectangle {
            id: mainButton
            x: 16
            y: 420
            width: card.width - 32
            height: 50
            radius: 25
            readonly property bool quiet: root.busy
            color: quiet ? Theme.withAlpha(pal.accent, 0.16) : pal.accent
            gradient: quiet ? null : shine
            Gradient {
                id: shine
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: pal.accent
                }
                GradientStop {
                    position: 1
                    color: Qt.tint(pal.accent, Theme.withAlpha(pal.accent2, 0.45))
                }
            }

            // Progress while pairing and connecting
            Rectangle {
                visible: root.busy
                height: parent.height
                radius: parent.radius
                width: parent.width * (root.phase === "pairing" ? 0.38 : 0.72)
                color: Theme.withAlpha(pal.accent, 0.4)
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
                    color: mainButton.quiet ? pal.text : pal.onAccent
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
                    color: mainButton.quiet ? pal.text : pal.onAccent
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

        // --- Quiet actions ----------------------------------------------------------------
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
                color: quietArea.containsMouse ? pal.text : pal.muted
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
                color: pal.muted
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
            color: Theme.withAlpha(pal.muted, 0.7)
            font.pixelSize: Theme.fontSizeSmall - 3
        }
    }
}
