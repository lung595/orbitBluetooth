import QtQuick
import qs.Common
import qs.Widgets
import "../card"
import "../noise/Anc.js" as Anc

// Right-click menu of an orbiting device: connect/disconnect, the headset's
// noise-control modes when it has them, "Stop together" for a device that
// listens together with another, "Hide" (into the black hole) and
// "Forget" (unpair), which asks for a second click.
// It lives inside the scene (no extra window) and closes on any choice,
// a click elsewhere or Escape.
Item {
    id: menu
    readonly property PaperColors paper: PaperColors {}

    required property var scene
    property var body: null
    readonly property bool open: !!body
    // "Forget" was clicked once: the next click on it unpairs
    property bool confirmForget: false

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
        if (scene.isTogether(b.address))
            list.push({
                "id": "separate",
                "icon": "call_split",
                "label": "Stop together"
            });
        list.push({
            "id": "hide",
            "icon": "visibility_off",
            "label": "Hide"
        });
        if (b.device && b.paired)
            list.push({
                "id": "forget",
                "icon": confirmForget ? "delete_forever" : "delete",
                "label": confirmForget ? "Click to forget" : "Forget",
                "danger": true
            });
        return list;
    }

    function popup(b, point) {
        confirmForget = false;
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
        // Forgetting unpairs: the first click only arms it
        if (id === "forget" && !confirmForget) {
            confirmForget = true;
            return;
        }
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
        else if (id === "separate")
            scene.stopTogether();
        else if (id === "hide")
            scene.hideBody(b);
        else if (id === "forget")
            scene.forget(b);
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
        color: menu.paper.fill(0.95)
        border.width: 1
        border.color: menu.paper.fg(0.08)
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
                    readonly property bool danger: modelData.danger ?? false
                    width: col.width
                    height: 32
                    radius: 10
                    color: danger && menu.confirmForget ? Theme.withAlpha(Theme.error, 0.16) : itemArea.containsMouse ? menu.paper.fg(0.08) : "transparent"

                    // A hairline before "Stop together" or "Hide" (once) and before the first mode
                    Rectangle {
                        visible: index > 0 && (modelData.id === "separate" || (modelData.id === "hide" && menu.entries[index - 1].id !== "separate") || (modelData.id.startsWith("anc:") && !menu.entries[index - 1].id.startsWith("anc:")))
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: menu.paper.fg(0.07)
                    }
                    DankIcon {
                        id: icon
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.icon
                        size: 16
                        color: modelData.checked ? Theme.primary : danger ? Theme.error : menu.paper.fg(0.75)
                    }
                    StyledText {
                        anchors.left: icon.right
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.checked ? Theme.primary : danger ? Theme.error : menu.paper.ink
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
                        color: Theme.primary
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
