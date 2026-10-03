import QtQuick
import qs.Common
import qs.Widgets
import "../common"
import "../volume"

// What the volume keys do, with the button that binds them to Orbit's
// smart steps or gives them back to DMS, and a link to the guide
Row {
    width: parent.width
    spacing: Theme.spacingM

    // The volume keys (D265): bound to Orbit on the user's click only,
    // through DMS's own keybind command; read when this page opens
    VolumeKeys {
        id: keyBinder
        visible: false
        Component.onCompleted: refresh()
    }

    StyledText {
        width: parent.width - (keysButton.visible ? keysButton.width + parent.spacing : 0) - keysLink.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: keyBinder.failed ? Theme.error : Theme.surfaceVariantText
        text: {
            if (keyBinder.failed)
                return "Could not change the volume keys. The guide shows how to bind them by hand";
            switch (keyBinder.keys) {
            case "dms":
                return "Volume keys: DMS's own steps. Smart steps apply to them only once they are bound to Orbit";
            case "orbit":
                return "Volume keys: Orbit's smart steps. If Orbit is turned off they fall back to DMS's steps";
            case "custom":
                return "Volume keys: a shortcut of your own, left as it is. For smart steps, bind them to dms ipc call orbitBluetooth volume up or down";
            case "unsupported":
                return "For smart steps on the volume keys, bind them to dms ipc call orbitBluetooth volume up or down (done for you on niri only)";
            default:
                return "Reading the volume keys…";
            }
        }
    }

    ActionButton {
        id: keysButton
        anchors.verticalCenter: parent.verticalCenter
        visible: !keyBinder.busy && (keyBinder.keys === "dms" || keyBinder.keys === "orbit")
        text: keyBinder.keys === "orbit" ? "Give back to DMS" : "Use smart steps"
        onClicked: keyBinder.keys === "orbit" ? keyBinder.disable() : keyBinder.enable()
    }

    GuideLink {
        id: keysLink
        anchors.verticalCenter: parent.verticalCenter
        anchor: "volume-keys"
        size: 14
        color: Theme.surfaceVariantText
        hoverColor: Theme.surfaceText
    }
}
