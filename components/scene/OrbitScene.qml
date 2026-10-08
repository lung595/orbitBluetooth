import QtQuick
import "../centre"

// The planetary Bluetooth scene shared by the Control Center panel, the bar
// popout and the desktop widget.
//
// Performance model:
//  - one step (OrbitPhysics) drives everything (physics, orbits, twinkles)
//    and only runs while the scene is active and not settled;
//  - bodies are plain items whose px/py are written in a single JS pass;
//  - static art (stars, nebulae, orbit rings) is painted once;
//  - discovery only runs while the scene is open and stops on its own.
//
// This file wires the parts, each in its own file, and gives them the
// entry points they call on each other: the device list (OrbitDevices),
// discovery, the new-device offer, the connection flow, the drag, hiding and
// focus gestures, noise control, the daemon's data, the physics, the sky
// (OrbitBackdrop), the orbit with its bodies and cards (OrbitWorld) and what
// floats above it (OrbitChrome). Its own state (inputs, geometry, clocks,
// black hole, preferences) is in the base type, OrbitState; what reads a
// part (cardOpen, awake, the aliases) stays here.
OrbitState {
    id: scene

    // The detail card's measures (FocusLayout), read by the world, the bodies
    // and the hosts
    FocusLayout {
        id: focusLayout
        scene: orbitRoot
    }
    readonly property alias focusCardWidth: focusLayout.cardWidth
    readonly property alias focusGlyphSize: focusLayout.glyphSize
    readonly property alias focusGlyphScale: focusLayout.glyphScale
    readonly property alias focusGlyphLift: focusLayout.glyphLift
    readonly property alias focusOverlap: focusLayout.overlap
    readonly property alias focusFullOverlap: focusLayout.fullOverlap
    readonly property alias focusHeadroom: focusLayout.headroom
    readonly property alias focusFitHeight: focusLayout.fitHeight

    // --- State that reads a part ---------------------------------------------------
    readonly property alias deviceMap: devices.deviceMap
    // Names of connected devices read stronger than the others; with nothing
    // connected there is no hierarchy to show, so every name is lifted
    readonly property alias anyConnected: devices.anyConnected
    // A card is up over the sky (the detail card, the hidden list, the radar): the
    // sky steps back, whichever it is. The detail card is the one that is the
    // device's, and not the radar's flown hero.
    readonly property bool cardOpen: !!focusBody || hiddenOpen || radar.open
    readonly property bool detailOpen: !!focusBody && !radar.open
    readonly property alias world: worldItem
    readonly property alias tetherLayer: worldItem.tetherLayer
    readonly property real holeHorizon: backdrop.holeHorizon

    // Time-driven motion (orbits, float, twinkles) runs only while awake;
    // otherwise the clock stops as soon as every body has settled.
    readonly property bool awake: active && visible && width > 0 && !screenAsleep && (!freezeWhenIdle || interacting || (prefs.desktopAmbient && !covered) || !!dragBody || cardOpen)
    readonly property Item orbitRoot: scene

    // --- What the daemon publishes (OrbitDaemonData) -------------------------
    OrbitDaemonData {
        id: daemon
        scene: orbitRoot
    }
    readonly property alias globals: daemon.globals
    readonly property alias now: daemon.now
    function sinceFor(address) {
        return daemon.sinceFor(address);
    }
    function batteryLogFor(address) {
        return daemon.batteryLogFor(address);
    }
    function powerFor(address) {
        return daemon.powerFor(address);
    }
    function pictureFor(model) {
        return daemon.pictureFor(model);
    }
    function requestPicture(query) {
        daemon.requestPicture(query);
    }

    // --- Noise control (the daemon runs the helper, see AncService) ----------
    OrbitAnc {
        id: anc
        scene: orbitRoot
        bodies: worldItem.bodies
    }
    readonly property alias ancService: anc.service
    function ancFor(address) {
        return anc.infoFor(address);
    }
    function ancCapable(body) {
        return anc.capable(body);
    }
    function ancSend(address, key, value) {
        anc.send(address, key, value);
    }
    function ancWatch(address, on) {
        anc.watch(address, on);
    }
    function ancSyncViews() {
        anc.syncViews();
    }

    clip: true
    focus: active

    onWidthChanged: wake()
    onHeightChanged: wake()
    onAwakeChanged: wake()
    onActiveChanged: {
        wake();
        refresh();
        discovery.update();
        ancSyncViews();
        if (!active)
            dismiss();
    }

    // --- Device list -----------------------------------------------------------
    OrbitDevices {
        id: devices
        scene: orbitRoot
        onListed: list => offer.update(list)
    }
    function refresh() {
        devices.refresh();
    }
    function finalizeRemoval(address) {
        devices.finalizeRemoval(address);
    }
    onBtOnChanged: {
        refresh();
        discovery.update();
    }

    // --- Offer to connect a new device ---------------------------------------
    OrbitOffer {
        id: offer
        scene: orbitRoot
        bodies: worldItem.bodies
    }
    readonly property alias offerAddress: offer.address
    function acceptOffer() {
        offer.accept();
    }
    function dismissOffer() {
        offer.dismiss();
    }

    Component.onCompleted: {
        refresh();
        discovery.update();
        Qt.callLater(ancSyncViews);   // bodies exist once the model is filled
    }
    Component.onDestruction: {
        stopScan();
        anc.endViews();
    }

    // --- Discovery -------------------------------------------------------------
    OrbitDiscovery {
        id: discovery
        scene: orbitRoot
    }
    // The center and the Scan chip start and stop it by hand
    function startScan() {
        discovery.start();
    }
    function stopScan() {
        discovery.stop();
    }

    onAutoScanChanged: discovery.update()
    readonly property bool _autoScanPref: prefs.autoScan
    on_AutoScanPrefChanged: discovery.update()

    // --- Connection flow -------------------------------------------------------
    OrbitConnections {
        id: connections
        scene: orbitRoot
        bodies: worldItem.bodies
    }
    // Entry points for the bodies, the cards and the menu
    function startConnect(b) {
        connections.startConnect(b);
    }
    function cancelConnect(b) {
        connections.cancelConnect(b);
    }
    function startDisconnect(b) {
        connections.startDisconnect(b);
    }
    function forget(b) {
        connections.forget(b);
    }
    function onBodyConnectionChanged(b, isConnected) {
        connections.onBodyConnectionChanged(b, isConnected);
    }

    // --- Drag ------------------------------------------------------------------
    OrbitDrag {
        id: drag
        scene: orbitRoot
    }
    function beginDrag(b, p) {
        drag.begin(b, p);
    }
    function updateDrag(p) {
        drag.update(p);
    }
    function endDrag() {
        drag.end();
    }

    // --- Listen together (drop a device onto another, OrbitTogether) ----------------
    OrbitTogether {
        id: togetherCtl
        scene: orbitRoot
    }
    readonly property alias together: togetherCtl
    // --- The listening source takes the center (OrbitCentre) ----------------------
    OrbitCentre {
        id: centreCtl
        scene: orbitRoot
        bodies: worldItem.bodies
        session: togetherCtl.session
    }
    readonly property alias centre: centreCtl

    // --- The group the scene proposes: a ghost planet on the host's ring (OrbitGhost) ---
    OrbitGhost {
        id: ghostCtl
        scene: orbitRoot
        centre: centreCtl
        session: togetherCtl.session
    }
    readonly property alias ghost: ghostCtl

    // --- Two outputs on one radio: a note, once per pair (OrbitRadio) ----------------
    OrbitRadio {
        scene: orbitRoot
    }

    // --- Hiding (the black hole) ---------------------------------------------------
    OrbitHidden {
        id: hidden
        scene: orbitRoot
    }
    function hideBody(b) {
        hidden.hide(b);
    }
    function finishHide(b) {
        hidden.finish(b);
    }
    function hideById(id, name) {
        hidden.hideById(id, name);
    }
    function carryToHole(point) {
        return hidden.carry(point);
    }
    function dropFromHole() {
        hidden.uncarry();
    }
    function unhide(address) {
        hidden.unhide(address);
    }
    function unhideAll() {
        hidden.unhideAll();
    }
    function openHidden() {
        hidden.open();
    }
    function closeHidden() {
        hidden.close();
    }

    readonly property bool menuOpen: menu.open

    // Closes whatever overlay is open (detail card, hidden list, menu)
    function dismiss() {
        menu.close();
        radar.close();
        closeHidden();
        clearFocus();
    }

    function openMenu(b, point) {
        if (!b || b.swallowing || focusBody || radar.open)
            return;
        menu.popup(b, point);
    }
    // The menu's group chooser, opened straight on `b` (the radar's "Add a device…")
    function openGroupChooser(b, point) {
        if (b)
            menu.addDevices(b, point);
    }

    // --- Focus and rename (the detail card) ----------------------------------
    OrbitFocus {
        id: focusCtl
        scene: orbitRoot
        menu: menu
    }
    // `card` asks for the detail card of a group member, which a click opens the radar for
    function focusOn(b, card) {
        focusCtl.on(b, card);
    }
    function clearFocus() {
        focusCtl.clear();
    }
    // Something to step back from: a card, the hidden list, or the group's view
    readonly property bool canStepBack: cardOpen || centre.canRecall
    function stepBack() {
        focusCtl.stepBack();
    }
    function rename(b, text) {
        focusCtl.rename(b, text);
    }

    // --- Waves -----------------------------------------------------------------
    function emitWave(outward) {
        worldItem.emitWave(outward);
    }

    // --- Physics ---------------------------------------------------------------
    OrbitPhysics {
        id: physics
        scene: orbitRoot
        repeater: worldItem.bodies
        card: worldItem.cardSlide
        centre: centreCtl
        ghost: ghostCtl
    }
    onDragBodyChanged: physics.kick()
    onFocusBodyChanged: physics.kick()

    // --- Background --------------------------------------------------------------
    OrbitBackdrop {
        id: backdrop
        anchors.fill: parent
        scene: orbitRoot
    }

    // --- World -------------------------------------------------------------------
    OrbitWorld {
        id: worldItem
        anchors.fill: parent
        scene: orbitRoot
        model: devices.model
    }

    // --- Chrome --------------------------------------------------------------------
    OrbitChrome {
        scene: orbitRoot
        bodyCount: devices.model.count
    }

    // The volume radar of a listening group, over the sky and under the menu
    readonly property alias radar: radarCtl
    OrbitRadar {
        id: radarCtl
        scene: orbitRoot
        anchors.fill: parent
        z: 29000
    }

    // Right-click menu, above everything else
    OrbitMenu {
        id: menu
        scene: orbitRoot
        z: 30000
    }
}
