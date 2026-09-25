import QtQuick
import qs.Common
import qs.Widgets
import "Charge.js" as Charge

// Battery card: status line, a readout ("72%   25 min left"),
// a matte pill gauge colored by the aurora ramp (red -> aqua) with
// light-speed streaks, a session sparkline and a row of stat tiles.
// While charging the streaks flow like a warp jump. Only render-thread
// animators are used, and they stop whenever `animate` is false.
Rectangle {
    id: root

    property real level: -1            // 0..100, negative when unknown
    property string statusIcon: "bluetooth_connected"
    property string statusText: ""
    property string detailText: ""      // shown only when there is no level
    property string timeValue: ""       // e.g. "1h04"
    property string timeSuffix: ""      // e.g. "left", "to full"
    property bool framed: true          // false when embedded in another card
    property real gaugeRatio: 0.1       // bar height / width
    property bool charging: false
    property bool animate: true
    property var stats: []              // [{ label, value }], up to 3 shown
    property var history: []            // [[epochMs, percent], ...] for the sparkline
    property string footnote: ""
    property bool compact: false        // hides the status line (detail card with ANC)

    readonly property bool hasLevel: level >= 0
    readonly property real frac: Math.max(0, Math.min(1, level / 100))
    readonly property color ink: "#F2F5EE"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.42)
    property color levelColor: Charge.levelColor(level)
    readonly property bool running: charging && animate && visible

    readonly property int bigFontPx: Math.max(18, Math.round(width * 0.075))
    readonly property real pad: framed ? Math.round(width * 0.075) : 0

    implicitHeight: content.implicitHeight + pad * 2
    radius: Math.round(width * 0.09)
    color: framed ? Qt.rgba(1, 1, 1, 0.055) : "transparent"
    border.width: framed ? 1 : 0
    border.color: Qt.rgba(1, 1, 1, 0.06)

    Behavior on levelColor {
        ColorAnimation {
            duration: 700
        }
    }

    Column {
        id: content
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: Math.round(root.width * 0.01)

        Row {
            visible: !root.compact
            spacing: Theme.spacingXS
            DankIcon {
                name: root.statusIcon
                size: title.font.pixelSize + 2
                color: root.charging ? root.levelColor : root.muted
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                id: title
                text: root.statusText
                color: root.muted
                font.pixelSize: Math.max(Theme.fontSizeSmall, Math.round(root.width * 0.045))
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StyledText {
            width: parent.width
            visible: !root.hasLevel && text !== ""
            text: root.detailText
            textFormat: Text.PlainText
            color: root.ink
            elide: Text.ElideRight
            font.pixelSize: Math.max(Theme.fontSizeSmall, Math.round(root.width * 0.052))
            font.weight: Font.Medium
        }

        // Readout: "72%   25 min left" (level in its ramp color)
        Row {
            width: parent.width
            spacing: Math.round(root.width * 0.06)
            visible: root.hasLevel

            StyledText {
                id: bigLevel
                text: Math.round(root.level) + "%"
                color: root.levelColor
                font.pixelSize: root.bigFontPx
                font.weight: Font.DemiBold
            }
            StyledText {
                anchors.baseline: bigLevel.baseline
                visible: root.timeValue !== ""
                text: root.timeValue + (root.timeSuffix ? " " + root.timeSuffix : "")
                color: root.ink
                font.pixelSize: root.bigFontPx
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - bigLevel.width - parent.spacing)
            }
        }

        // Gauge band: taller than the bar so streaks can run above and below
        Item {
            id: gauge
            width: parent.width
            height: Math.round(bar.height * 1.9)
            visible: root.hasLevel
            clip: true

            Item {
                id: bar
                width: parent.width
                height: Math.max(14, Math.round(width * root.gaugeRatio))
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.055)
                }

                // Faint vertical hairlines
                Repeater {
                    model: [0.2, 0.46, 0.63, 0.88]
                    Rectangle {
                        x: bar.width * modelData
                        y: bar.height * 0.2
                        width: 1
                        height: bar.height * 0.6
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }
                }

                // 80% mark while charging (where charging slows down)
                Rectangle {
                    visible: root.charging
                    x: bar.width * 0.8
                    y: bar.height * 0.14
                    width: 1.5
                    height: bar.height * 0.72
                    radius: 1
                    color: Theme.withAlpha(root.levelColor, 0.5)
                }

                // Matte fill: rounded start, flat leading edge (full pill at 100%)
                Item {
                    id: fillClip
                    width: root.frac >= 1 ? bar.width : Math.max(bar.height / 2, bar.width * root.frac)
                    height: bar.height
                    clip: true

                    Behavior on width {
                        NumberAnimation {
                            duration: 700
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        width: root.frac >= 1 ? bar.width : fillClip.width + bar.height
                        height: bar.height
                        radius: bar.height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: Qt.darker(root.levelColor, 1.15)
                            }
                            GradientStop {
                                position: 0.75
                                color: root.levelColor
                            }
                            GradientStop {
                                position: 1
                                color: Qt.lighter(root.levelColor, 1.05)
                            }
                        }
                    }
                }
            }

            // Streaks: static accents at rest, a warp flow while charging.
            // [y (band fraction), x, length (width fractions), alpha, thickness]
            Repeater {
                model: [[0.07, 0.12, 0.3, 0.3, 2], [0.3, 0.1, 0.18, 0.55, 2], [0.42, 0.34, 0.26, 0.4, 1.5], [0.5, 0.03, 0.1, 0.3, 1.5], [0.58, 0.22, 0.34, 0.45, 2], [0.66, 0.66, 0.14, 0.3, 1.5], [0.8, 0.52, 0.2, 0.4, 2], [0.94, 0.26, 0.42, 0.26, 2.5], [0.22, 0.74, 0.12, 0.25, 1.5]]

                Rectangle {
                    id: streak
                    readonly property real len: gauge.width * modelData[2]
                    x: gauge.width * modelData[1]
                    y: gauge.height * modelData[0] - height / 2
                    width: len
                    height: modelData[4]
                    radius: height / 2
                    opacity: modelData[3]
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Qt.rgba(1, 1, 1, 0)
                        }
                        GradientStop {
                            position: 0.6
                            color: Qt.lighter(root.levelColor, 1.35)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(1, 1, 1, 0)
                        }
                    }

                    XAnimator on x {
                        running: root.running
                        from: -streak.len
                        to: gauge.width
                        duration: 1100 + (index % 4) * 380
                        loops: Animation.Infinite
                    }
                }
            }
        }

        // Session sparkline: the level over this connection
        Item {
            width: parent.width
            height: visible ? Math.round(root.width * 0.06) + 4 : 0
            visible: root.hasLevel && (root.history || []).length >= 2

            Canvas {
                id: spark
                anchors.fill: parent
                anchors.topMargin: 4
                renderStrategy: Canvas.Cooperative
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: root
                    function onHistoryChanged() {
                        spark.requestPaint();
                    }
                    function onLevelColorChanged() {
                        spark.requestPaint();
                    }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const pts = root.history || [];
                    if (pts.length < 2 || width <= 0)
                        return;
                    const t0 = pts[0][0], t1 = Math.max(t0 + 1, pts[pts.length - 1][0]);
                    let lo = 100, hi = 0;
                    for (const p of pts) {
                        lo = Math.min(lo, p[1]);
                        hi = Math.max(hi, p[1]);
                    }
                    lo = Math.max(0, lo - 5);
                    hi = Math.min(100, hi + 5);
                    const X = t => (t - t0) / (t1 - t0) * (width - 4) + 2;
                    const Y = v => height - 2 - (v - lo) / Math.max(1, hi - lo) * (height - 4);
                    const c = root.levelColor;

                    ctx.beginPath();
                    ctx.moveTo(X(pts[0][0]), Y(pts[0][1]));
                    for (let i = 1; i < pts.length; i++) {
                        // Step shape: levels are reported in discrete jumps
                        ctx.lineTo(X(pts[i][0]), Y(pts[i - 1][1]));
                        ctx.lineTo(X(pts[i][0]), Y(pts[i][1]));
                    }
                    ctx.lineWidth = 1.2;
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.7);
                    ctx.stroke();

                    ctx.lineTo(X(t1), height);
                    ctx.lineTo(X(t0), height);
                    ctx.closePath();
                    const g = ctx.createLinearGradient(0, 0, 0, height);
                    g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.16));
                    g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                    ctx.fillStyle = g;
                    ctx.fill();
                }
            }
        }

        // Stat tiles
        Row {
            id: tiles
            readonly property var items: (root.stats || []).slice(0, 3)
            visible: items.length > 0
            width: parent.width
            topPadding: Math.round(root.width * 0.015)
            spacing: Theme.spacingXS

            Repeater {
                model: tiles.items
                Rectangle {
                    width: (tiles.width - tiles.spacing * (tiles.items.length - 1)) / tiles.items.length
                    height: tileCol.implicitHeight + 10
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.045)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)

                    Column {
                        id: tileCol
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 1
                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.label
                            color: root.muted
                            elide: Text.ElideRight
                            font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2)
                            font.letterSpacing: 0.4
                        }
                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.value
                            color: root.ink
                            elide: Text.ElideRight
                            font.family: "monospace"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.footnote
            horizontalAlignment: Text.AlignHCenter
            color: Qt.rgba(1, 1, 1, 0.3)
            font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2)
            elide: Text.ElideRight
        }
    }
}
