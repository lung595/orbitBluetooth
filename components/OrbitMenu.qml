import QtQuick
import qs.Common
import qs.Widgets
import "Anc.js" as Anc

// Right-click menu of an orbiting device: connect/disconnect, the headset's
// noise-control modes when it has them, and "Hide" (into the black hole).
// It lives inside the scene (no extra window) and closes on any choice,
// a click elsewhere or Escape.
Item {
    id: menu
    readonly property NightColors night: NightColors {}

    required property var scene
    property var body: null
    readonly property bool open: !!body

    readonly property var entries: {
        const b = body;
        if (!b)
            return [];
        const list = [];
        if (b.device)
            list.push(b.phase === "connecting" ? {
                "id": "cancel",
                "icon": "close",
                "label": "Cancel"
            } : b.connected ? {
                "id": "disconnect",
                "icon": "link_off",
                "label": "Disconnect"
            } : {
                "id": "connect",
                "icon": "link",
                "label": "Connect"
            });
        if (b.ancCapable) {
            const info = scene.ancFor(b.address);
            const modes = Anc.ordered(info?.features?.modes);
            for (const m of modes)
                list.push({
                    "id": "anc:" + m,
                    "icon": Anc.ICONS[m],
                    "label": Anc.SHORT[m],
                    "checked": info?.state?.mode === m
                });
        }
        list.push({
            "id": "hide",
            "icon": "visibility_off",
            "label": "Hide"
        });
        return list;
    }

    function popup(b, point) {
        body = b;
        // Keep the menu inside the scene
        panel.x = Math.max(8, Math.min(point.x, scene.width - panel.width - 8));
        panel.y = Math.max(8, Math.min(point.y, scene.height - panel.height - 8));
        if (b.ancCapable)
            scene.ancWatch(b.address, true);   // fetch the current mode
        _watching = b.ancCapable ? b.address : "";
        scene.forceActiveFocus();
    }

    property string _watching: ""
    function close() {
        if (_watching)
            scene.ancWatch(_watching, false);
        _watching = "";
        body = null;
    }

    function choose(id) {
        const b = body;
        close();
        if (!b)
            return;
        if (id === "connect")
            scene.startConnect(b);
        else if (id === "disconnect")
            scene.startDisconnect(b);
        else if (id === "cancel")
            scene.cancelConnect(b);
        else if (id === "hide")
            scene.hideBody(b);
        else if (id.startsWith("anc:"))
            scene.ancSend(b.address, "mode", id.slice(4));
    }

    anchors.fill: parent
    visible: open

    // Click anywhere else closes it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: menu.close()
    }

    Rectangle {
        id: panel
        width: 168
        height: menu.entries.length * 32 + 10   // known before layout, for placement
        radius: 14
        color: Qt.rgba(0.075, 0.08, 0.095, 0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        transformOrigin: Item.TopLeft
        scale: menu.open ? 1 : 0.92
        opacity: menu.open ? 1 : 0
        Behavior on scale {
            enabled: menu.scene.motion
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: col
            x: 5
            y: 5
            width: parent.width - 10

            Repeater {
                model: menu.entries

                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool danger: modelData.id === "hide"
                    width: col.width
                    height: 32
                    radius: 10
                    color: itemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                    // A hairline before "Hide" and before the first mode
                    Rectangle {
                        visible: index > 0 && (modelData.id === "hide" || (modelData.id.startsWith("anc:") && !menu.entries[index - 1].id.startsWith("anc:")))
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.07)
                    }
                    DankIcon {
                        id: icon
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.icon
                        size: 16
                        color: modelData.checked ? menu.night.primary : Qt.rgba(1, 1, 1, 0.75)
                    }
                    StyledText {
                        anchors.left: icon.right
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.checked ? menu.night.primary : "#F2F5EE"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: modelData.checked ? Font.DemiBold : Font.Normal
                    }
                    DankIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.checked ?? false
                        name: "check"
                        size: 14
                        color: menu.night.primary
                    }
                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.choose(modelData.id)
                    }
                }
            }
        }
    }
}
