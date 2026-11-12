import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Window
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import "../../components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// The README's cover picture (and GitHub's social preview): 1280 x 640, in
// DMS's default theme (Purple), with the real scene at the size the Control
// Center gives it, on made-up devices.
// Usage: QT_SCALE_FACTOR=2 QT_QPA_PLATFORM=offscreen qml -I imports hero.qml -- <out.png>
// (render.sh makes it at twice the size, sharp on HiDPI screens)
Window {
    id: win
    readonly property string out: Qt.application.arguments[Qt.application.arguments.length - 1]
    width: 1280
    height: 640
    visible: true
    color: Theme.surface

    // The Control Center sheet: 8 columns of 64 px tiles with 8 px gaps and
    // 16 px of padding (DMS's CcMetrics at density 0) make it 600 wide, and
    // Orbit's detail is 314 high while no card is open
    readonly property int sheetPadding: 16
    readonly property int ccWidth: 568
    readonly property int ccHeight: 314

    FontLoader {
        id: sans
        source: "file:///usr/share/quickshell/dms/DCommon/assets/fonts/google-sans-flex/GoogleSansFlex.ttf"
    }
    readonly property string family: sans.status === FontLoader.Ready ? sans.name : "Noto Sans"

    Component.onCompleted: {
        // DMS's stock Purple theme (Common/StockThemes.js), the default
        // of a fresh install; tertiary and error are Material's baseline
        Theme.primary = "#D0BCFF";
        Theme.primaryText = "#381E72";
        Theme.secondary = "#CCC2DC";
        Theme.tertiary = "#EFB8C8";
        Theme.error = "#F2B8B5";
        Theme.surface = "#141218";
        Theme.surfaceContainer = "#211F24";
        Theme.surfaceContainerHigh = "#2B292F";
        Theme.surfaceContainerHighest = "#36343A";
        Theme.outline = "#948F99";
        Theme.surfaceText = "#E6E0E9";
        Theme.surfaceVariantText = "#CAC4CF";
        SettingsData.pluginSettings = Object.assign({}, SettingsData.pluginSettings, {
            "hiddenDevices": {
                "3C:8D:20:54:AB:12": "Keychron K3",
                "E8:07:BF:6A:19:D4": "JBL Flip 6"
            },
            "holeStyle": "blackhole"
        });
        Pipewire.playing = true;
        BluetoothService.discovering = true;
        BluetoothService.available = true;
        BluetoothService.enabled = true;
        PluginService.globalVars = State.globals("orbit", Date.now());
    }

    // grabToImage leaves out the window's own colour
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    // A soft glow of the theme behind the sheet
    Rectangle {
        id: glow
        width: 600
        height: 380
        radius: height / 2
        x: sheet.x + sheet.width / 2 - width / 2
        y: sheet.y + sheet.height / 2 - height / 2
        color: "#6750A4"
        opacity: 0.7
        visible: false
    }
    MultiEffect {
        source: glow
        anchors.fill: glow
        autoPaddingEnabled: true
        blurEnabled: true
        blurMax: 64
        blurMultiplier: 4
        blur: 1
        opacity: glow.opacity
    }

    // Faint stars in the margins, always in the same places
    Repeater {
        model: 90
        Rectangle {
            readonly property real r1: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
            readonly property real r2: Math.abs(Math.sin(index * 78.233) * 12543.137) % 1
            readonly property real r3: Math.abs(Math.sin(index * 39.425) * 24634.633) % 1
            x: r1 * win.width
            y: r2 * win.height
            width: r3 > 0.85 ? 2.4 : 1.4
            height: width
            radius: width / 2
            color: Theme.surfaceText
            opacity: 0.12 + r3 * 0.35
        }
    }

    // Three orbits round the sheet, the outer one dashed, with a moon each
    Repeater {
        model: [{ "rx": 420, "ry": 250, "a": 0.16, "dash": false, "moon": 300 },
                { "rx": 560, "ry": 330, "a": 0.11, "dash": true, "moon": 32 },
                { "rx": 720, "ry": 420, "a": 0.07, "dash": false, "moon": 62 }]
        Item {
            id: ring
            anchors.fill: parent
            readonly property real cx: sheet.x + sheet.width / 2
            readonly property real cy: sheet.y + sheet.height / 2
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.withAlpha(Theme.primary, modelData.a)
                    strokeWidth: 1.5
                    strokeStyle: modelData.dash ? ShapePath.DashLine : ShapePath.SolidLine
                    dashPattern: [3, 6]
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: ring.cx
                        centerY: ring.cy
                        radiusX: modelData.rx
                        radiusY: modelData.ry
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }
            Rectangle {
                readonly property real t: modelData.moon * Math.PI / 180
                width: 10
                height: 10
                radius: 5
                x: ring.cx + modelData.rx * Math.cos(t) - 5
                y: ring.cy + modelData.ry * Math.sin(t) - 5
                color: Theme.primary
                opacity: modelData.a * 4
            }
        }
    }

    // Left: what it is, in a few words
    Column {
        id: pitch
        x: 80
        anchors.verticalCenter: parent.verticalCenter
        width: 500
        spacing: 0

        Rectangle {
            width: chipRow.width + 28
            height: 34
            radius: height / 2
            color: Theme.withAlpha(Theme.primary, 0.14)
            border.color: Theme.withAlpha(Theme.primary, 0.28)
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 8
                DankIcon {
                    name: "extension"
                    size: 18
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Plugin for DankMaterialShell"
                    color: Theme.primary
                    font.family: win.family
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item { width: 1; height: 22 }

        Text {
            text: "Orbit <font color='" + Theme.surfaceText + "'>Bluetooth</font>"
            textFormat: Text.StyledText
            color: Theme.primary
            font.family: win.family
            font.pixelSize: 64
            font.weight: Font.Bold
            font.letterSpacing: -1.2
        }

        Item { width: 1; height: 12 }

        Text {
            width: parent.width
            text: "Your devices orbit your computer. Drag one to the center to connect it, pull it away to disconnect it."
            wrapMode: Text.WordWrap
            color: Theme.surfaceVariantText
            font.family: win.family
            font.pixelSize: 20
            lineHeight: 1.25
        }

        Item { width: 1; height: 32 }

        Column {
            spacing: 14
            Repeater {
                model: [{ "icon": "battery_charging_full", "text": "Battery and live charging at a glance" },
                        { "icon": "noise_control_on", "text": "Noise control for 13 headphone brands" },
                        { "icon": "speaker_group", "text": "Listen together on up to four outputs" },
                        { "icon": "volume_up", "text": "The device's volume and this PC's, side by side" }]
                Row {
                    spacing: 14
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: Theme.withAlpha(Theme.primary, 0.14)
                        DankIcon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: 19
                            color: Theme.primary
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        color: Theme.surfaceText
                        font.family: win.family
                        font.pixelSize: 17
                    }
                }
            }
        }

        Item { width: 1; height: 34 }

        Row {
            spacing: 8
            DankIcon {
                name: "shield_lock"
                size: 17
                color: Theme.outline
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "No network, no telemetry  ·  Free and open source, MIT"
                color: Theme.outline
                font.family: win.family
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Right: the Control Center sheet with Orbit's detail open, at real size
    RectangularShadow {
        anchors.fill: sheet
        radius: sheet.radius
        blur: 48
        spread: 0
        offset.y: 18
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    Rectangle {
        id: sheet
        x: 640
        anchors.verticalCenter: parent.verticalCenter
        width: win.ccWidth + 2 * win.sheetPadding
        height: win.ccHeight + 2 * win.sheetPadding
        radius: 20
        color: Theme.surfaceContainer
        border.color: Theme.withAlpha(Theme.outline, 0.22)

        Rectangle {
            id: view
            x: win.sheetPadding
            y: win.sheetPadding
            width: win.ccWidth
            height: win.ccHeight
            radius: Theme.cornerRadius
            color: "#07080c"
            clip: true

            OrbitScene {
                id: scene
                anchors.fill: parent
                active: true
                autoScan: false
                previewDevices: Devices.list(false, 0)
                audioRoute: fakeRoute
                foldVolume: true
                cornerRadius: Theme.cornerRadius
            }
        }
    }

    FakeRoute {
        id: fakeRoute
        focusDevice: scene.focusBody ? scene.focusBody.device : null
    }

    Timer {
        interval: 2700
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
