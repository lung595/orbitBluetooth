import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "components"
import "components/DeviceCatalog.js" as Catalog

// Bar pill + bar popout + Control Center tile. The Control Center detail is a
// fresh instance created when the tile expands and destroyed when it
// collapses, so scanning and animation live exactly as long as the panel.
PluginComponent {
    id: root

    // Devices hidden in the black hole are left out here too
    readonly property var hiddenDevices: pluginData.hiddenDevices ?? ({})
    readonly property var connectedDevices: {
        const all = BluetoothService.adapter?.devices?.values ?? [];
        return all.filter(d => d && d.connected && hiddenDevices[d.address] === undefined);
    }
    readonly property var overrides: pluginData.glyphOverrides ?? ({})

    // --- Control Center -------------------------------------------------------
    ccWidgetIcon: !BluetoothService.enabled ? "bluetooth_disabled" : connectedDevices.length > 0 ? "bluetooth_connected" : "bluetooth"
    ccWidgetPrimaryText: "Bluetooth"
    ccWidgetSecondaryText: {
        if (!BluetoothService.available)
            return "Unavailable";
        if (!BluetoothService.enabled)
            return "Off";
        const n = connectedDevices.length;
        if (n === 0)
            return "No devices";
        if (n === 1)
            return Catalog.deviceName(connectedDevices[0]);
        return n + " devices";
    }
    ccWidgetIsActive: BluetoothService.enabled
    ccDetailHeight: 314   // 440 / 1.4: compact when the Control Center opens

    onCcWidgetToggled: BluetoothService.toggleBluetooth()

    ccDetailContent: Component {
        Rectangle {
            radius: Theme.cornerRadius
            color: "#07080c"
            clip: true

            OrbitScene {
                anchors.fill: parent
                active: true
                cornerRadius: Theme.cornerRadius
            }
        }
    }

    // --- Bar ------------------------------------------------------------------
    component ConnectedStack: Row {
        spacing: -4
        Repeater {
            model: root.connectedDevices.slice(0, 3)
            Rectangle {
                width: root.iconSize + 2
                height: width
                radius: width / 2
                color: Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.withAlpha(Theme.primary, 0.5)
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                DeviceGlyph {
                    anchors.centerIn: parent
                    width: parent.width * 0.64
                    height: width
                    kind: Catalog.resolve(modelData, root.overrides)
                    color: Theme.primary
                    stroke: 1.8
                }
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.ccWidgetIcon
                size: root.iconSize
                color: BluetoothService.enabled ? (root.connectedDevices.length ? Theme.primary : Theme.widgetIconColor ?? Theme.surfaceText) : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.connectedDevices.length === 0
            }
            ConnectedStack {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.connectedDevices.length > 0
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            DankIcon {
                name: root.ccWidgetIcon
                size: root.iconSize
                color: root.connectedDevices.length ? Theme.primary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                visible: root.connectedDevices.length > 0
                text: root.connectedDevices.length
                color: Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    pillRightClickAction: () => BluetoothService.toggleBluetooth()

    popoutWidth: 520
    popoutHeight: 440

    popoutContent: Component {
        Item {
            id: pop
            property var parentPopout: null
            width: parent ? parent.width : 0
            implicitHeight: root.popoutHeight

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: "#07080c"
                clip: true

                OrbitScene {
                    anchors.fill: parent
                    cornerRadius: Theme.cornerRadius
                    // The popout keeps its content loaded; only run while shown
                    active: pop.parentPopout ? pop.parentPopout.shouldBeVisible : true
                }
            }
        }
    }
}
