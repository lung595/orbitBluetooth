import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Widgets

// The "new device nearby" card, shown in its own window under the bar by
// NewDeviceWatch. Pure visuals: the watcher owns the state and the actions.
//
// Choreography: the card drops from the bar, then the device falls out of
// the bar along a comet trail, is caught by the orbit ring with a flash and
// sends sonar rings while it waits. The halo takes the colour of the
// device's picture (or the theme accent). A thin line at the bottom runs
// down while nobody answers; it stops while the pointer is over the card.
Item {
    id: root

    // "offer", "pairing", "connecting", "done" or "failed"
    property string phase: "offer"
    property string name: ""
    property string kind: "headphonesSlim"
    property string headline: "New headphones nearby"
    property url pictureSource: ""
    property string credit: ""
    property int battery: -1
    // 1 -> 0 while the offer waits for an answer
    property real life: 1
    property bool shown: false
    property bool reduceMotion: false

    signal accepted
    signal later
    signal ignored
    signal retry
    signal cancelled

    readonly property bool hovered: hover.hovered
    // The window's input region: clicks around the card go through
    readonly property Item card: card
    readonly property bool busy: phase === "pairing" || phase === "connecting"

    implicitWidth: 480
    implicitHeight: 196

    NightColors {
        id: night
    }

    // --- Halo colour -------------------------------------------------------------
    // Average of the picture's coloured pixels, lifted so it glows on the
    // night sky. Black or white products have no colour: the accent is used.
    property color halo: probe.found.a > 0 ? Qt.hsla(probe.found.hslHue, Math.max(probe.found.hslSaturation, 0.5), Math.max(probe.found.hslLightness, 0.68), 1) : night.primary
    // Dark text on a halo-coloured button
    readonly property color haloInk: Qt.hsla(halo.hslHue, Math.min(halo.hslSaturation, 0.6), 0.13, 1)

    Behavior on halo {
        ColorAnimation {
            duration: 600
        }
    }

    Canvas {
        id: probe
        // Painted but not shown: a hidden Canvas never paints
        width: 12
        height: 12
        opacity: 0
        property color found: "transparent"
        property url src: root.pictureSource

        onSrcChanged: {
            found = "transparent";
            if (src != "")
                loadImage(src);
        }
        onImageLoaded: requestPaint()
        onPaint: {
            if (src == "" || !isImageLoaded(src))
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(src, 0, 0, width, height);
            const px = ctx.getImageData(0, 0, width, height).data;
            let r = 0, g = 0, b = 0, total = 0;
            for (let i = 0; i < px.length; i += 4) {
                const c = Qt.rgba(px[i] / 255, px[i + 1] / 255, px[i + 2] / 255, 1);
                // Saturated mid tones count, backgrounds and shadows do not
                const w = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 2) * (px[i + 3] / 255);
                r += c.r * w;
                g += c.g * w;
                b += c.b * w;
                total += w;
            }
            found = total > 4 ? Qt.rgba(r / total, g / total, b / total, 1) : "transparent";
        }
    }

    // --- Card --------------------------------------------------------------------
    Item {
        id: card
        width: 440
        height: 134
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? 14 : -18
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.94
        transformOrigin: Item.Top

        Behavior on y {
            NumberAnimation {
                duration: root.reduceMotion ? 0 : 520
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 260
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.reduceMotion ? 0 : 520
                easing.type: Easing.OutBack
            }
        }

        HoverHandler {
            id: hover
        }

        // Body: a piece of the night sky, with a soft drop shadow
        Rectangle {
            id: body
            anchors.fill: parent
            radius: Theme.cornerRadius * 2
            border.width: 1
            border.color: Theme.withAlpha(root.halo, 0.32)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.tint(night.sky, Theme.withAlpha(root.halo, 0.07))
                }
                GradientStop {
                    position: 1
                    color: night.skyDeep
                }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.6)
                shadowBlur: 0.9
                shadowVerticalOffset: 6
            }
        }

        // Everything that must stay inside the rounded card
        Item {
            id: inside
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: insideMask
            }

            // A few stars, fixed so the card looks the same every time
            Repeater {
                model: 18
                Rectangle {
                    readonly property real h1: (index * 0.6180339 + 0.13) % 1
                    readonly property real h2: (index * 0.4142135 + 0.57) % 1
                    x: 130 + h1 * (inside.width - 136)
                    y: 4 + h2 * (inside.height - 8)
                    width: index % 5 === 0 ? 2 : 1.2
                    height: width
                    radius: width / 2
                    color: night.ink(1)
                    opacity: 0.12 + 0.25 * h2
                    SequentialAnimation on opacity {
                        running: root.shown && !root.reduceMotion
                        loops: Animation.Infinite
                        PauseAnimation {
                            duration: 900 + index * 170
                        }
                        NumberAnimation {
                            to: 0.55
                            duration: 700
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 0.12
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            // Halo behind the device
            Shape {
                id: haloShape
                width: 190
                height: 190
                x: visual.cx - width / 2
                y: visual.cy - height / 2
                opacity: 0.8 * visual.arrived
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: 95
                        centerY: 95
                        centerRadius: 95
                        focalX: 95
                        focalY: 95
                        GradientStop {
                            position: 0
                            color: Theme.withAlpha(root.halo, 0.55)
                        }
                        GradientStop {
                            position: 0.45
                            color: Theme.withAlpha(root.halo, 0.14)
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                    PathAngleArc {
                        centerX: 95
                        centerY: 95
                        radiusX: 95
                        radiusY: 95
                        sweepAngle: 360
                    }
                }
                SequentialAnimation on scale {
                    running: root.shown && !root.reduceMotion
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0.94
                        to: 1.06
                        duration: 2200
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 1.06
                        to: 0.94
                        duration: 2200
                        easing.type: Easing.InOutSine
                    }
                }
            }

            // Runs down while the offer waits for an answer
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 2
                width: parent.width * root.life
                color: Theme.withAlpha(root.halo, 0.7)
                visible: root.phase === "offer"
            }
        }

        Rectangle {
            id: insideMask
            anchors.fill: parent
            radius: body.radius
            visible: false
            layer.enabled: true
        }

        // --- The device in its orbit -----------------------------------------
        Item {
            id: visual
            width: 132
            height: parent.height
            readonly property real cx: 70
            readonly property real cy: height / 2
            // 0 -> 1: the fall out of the bar into the orbit
            property real p: 0
            // 0 -> 1 once caught, for what only exists in orbit
            property real arrived: 0
            // Where the device comes from: above the card, out of the bar
            readonly property real sx: 170
            readonly property real sy: -150
            // Control point of the curve: it swings past and is pulled back
            readonly property real kx: -110
            readonly property real ky: -10

            function along(t) {
                const u = 1 - t;
                return Qt.point(u * u * sx + 2 * u * t * kx, u * u * sy + 2 * u * t * ky);
            }

            // Orbit ring, tilted, with a small moon that passes behind the device
            Item {
                id: orbit
                x: visual.cx
                y: visual.cy
                rotation: -16
                opacity: visual.arrived
                property real angle: 0
                readonly property real rx: 54
                readonly property real ry: 17
                NumberAnimation on angle {
                    running: root.shown && !root.reduceMotion
                    from: 0
                    to: 2 * Math.PI
                    duration: 5200
                    loops: Animation.Infinite
                }
                Rectangle {
                    x: -orbit.rx
                    y: -orbit.ry
                    width: orbit.rx * 2
                    height: orbit.ry * 2
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.withAlpha(root.halo, 0.35)
                }
                Rectangle {
                    readonly property bool behind: Math.sin(orbit.angle) < 0
                    width: 6
                    height: 6
                    radius: 3
                    x: orbit.rx * Math.cos(orbit.angle) - 3
                    y: orbit.ry * Math.sin(orbit.angle) - 3
                    z: behind ? -1 : 2
                    opacity: behind ? 0.35 : 1
                    color: root.halo
                }
            }

            // Sonar rings while it waits, faster while connecting
            Repeater {
                model: 3
                Rectangle {
                    id: ring
                    width: 64
                    height: 64
                    radius: 32
                    x: visual.cx - 32
                    y: visual.cy - 32
                    color: "transparent"
                    border.width: 1.5
                    border.color: root.halo
                    opacity: 0
                    readonly property int period: root.busy ? 1500 : 2700
                    SequentialAnimation {
                        running: root.shown && visual.arrived >= 1 && !root.reduceMotion && root.phase !== "done" && root.phase !== "failed"
                        loops: Animation.Infinite
                        onStopped: ring.opacity = 0
                        PauseAnimation {
                            duration: index * ring.period / 3
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: ring
                                property: "scale"
                                from: 1
                                to: 2.2
                                duration: ring.period
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: ring
                                property: "opacity"
                                from: 0.5
                                to: 0
                                duration: ring.period
                                easing.type: Easing.OutQuad
                            }
                        }
                        PauseAnimation {
                            duration: (2 - index) * ring.period / 3
                        }
                    }
                }
            }

            // Comet trail: ghosts of where the device just was
            Repeater {
                model: 9
                Rectangle {
                    readonly property real t: Math.max(0, visual.p - (index + 1) * 0.045)
                    readonly property point at: visual.along(t)
                    width: 26 - index * 2.4
                    height: width
                    radius: width / 2
                    x: visual.cx + at.x - width / 2
                    y: visual.cy + at.y - height / 2
                    color: root.halo
                    opacity: visual.p > 0 && visual.p < 1 ? (0.34 - index * 0.035) * Math.min(1, (1 - visual.p) * 4) : 0
                }
            }

            // Flash when the orbit catches it
            Rectangle {
                id: flash
                width: 64
                height: 64
                radius: 32
                x: visual.cx - 32
                y: visual.cy - 32
                color: "transparent"
                border.width: 1.5
                border.color: root.halo
                opacity: 0
            }

            // The device itself
            Rectangle {
                id: disc
                readonly property point at: visual.along(visual.p)
                width: 64
                height: 64
                radius: 32
                x: visual.cx + at.x - 32
                y: visual.cy + at.y - 32
                scale: 0.4 + 0.6 * visual.p
                opacity: Math.min(1, visual.p * 3)
                color: Qt.tint(night.sky, Theme.withAlpha(root.halo, 0.16))
                border.width: 1
                border.color: Theme.withAlpha(root.halo, 0.65)

                DeviceGlyph {
                    id: glyph
                    anchors.centerIn: parent
                    width: pictureShown ? parent.width - 2 : parent.width * 0.56
                    height: width
                    kind: root.kind
                    pictureSource: root.pictureSource
                    color: Qt.lighter(root.halo, 1.1)
                    stroke: 1.5
                }
            }

            // Connected: a check badge on the disc
            Rectangle {
                width: 22
                height: 22
                radius: 11
                x: visual.cx + 14
                y: visual.cy + 12
                color: root.halo
                scale: root.phase === "done" ? 1 : 0
                Behavior on scale {
                    NumberAnimation {
                        duration: 380
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.2
                    }
                }
                DankIcon {
                    anchors.centerIn: parent
                    name: "check"
                    size: 15
                    color: root.haloInk
                }
            }

            SequentialAnimation {
                id: fall
                PauseAnimation {
                    duration: 180
                }
                NumberAnimation {
                    target: visual
                    property: "p"
                    from: 0
                    to: 1
                    duration: 1050
                    easing.type: Easing.OutCubic
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: flash
                        property: "scale"
                        from: 1
                        to: 1.9
                        duration: 520
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: flash
                        property: "opacity"
                        from: 0.9
                        to: 0
                        duration: 520
                    }
                    NumberAnimation {
                        target: visual
                        property: "arrived"
                        from: 0
                        to: 1
                        duration: 600
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: disc
                            property: "scale"
                            to: 1.12
                            duration: 120
                        }
                        NumberAnimation {
                            target: disc
                            property: "scale"
                            to: 1
                            duration: 260
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }
        }

        // --- Text and actions -------------------------------------------------
        Column {
            anchors.left: visual.right
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingL
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            spacing: 3

            StyledText {
                text: root.headline.toUpperCase()
                color: Theme.withAlpha(root.halo, 0.9)
                font.pixelSize: Theme.fontSizeSmall - 2
                font.weight: Font.DemiBold
                font.letterSpacing: 1.3
            }
            StyledText {
                width: parent.width
                text: root.name
                color: night.ink(0.96)
                font.pixelSize: Theme.fontSizeLarge + 4
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            StyledText {
                width: parent.width
                text: {
                    switch (root.phase) {
                    case "pairing":
                        return "Pairing…";
                    case "connecting":
                        return "Connecting…";
                    case "done":
                        return root.battery >= 0 ? "Connected · battery " + root.battery + "%" : "Connected";
                    case "failed":
                        return "Could not connect. Is it still in pairing mode?";
                    }
                    return "In pairing mode, ready to connect";
                }
                color: root.phase === "failed" ? night.error : night.ink(0.6)
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            Item {
                width: 1
                height: Theme.spacingXS
            }

            Row {
                spacing: Theme.spacingS

                component Pill: Rectangle {
                    id: pill
                    property string label: ""
                    property string icon: ""
                    property bool primary: false
                    property bool working: false
                    signal clicked
                    width: pillRow.implicitWidth + Theme.spacingL * 2
                    height: 30
                    radius: height / 2
                    color: primary ? (pillArea.containsMouse ? Qt.lighter(root.halo, 1.08) : root.halo) : pillArea.containsMouse ? night.ink(0.14) : night.ink(0.07)
                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                    // Working: a sheen sweeps across the pill
                    Rectangle {
                        id: sheen
                        visible: pill.working
                        width: pill.width * 0.4
                        height: pill.height
                        radius: pill.radius
                        opacity: 0.35
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: "transparent"
                            }
                            GradientStop {
                                position: 0.5
                                color: night.ink(1)
                            }
                            GradientStop {
                                position: 1
                                color: "transparent"
                            }
                        }
                        NumberAnimation on x {
                            running: pill.working && !root.reduceMotion
                            from: -sheen.width
                            to: pill.width
                            duration: 1100
                            loops: Animation.Infinite
                        }
                    }
                    Row {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 5
                        DankIcon {
                            visible: pill.icon !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            name: pill.icon
                            size: 16
                            color: pill.primary ? root.haloInk : night.ink(0.85)
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pill.label
                            color: pill.primary ? root.haloInk : night.ink(0.85)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: pill.primary ? Font.DemiBold : Font.Normal
                        }
                    }
                    MouseArea {
                        id: pillArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !pill.working
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.clicked()
                    }
                }

                Pill {
                    visible: root.phase === "offer"
                    primary: true
                    icon: "bluetooth"
                    label: "Connect"
                    onClicked: root.accepted()
                }
                Pill {
                    visible: root.busy
                    primary: true
                    working: true
                    icon: "bluetooth_searching"
                    label: root.phase === "pairing" ? "Pairing" : "Connecting"
                }
                Pill {
                    visible: root.phase === "failed"
                    primary: true
                    icon: "refresh"
                    label: "Try again"
                    onClicked: root.retry()
                }
                Pill {
                    visible: root.phase === "offer"
                    label: "Later"
                    onClicked: root.later()
                }
                Pill {
                    visible: root.busy
                    label: "Cancel"
                    onClicked: root.cancelled()
                }
                Pill {
                    visible: root.phase === "failed" || root.phase === "done"
                    label: root.phase === "done" ? "Done" : "Close"
                    onClicked: root.later()
                }
                Pill {
                    visible: root.phase === "offer"
                    icon: "notifications_off"
                    label: "Ignore"
                    onClicked: root.ignored()
                }
            }
        }

        // Credit of a downloaded picture: its license asks for it
        StyledText {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Theme.spacingL
            anchors.bottomMargin: 5
            width: parent.width - visual.width - Theme.spacingL
            horizontalAlignment: Text.AlignRight
            visible: root.credit !== "" && root.phase === "offer"
            text: "Picture " + root.credit
            elide: Text.ElideLeft
            color: night.ink(0.3)
            font.pixelSize: Theme.fontSizeSmall - 3
        }
    }

    // The device falls in once the card has dropped
    onShownChanged: {
        if (!shown) {
            fall.stop();
            return;
        }
        if (reduceMotion) {
            visual.p = 1;
            visual.arrived = 1;
            return;
        }
        visual.p = 0;
        visual.arrived = 0;
        fall.restart();
    }
}
