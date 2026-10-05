import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../common"
import "../together/Delay.js" as Delay

// The wired delay (D298): nudges the automatic wait that lines the wired
// outputs up with the Bluetooth ones. A slider from -100 to +100 ms in steps of
// 5, the value in force, a one-click reset and a link to the guide. It never
// moves by itself: nothing is saved while it loads, and a gesture saves once,
// when it ends, so Listen together is not planned again at every notch. A
// change made elsewhere (`dms ipc call orbitBluetooth wiredDelay`) moves the
// slider too.
Column {
    id: row

    required property PluginSettings settings

    readonly property string settingKey: "togetherFineDelay"
    // The saved correction (ms), always within Delay.cleanFine's range
    property int value: 0

    function load() {
        if (settings.pluginService)
            value = Delay.cleanFine(Number(settings.loadValue(settingKey, 0)));
    }
    function save(ms) {
        value = Delay.cleanFine(ms);
        settings.saveValue(settingKey, value);
    }

    width: parent ? parent.width : 0
    spacing: Theme.spacingS

    // The service is handed over after the page is built: read on the next turn
    Component.onCompleted: Qt.callLater(load)
    Connections {
        target: row.settings.pluginService
        enabled: row.settings.pluginService !== null

        function onPluginDataChanged(pluginId) {
            if (pluginId === row.settings.pluginId)
                row.load();
        }
    }

    Item {
        width: parent.width
        height: reset.height

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Wired delay"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            // Only once there is something to give back
            ActionButton {
                id: reset
                visible: row.value !== 0
                text: "Reset to 0"
                onClicked: row.save(0)
            }
            // The value follows the thumb while it is dragged. Its width is
            // that of the longest it can be, so nothing moves as it changes
            StyledText {
                id: shown
                width: widest.width
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.NoWrap
                text: Delay.fineText(slider.value)
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: slider.value === 0 ? Theme.surfaceVariantText : Theme.primary
            }
            GuideLink {
                anchor: "wired-delay"
                anchors.verticalCenter: parent.verticalCenter
                size: 14
                color: Theme.surfaceVariantText
                hoverColor: Theme.surfaceText
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Nudge the automatic wait that lines up wired outputs with Bluetooth ones"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    DankSlider {
        id: slider
        width: parent.width
        minimum: -Delay.MAX_FINE_MS
        maximum: Delay.MAX_FINE_MS
        step: Delay.FINE_STEP_MS
        // The value is shown above, not in a tooltip; the wheel scrolls the page
        showValue: false
        wheelEnabled: false
        // A click on the thumb that moves nothing saves nothing
        onSliderDragFinished: ms => {
            if (ms !== row.value)
                row.save(ms);
        }
    }
    // A drag breaks a plain `value:` binding of the slider, and a reset or a
    // change from outside must still move it
    Binding {
        target: slider
        property: "value"
        value: row.value
    }

    TextMetrics {
        id: widest
        font: shown.font
        text: Delay.fineText(-Delay.MAX_FINE_MS)
    }
}
