import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../device"
import "../noise"
import "../volume"
import "../device/DeviceCatalog.js" as Catalog
import "../device/Glyphs.js" as Glyphs
import "Charge.js" as Charge
import "../common/Pictures.js" as Pictures

// Frosted detail card. The focused device glyph is not drawn here: the real
// orbiting body flies onto the card's top edge and scales up, so it breaks
// out of the frame (see DeviceBody.focused).
Item {
    id: card
    readonly property PaperColors paper: PaperColors {}

    required property var scene
    readonly property var body: scene.focusBody
    readonly property var device: body ? body.device : null
    property bool picking: false
    property bool confirmForget: false
    // Headsets with noise control trade the battery graph for the ANC panel
    readonly property bool ancShown: !picking && scene.ancCapable(body)

    readonly property color ink: card.paper.ink
    readonly property color muted: card.paper.fg(0.42)

    // Time to full / time left, e.g. "≈ 2 h 08 to full"
    readonly property string timeText: body?.connected && (body?.battery ?? -1) >= 0 ? Charge.timeText(body.charge ?? null, body.charging) : ""

    // Per-part batteries reported by the headset (earbuds and case)
    readonly property var parts: body?.ancFresh ? (body.ancInfo?.state?.battery ?? null) : null
    readonly property bool trioShown: !picking && !!parts && !!(parts.left || parts.right || parts.case)

    // Charging / drain stats, shown in the battery card, or under the noise
    // control panel for headsets with ANC
    readonly property var statItems: body?.connected ? Charge.statItems(body.charge ?? null, body.charging, scene.now) : []

    implicitHeight: frameContent.implicitHeight + scene.focusOverlap + Theme.spacingL

    onBodyChanged: {
        picking = false;
        confirmForget = false;
        scene.renaming = false;
    }

    // The device's two volumes; its picture of the sound runs only while
    // the card is on screen
    CardVolume {
        id: volumes
        route: card.scene.audioRoute
        prefs: card.scene.prefs
        address: card.body && card.body.connected ? card.body.address : ""
        live: card.visible && card.scene.awake && !card.picking && !card.volumeFolded
    }
    // In the menus the volumes start as a thin line, so the card fits
    // without scrolling; a click unfolds the scope
    readonly property bool volumeFolded: card.scene.foldVolume && !card.scene.volumeUnfolded

    // Swallow clicks so they don't reach the scene's "click outside" handler
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.round(width * 0.075)
        color: card.paper.fill(0.86)
        border.width: 1
        border.color: card.paper.fg(0.07)
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
        color: area.containsMouse ? (danger ? Theme.withAlpha(Theme.error, 0.85) : card.paper.fg(0.12)) : active ? Theme.withAlpha(Theme.primary, 0.22) : card.paper.fg(0.05)
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: btn.icon
            size: 17
            color: btn.active ? Theme.primary : card.paper.fg(0.8)
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // Left: the card itself (back, look); right: the device (connect,
    // hide, forget). Two sides keep the header balanced around the glyph.
    Row {
        x: Theme.spacingM
        y: Theme.spacingM
        spacing: Theme.spacingXS

        CardButton {
            icon: "arrow_back"
            onClicked: card.scene.clearFocus()
        }
        CardButton {
            icon: "palette"
            active: card.picking
            onClicked: card.picking = !card.picking
        }
    }

    Row {
        x: parent.width - width - Theme.spacingM
        y: Theme.spacingM
        spacing: Theme.spacingXS

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
        // Bottom margin equals the side margins (and matches implicitHeight)
        height: parent.height - y - Theme.spacingL
        contentHeight: frameContent.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: frameContent
            width: parent.width
            spacing: 2

            // Name. Paired devices: click to rename, Enter to save, Escape
            // to cancel, an empty name gives the device its own name back.
            Item {
                id: nameBox
                readonly property bool canRename: card.body?.paired ?? false
                readonly property bool editing: card.scene.renaming && canRename
                width: parent.width
                height: nameLabel.implicitHeight + 6

                // Hover hint: a soft pill that hugs the name
                Rectangle {
                    anchors.centerIn: nameLabel
                    width: Math.min(nameBox.width, (nameBox.editing ? nameInput.contentWidth : nameLabel.contentWidth) + Theme.spacingM * 2)
                    height: parent.height
                    radius: height / 2
                    color: card.paper.fg(nameBox.editing ? 0.08 : 0.05)
                    visible: nameBox.editing || nameHover.containsMouse
                }

                StyledText {
                    id: nameLabel
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingM * 2
                    horizontalAlignment: Text.AlignHCenter
                    text: card.body?.name ?? ""
                    elide: Text.ElideRight
                    color: card.ink
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    visible: !nameBox.editing
                }

                MouseArea {
                    id: nameHover
                    anchors.fill: parent
                    enabled: nameBox.canRename && !nameBox.editing
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onClicked: {
                        nameInput.text = card.body.name;
                        card.scene.renaming = true;
                        nameInput.forceActiveFocus();
                        nameInput.selectAll();
                    }
                }

                TextInput {
                    id: nameInput
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingM * 2
                    horizontalAlignment: TextInput.AlignHCenter
                    visible: nameBox.editing
                    color: card.ink
                    selectionColor: Theme.withAlpha(Theme.primary, 0.35)
                    selectedTextColor: card.ink
                    font.family: nameLabel.font.family
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    // BlueZ names are at most 248 bytes
                    maximumLength: 60
                    clip: true
                    // Enter, or clicking elsewhere, saves. Escape (handled here
                    // and by the scene's Shortcut) clears `renaming` first, so
                    // the focus loss that follows saves nothing.
                    onEditingFinished: {
                        if (card.scene.renaming)
                            card.scene.rename(card.body, text);
                    }
                    Keys.onEscapePressed: event => {
                        card.scene.renaming = false;
                        event.accepted = true;
                    }
                }
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

            // One gap between the title block, the battery and the controls
            Item {
                width: 1
                height: Theme.spacingS
            }

            // The two volumes (D250), on the same screen as the pop-up's
            VolumeStrip {
                visible: volumes.ready && !card.picking && card.volumeFolded
                width: parent.width
                height: implicitHeight
                levels: volumes
                onUnfold: card.scene.volumeUnfolded = true
                onStepped: (part, dir) => volumes.stepLevel(part, dir)
            }
            ScopeScreen {
                objectName: "cardScope" // found by the offscreen previews
                visible: volumes.ready && !card.picking && !card.volumeFolded
                width: parent.width
                height: Math.round(width * 0.44) + noteRoom
                noteBelow: true
                overlay: volumes
                live: volumes.live

                // Fold it back into the thin line (menus only)
                Rectangle {
                    visible: card.scene.foldVolume
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: parent.margin + Theme.spacingXS
                    width: 24
                    height: 24
                    radius: 12
                    color: foldArea.containsMouse ? (parent.light ? parent.paper.fg(0.1) : parent.night.ink(0.12)) : "transparent"
                    DankIcon {
                        anchors.centerIn: parent
                        name: "expand_less"
                        size: 18
                        color: parent.parent.light ? parent.parent.paper.fg(foldArea.containsMouse ? 0.9 : 0.5) : parent.parent.night.ink(foldArea.containsMouse ? 0.95 : 0.5)
                    }
                    MouseArea {
                        id: foldArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.scene.volumeUnfolded = false
                    }
                }
            }

            Item {
                visible: volumes.ready && !card.picking
                width: 1
                height: Theme.spacingS
            }

            // Earbuds with a case: case, left and right with a bar each
            Loader {
                width: parent.width
                active: card.trioShown
                visible: active
                sourceComponent: EarbudsTrio {
                    width: parent ? parent.width : 0
                    parts: card.parts
                    name: card.body?.model ?? ""
                    caption: card.timeText
                    animate: card.scene.awake && card.scene.motion
                    time: card.scene.fxTime
                    caseImage: card.scene.prefs.partImageFor(card.device, "case")
                    leftImage: card.scene.prefs.partImageFor(card.device, "left")
                    rightImage: card.scene.prefs.partImageFor(card.device, "right")
                }
            }

            Loader {
                width: parent.width
                active: !card.picking
                visible: active
                sourceComponent: BatteryCard {
                    width: parent ? parent.width : 0
                    framed: false
                    gaugeRatio: card.ancShown ? 0.035 : 0.1
                    timeText: card.timeText
                    showMeter: !card.trioShown
                    animate: card.scene.awake && card.scene.motion
                    time: card.scene.fxTime

                    readonly property var c: card.body?.charge ?? null
                    readonly property real since: card.scene.sinceFor(card.body?.address)

                    level: card.body?.connected ? card.body.battery : -1
                    charging: card.body?.charging ?? false
                    history: {
                        const log = card.scene.batteryLogFor(card.body?.address);
                        return log.length && level >= 0 ? log.concat([[card.scene.now, level]]) : [];
                    }
                    footnote: card.body?.connected && level >= 0 && !card.ancShown ? Charge.footnote(c, charging) : ""
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
                        if (level >= 0)
                            return Charge.levelText(level, c, charging);
                        if (card.body.connected)
                            return "No battery info";
                        const sig = card.body.rawSignal;
                        return sig > 0 ? "Signal " + Math.round(sig * 100) + "%" : "Out of range";
                    }
                    stats: card.ancShown ? [] : card.statItems
                }
            }

            // With noise control, the stats stay with the battery, above the
            // ANC panel (without it they are part of the battery card)
            StatTiles {
                width: parent.width
                topPadding: Theme.spacingS
                stats: card.ancShown ? card.statItems : []
            }

            Loader {
                width: parent.width
                active: card.ancShown
                visible: active
                sourceComponent: AncPanel {
                    width: parent ? parent.width : 0
                    topPadding: Theme.spacingM
                    scene: card.scene
                    address: card.body?.address ?? ""
                }
            }

            // Credit of the downloaded picture: its licenses ask for it
            StyledText {
                width: parent.width
                visible: !card.picking && !!card.body?.picture?.credit
                text: visible ? Pictures.creditText(card.body.picture.credit) : ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: card.paper.fg(0.45)
                font.pixelSize: Theme.fontSizeSmall - 2
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
                            color: selected ? Theme.withAlpha(Theme.primary, 0.25) : tileArea.containsMouse ? card.paper.fg(0.1) : card.paper.fg(0.04)
                            border.width: selected ? 1 : 0
                            border.color: Theme.primary

                            DeviceGlyph {
                                visible: modelData !== "auto"
                                anchors.centerIn: parent
                                width: parent.width * 0.6
                                height: width
                                kind: modelData
                                stroke: 1.5
                                color: parent.selected ? Theme.primary : card.paper.fg(0.8)
                            }
                            DankIcon {
                                visible: modelData === "auto"
                                anchors.centerIn: parent
                                name: "auto_awesome"
                                size: parent.width * 0.5
                                color: parent.selected ? Theme.primary : card.paper.fg(0.8)
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
