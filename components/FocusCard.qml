import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "DeviceCatalog.js" as Catalog
import "Glyphs.js" as Glyphs
import "Charge.js" as Charge

// Frosted detail card. The focused device glyph is not drawn here: the real
// orbiting body flies onto the card's top edge and scales up, so it breaks
// out of the frame (see DeviceBody.focused).
Item {
    id: card

    required property var scene
    readonly property var body: scene.focusBody
    readonly property var device: body ? body.device : null
    property bool picking: false
    property bool confirmForget: false
    // Headsets with noise control trade the battery graph for the ANC panel
    readonly property bool ancShown: !picking && scene.ancCapable(body)

    readonly property color ink: "#F2F5EE"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.42)

    implicitHeight: frameContent.implicitHeight + scene.focusOverlap + Theme.spacingL

    onBodyChanged: {
        picking = false;
        confirmForget = false;
    }

    // Swallow clicks so they don't reach the scene's "click outside" handler
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.round(width * 0.075)
        color: Qt.rgba(0.075, 0.08, 0.095, 0.86)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
    }

    // Corner actions
    component CardButton: Rectangle {
        id: btn
        property string icon: ""
        property bool danger: false
        property bool active: false
        signal clicked

        width: 30
        height: 30
        radius: 15
        color: area.containsMouse ? (danger ? Theme.withAlpha(Theme.error, 0.85) : Qt.rgba(1, 1, 1, 0.12)) : active ? Theme.withAlpha(Theme.primary, 0.22) : Qt.rgba(1, 1, 1, 0.05)
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: btn.icon
            size: 17
            color: btn.active ? Theme.primary : Qt.rgba(1, 1, 1, 0.8)
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    CardButton {
        x: Theme.spacingM
        y: Theme.spacingM
        icon: "arrow_back"
        onClicked: card.scene.clearFocus()
    }

    Row {
        x: parent.width - width - Theme.spacingM
        y: Theme.spacingM
        spacing: Theme.spacingXS

        CardButton {
            icon: "palette"
            active: card.picking
            onClicked: card.picking = !card.picking
        }
        CardButton {
            visible: !!card.device
            icon: card.body?.phase === "connecting" ? "close" : card.body?.connected ? "link_off" : "link"
            onClicked: {
                if (card.body.phase === "connecting")
                    card.scene.cancelConnect(card.body);
                else if (card.body.connected)
                    card.scene.startDisconnect(card.body);
                else
                    card.scene.startConnect(card.body);
            }
        }
        // Into the black hole: gone from the orbit, still connected
        CardButton {
            icon: "visibility_off"
            onClicked: card.scene.hideBody(card.body)
        }
        CardButton {
            visible: card.body?.paired ?? false
            icon: card.confirmForget ? "delete_forever" : "delete"
            danger: true
            active: card.confirmForget
            onClicked: {
                if (!card.confirmForget) {
                    card.confirmForget = true;
                    return;
                }
                card.scene.forget(card.body);
            }
        }
    }

    // Scrolls when the host is short (compact Control Center tile)
    Flickable {
        x: Theme.spacingL
        y: card.scene.focusOverlap
        width: parent.width - Theme.spacingL * 2
        height: parent.height - y - Theme.spacingS
        contentHeight: frameContent.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: frameContent
            width: parent.width
            spacing: 2

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: card.body?.name ?? ""
                elide: Text.ElideRight
                color: card.ink
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (!card.body)
                        return "";
                    const state = card.body.connected ? "Connected" : card.body.paired ? "Paired" : "Available";
                    return Glyphs.label(card.body.kind) + "  ·  " + state;
                }
                color: card.muted
                font.pixelSize: Theme.fontSizeSmall
            }

            Item {
                width: 1
                height: card.ancShown ? Theme.spacingXS : Theme.spacingM
            }

            Loader {
                width: parent.width
                active: !card.picking
                visible: active
                sourceComponent: BatteryCard {
                    width: parent ? parent.width : 0
                    framed: false
                    gaugeRatio: card.ancShown ? 0.035 : 0.1
                    compact: card.ancShown && level >= 0
                    timeValue: {
                        if (!c || level < 0)
                            return "";
                        if (charging)
                            return c.minutesToFull > 0 ? approx + Charge.formatMinutes(c.minutesToFull) : "Measuring…";
                        return c.minutesLeft > 0 ? approx + Charge.formatMinutes(c.minutesLeft) : "";
                    }
                    timeSuffix: timeValue === "" || timeValue === "Measuring…" ? "" : charging ? "to full" : "left"
                    animate: card.scene.awake && card.scene.motion

                    readonly property var c: card.body?.charge ?? null
                    readonly property real since: card.scene.sinceFor(card.body?.address)
                    readonly property string approx: c && c.source === "estimated" ? "≈ " : ""

                    level: card.body?.connected ? card.body.battery : -1
                    charging: card.body?.charging ?? false
                    history: {
                        if (card.ancShown)
                            return [];
                        const log = card.scene.batteryLogFor(card.body?.address);
                        return log.length && level >= 0 ? log.concat([[card.scene.now, level]]) : [];
                    }
                    footnote: {
                        if (!c || !card.body?.connected || level < 0 || card.ancShown)
                            return "";
                        if (c.source === "system")
                            return "Reported by the device";
                        if (charging || c.state === "full")
                            return "Estimated from level changes · refines as it charges";
                        return c.source === "estimated" ? "Estimated from level changes" : "";
                    }
                    statusIcon: {
                        if (card.body?.phase === "connecting")
                            return "sync";
                        if (charging)
                            return "bolt";
                        if (c && c.state === "full")
                            return "battery_full";
                        return card.body?.connected ? "bluetooth_connected" : "bluetooth";
                    }
                    statusText: {
                        if (!card.body)
                            return "";
                        if (card.body.phase === "connecting")
                            return "Connecting...";
                        if (card.body.phase === "disconnecting")
                            return "Disconnecting...";
                        if (charging)
                            return "Charging...";
                        if (c && c.state === "full")
                            return "Fully charged";
                        if (card.body.connected)
                            return since > 0 ? "Connected for " + Catalog.formatDuration(card.scene.now - since) : "Connected";
                        return card.body.paired ? "Not connected" : "Available nearby";
                    }
                    detailText: {
                        if (!card.body)
                            return "";
                        if (level >= 0) {
                            if (charging)
                                return level + "%" + (c.minutesToFull > 0 ? "  •  Full in " + approx + Charge.formatMinutes(c.minutesToFull) : "  •  Measuring speed...");
                            const left = c ? Charge.formatMinutes(c.minutesLeft) : "";
                            return level + "%" + (left ? "  •  " + approx + left + " left" : "");
                        }
                        if (card.body.connected)
                            return "No battery info";
                        const sig = card.body.rawSignal;
                        return sig > 0 ? "Signal " + Math.round(sig * 100) + "%" : "Out of range";
                    }
                    stats: {
                        if (!c || !card.body?.connected || card.ancShown)
                            return [];
                        const out = [];
                        if (charging) {
                            out.push({
                                "label": "READY AT",
                                "value": c.fullAt > 0 ? approx + Charge.formatClock(c.fullAt) : "Measuring…"
                            });
                            out.push(c.watts > 0 ? {
                                "label": "POWER",
                                "value": c.watts.toFixed(1) + " W"
                            } : {
                                "label": "SPEED",
                                "value": c.ratePerHour > 0 ? "+" + Math.round(c.ratePerHour) + " %/h" : "—"
                            });
                            out.push({
                                "label": c.gained > 0 ? "+" + c.gained + "% IN" : "CHARGING FOR",
                                "value": c.since > 0 ? (Charge.formatMinutes((card.scene.now - c.since) / 60000) || "< 1 min") : "—"
                            });
                        } else if (c.state !== "full") {
                            if (c.minutesLeft > 0)
                                out.push({
                                    "label": "EMPTY AT",
                                    "value": approx + Charge.formatClock(card.scene.now + c.minutesLeft * 60000)
                                });
                            if (c.ratePerHour < 0)
                                out.push({
                                    "label": "DRAIN",
                                    "value": Math.round(-c.ratePerHour) + " %/h"
                                });
                        }
                        if (c.health > 0)
                            out.push({
                                "label": "HEALTH",
                                "value": c.health + "%"
                            });
                        return out;
                    }
                }
            }

            Loader {
                width: parent.width
                active: card.ancShown
                visible: active
                sourceComponent: AncPanel {
                    width: parent ? parent.width : 0
                    topPadding: Theme.spacingS
                    scene: card.scene
                    address: card.body?.address ?? ""
                }
            }

            // Glyph picker
            Loader {
                width: parent.width
                active: card.picking
                visible: active
                sourceComponent: Flow {
                    width: parent ? parent.width : 0
                    spacing: 6

                    readonly property real tile: Math.floor((width - spacing * 7) / 8)
                    readonly property string current: card.scene.prefs.glyphOverrides[card.body?.address] ?? "auto"

                    Repeater {
                        model: ["auto"].concat(Glyphs.order)

                        Rectangle {
                            width: parent.tile
                            height: width
                            radius: width * 0.3
                            readonly property bool selected: parent.current === modelData
                            color: selected ? Theme.withAlpha(Theme.primary, 0.25) : tileArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: selected ? 1 : 0
                            border.color: Theme.primary

                            DeviceGlyph {
                                visible: modelData !== "auto"
                                anchors.centerIn: parent
                                width: parent.width * 0.6
                                height: width
                                kind: modelData
                                stroke: 1.5
                                color: parent.selected ? Theme.primary : Qt.rgba(1, 1, 1, 0.8)
                            }
                            DankIcon {
                                visible: modelData === "auto"
                                anchors.centerIn: parent
                                name: "auto_awesome"
                                size: parent.width * 0.5
                                color: parent.selected ? Theme.primary : Qt.rgba(1, 1, 1, 0.8)
                            }
                            MouseArea {
                                id: tileArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    card.scene.prefs.setGlyphOverride(card.body.address, modelData);
                                    card.scene.sounds.play("snap");
                                    card.body.pop();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
