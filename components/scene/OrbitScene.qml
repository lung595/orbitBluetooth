import QtQuick
import qs.Common
import qs.Services
import "../common"
import "../pairing"
import "../noise/Anc.js" as Anc
import "Orbit.js" as Orbit
import "Physics.js" as Physics

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
// This file holds the state every part shares and wires the parts, each in
// its own file: the device list (OrbitDevices), discovery, the new-device
// offer, the connection flow, the physics, the sky (OrbitBackdrop) and the
// orbit with its bodies and cards (OrbitWorld).
Item {
    id: scene
    readonly property NightColors night: NightColors {}

    // --- Inputs ----------------------------------------------------------------
    property bool active: true               // visible to the user right now
    property bool autoScan: true             // start discovery when active
    property bool freezeWhenIdle: false      // desktop: stop animating when idle
    property bool covered: false             // desktop: hidden behind a window, Ambient pauses
    property bool interacting: false         // desktop: pointer is over the widget
    property bool glass: false               // desktop: frameless, fades into the wallpaper
    property bool foldVolume: false          // menus: the card's two volumes start folded into a thin line
    property bool volumeUnfolded: false      // ...until clicked; kept while the shell runs, never saved
    property real cornerRadius: 0            // rounded hosts (Control Center, popout)
    property var previewDevices: []          // fake device objects, for previews and tests
    readonly property alias prefs: prefsObj
    readonly property alias sounds: soundFx

    // --- Geometry --------------------------------------------------------------
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real rx: Math.max(40, width / 2 - bodySize * 0.8)
    readonly property real ry: Math.max(30, height / 2 - bodySize * 1.25)
    readonly property real innerNorm: 0.56     // connected orbit
    // Perspective: a tilted circle is still an ellipse, just shifted. The
    // connected ring keeps its near (bottom) edge and its far (top) edge
    // reaches the host core's edge, so devices on the far side pass behind it
    readonly property real innerFrontRy: ry * innerNorm
    readonly property real innerBackRy: Math.min(innerFrontRy, coreSize * 0.5)
    readonly property real ringRy: (innerFrontRy + innerBackRy) / 2
    readonly property real ringCy: cy + (innerFrontRy - innerBackRy) / 2
    readonly property real outerMinNorm: 0.8  // strongest signal
    readonly property real snapNorm: 0.7      // magnet engages inside this
    readonly property real detachNorm: 0.8   // pulling a connected device past this disconnects
    readonly property real coreSize: Math.round(Math.min(width, height) * 0.17)
    readonly property real bodySize: Math.round(Math.max(34, Math.min(width, height) * 0.135))

    // Focus mode layout: a small glyph (~20% of the card width) peeking
    // ~30% above the card's top edge, the rest sitting inside the frame
    readonly property real focusCardWidth: Math.min(width - Theme.spacingL * 2, 360)
    readonly property real focusGlyphRatio: 0.2
    readonly property real focusGlyphSize: Math.min(focusCardWidth * focusGlyphRatio, height * 0.26)
    readonly property real focusGlyphScale: focusGlyphSize / bodySize
    readonly property real focusGlyphLift: focusGlyphSize * 0.2      // glyph center relative to card top
    readonly property real focusOverlap: focusGlyphLift + focusGlyphSize * 0.5 + 8
    // Room above the card for the glyph, which breaks out of its top edge:
    // its center sits 0.2 glyph below the card top, so 0.3 glyph rises
    // above it, plus a margin. Less than this and the window cuts it.
    function focusHeadroomFor(glyph) {
        return glyph * 0.3 + Theme.spacingS;
    }
    readonly property real focusHeadroom: focusHeadroomFor(focusGlyphSize)
    // Scene height at which the open detail card fits without scrolling (0
    // when none is open): card content, glyph overlap and margins, with the
    // glyph at its width-bound size. It does not depend on the scene's own
    // height, so a host can grow to it without a binding loop.
    readonly property real focusFitHeight: {
        if (!focusBody)
            return 0;
        const glyph = focusCardWidth * focusGlyphRatio;
        const content = worldItem.focusCard.implicitHeight - focusOverlap - Theme.spacingL;
        return content + glyph * 0.7 + 8 + Theme.spacingL + focusHeadroomFor(glyph) + Theme.spacingM;
    }

    // --- State -----------------------------------------------------------------
    readonly property alias deviceMap: devices.deviceMap
    // Names of connected devices read stronger than the others; with nothing
    // connected there is no hierarchy to show, so every name is lifted
    readonly property alias anyConnected: devices.anyConnected
    property var focusBody: null
    property var dragBody: null
    property real dragX: 0
    property real dragY: 0
    property real clock: 0
    property real fxTime: 0
    // When the black hole last swallowed a shooting star (effects clock)
    property real holeFlashAt: -10
    property real orbitTime: 0
    property bool settled: false
    property double now: Date.now()
    readonly property alias world: worldItem
    readonly property alias tetherLayer: worldItem.tetherLayer

    // --- Black hole ("Hidden") -----------------------------------------------
    // It drifts in the outer belt like a device nobody paired: it takes a
    // slot there and step() moves it with the same spring as the bodies.
    property real holeX: cx
    property real holeY: cy + ry
    readonly property var _hole: ({
            "px": 0,
            "py": 0,
            "vx": 0,
            "vy": 0,
            "spawned": false,
            "homeHash": 0.62
        })
    readonly property real holeHorizon: backdrop.holeHorizon
    property bool hiddenOpen: false
    property real holeFeed: 0      // 0..1, how close the dragged device is
    property real holeSpin: 0      // tesseract phase (0 = the classic cube-in-cube), advanced by step()
    // address -> {x, y}: where a device reappears (spat out of the hole)
    property var spawnFrom: ({})
    readonly property int hiddenCount: Object.keys(prefs.hiddenDevices).length

    readonly property var adapter: BluetoothService.adapter
    readonly property bool btOn: BluetoothService.enabled
    readonly property bool discovering: BluetoothService.discovering
    readonly property bool motion: !prefs.reduceMotion
    // Nobody can see the screen: session locked or monitors powered off
    readonly property bool screenAsleep: SessionService.locked || IdleService.isShellLocked || IdleService.monitorsOff
    // Time-driven motion (orbits, float, twinkles) runs only while awake;
    // otherwise the clock stops as soon as every body has settled.
    readonly property bool awake: active && visible && width > 0 && !screenAsleep && (!freezeWhenIdle || interacting || (prefs.desktopAmbient && !covered) || !!dragBody || !!focusBody)
    readonly property Item orbitRoot: scene

    readonly property var _globals: PluginService.globalVars[prefs.pluginId] || ({})

    function sinceFor(address) {
        const s = _globals.since || {};
        return address && s[address] ? s[address] : 0;
    }
    function batteryLogFor(address) {
        const l = _globals.batteryLog || {};
        return address ? (l[address] || []) : [];
    }
    function powerFor(address) {
        const p = _globals.power || {};
        return address ? (p[address] || null) : null;
    }

    // --- Real device pictures (opt-in, the daemon does the lookups) ----------
    readonly property var _pictureService: PluginService.pluginDaemonInstances[prefs.pluginId]?.pictureLookup ?? null
    function pictureFor(model) {
        const p = _globals.pictures || {};
        return prefs.realPictures && model ? (p[model] || null) : null;
    }
    function requestPicture(query) {
        if (query)
            _pictureService?.request(query);
    }

    // --- The two volumes (the daemon's AudioRoute, D249) ----------------------
    // Not read-only: the offscreen previews give a made-up one
    property var audioRoute: PluginService.pluginDaemonInstances[prefs.pluginId]?.route ?? null

    // --- Noise control (the daemon runs the helper, see AncService) ----------
    readonly property var _ancService: PluginService.pluginDaemonInstances[prefs.pluginId]?.anc ?? null

    function ancFor(address) {
        const a = _globals.anc || {};
        return address ? (a[address] || null) : null;
    }
    function ancCapable(body) {
        return prefs.ancEnabled && !!body && body.connected && body.paired && Anc.family(body.model) !== "";
    }
    function ancSend(address, key, value) {
        _ancService?.send(address, key, value);
    }
    function ancCycle(address) {
        _ancService?.cycle(address);
    }
    function ancWatch(address, on) {
        _ancService?.watch(address, on);
    }
    // While this view is visible, keep a session with each connected headset:
    // the helper waits on the socket, so plugging or unplugging the charger
    // shows up at once without any polling. Closing the view ends them.
    property var _ancViewing: []
    function ancSyncViews() {
        const want = [];
        if (active) {
            for (let i = 0; i < worldItem.bodies.count; i++) {
                const b = worldItem.bodies.itemAt(i);
                if (b && b.ancCapable)
                    want.push(b.address);
            }
        }
        const c = Orbit.changes(_ancViewing, want);
        if (!c.added.length && !c.removed.length)
            return;
        c.added.forEach(a => ancWatch(a, true));
        c.removed.forEach(a => ancWatch(a, false));
        _ancViewing = want;
    }

    clip: true
    focus: active

    Prefs {
        id: prefsObj
    }
    SoundFx {
        id: soundFx
        enabled: prefsObj.sounds
        volume: prefsObj.soundVolume
    }

    function wake() {
        settled = false;
    }

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

    // Connection timers tick once per second, only while the scene is awake:
    // an idle desktop orbit stays frozen (zero frames) and catches up on wake.
    Timer {
        interval: 1000
        repeat: true
        running: scene.awake && scene.btOn && Object.keys(scene._globals.since || {}).length > 0
        triggeredOnStart: true
        onTriggered: scene.now = Date.now()
    }
    // Fresh clock on every daemon event (connection, battery sample), so the
    // charge estimates never use a stale time, even while the ticker sleeps.
    on_GlobalsChanged: now = Date.now()

    Component.onCompleted: {
        refresh();
        discovery.update();
        Qt.callLater(ancSyncViews);   // bodies exist once the model is filled
    }
    Component.onDestruction: {
        stopScan();
        _ancViewing.forEach(a => ancWatch(a, false));
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

    // What did not work, said under the core (OrbitNote), null when nothing
    property var note: null
    function explain(info) {
        note = info;
    }

    // --- Drag ------------------------------------------------------------------
    function beginDrag(b, p) {
        dragBody = b;
        b.dragging = true;
        b.armed = false;
        dragX = p.x;
        dragY = p.y;
        wake();
    }

    function updateDrag(p) {
        dragX = p.x;
        dragY = p.y;
        const b = dragBody;
        if (!b)
            return;
        const wasArmed = b.armed;
        const wasHide = b.hideArmed;
        const arm = Physics.dragArm(scene, b.holding, p.x, p.y);
        b.hideArmed = arm.hide;
        holeFeed = arm.feed;
        b.armed = arm.armed;
        if ((b.armed && !wasArmed && !b.holding) || (b.hideArmed && !wasHide)) {
            b.pop();
            sounds.play("snap");
        }
        wake();
    }

    function endDrag() {
        const b = dragBody;
        dragBody = null;
        if (!b)
            return;
        b.dragging = false;
        holeFeed = 0;
        if (b.hideArmed) {
            b.hideArmed = false;
            hideBody(b);
        } else if (b.armed) {
            if (b.connected)
                startDisconnect(b);
            else if (b.phase === "connecting")
                cancelConnect(b);
            else
                startConnect(b);
        }
        b.armed = false;
        wake();
    }

    // --- Hiding (the black hole) ---------------------------------------------------
    // The device spirals into the hole; once it vanished it is saved as hidden
    // (it stays connected, it just leaves the orbit).
    function hideBody(b) {
        if (!b || b.swallowing || b.leaving)
            return;
        if (focusBody === b)
            clearFocus();
        if (b.phase === "connecting")
            cancelConnect(b);
        b.swallow();
        sounds.play("disconnect");
        wake();
    }

    function finishHide(b) {
        prefs.setHidden(b.address, b.name, true);
        refresh();
    }

    function unhide(address) {
        const next = Object.assign({}, spawnFrom);
        next[address] = Qt.point(holeX, holeY);
        spawnFrom = next;
        prefs.setHidden(address, "", false);
        if (hiddenCount <= 1)
            closeHidden();
        wake();
    }

    function unhideAll() {
        const next = Object.assign({}, spawnFrom);
        for (const a in prefs.hiddenDevices)
            next[a] = Qt.point(holeX, holeY);
        spawnFrom = next;
        prefs.set("hiddenDevices", ({}));
        closeHidden();
        wake();
    }

    function openHidden() {
        clearFocus();
        hiddenOpen = true;
        wake();
        scene.forceActiveFocus();
    }

    function closeHidden() {
        if (!hiddenOpen)
            return;
        hiddenOpen = false;
        wake();
    }

    readonly property bool menuOpen: menu.open

    // Closes whatever overlay is open (detail card, hidden list, menu)
    function dismiss() {
        menu.close();
        closeHidden();
        clearFocus();
    }

    function openMenu(b, point) {
        if (!b || b.swallowing || focusBody)
            return;
        menu.popup(b, point);
    }

    // A device drawn under this scene point, if any (devices passing behind
    // the core still get their clicks)
    function bodyAt(x, y) {
        for (let i = 0; i < worldItem.bodies.count; i++) {
            const b = worldItem.bodies.itemAt(i);
            if (b && !b.leaving && Math.hypot(x - b.px, y - b.py) < b.diameter * b.baseScale / 2)
                return b;
        }
        return null;
    }

    // --- Focus -----------------------------------------------------------------
    function focusOn(b) {
        if (!b || b.leaving)
            return;
        focusBody = b;
        wake();
        scene.forceActiveFocus();
    }

    function clearFocus() {
        renaming = false;
        if (!focusBody)
            return;
        focusBody = null;
        wake();
    }

    // --- Rename (click on the name in the detail card) ------------------------
    // The new name is the BlueZ alias: shown everywhere on the system, kept
    // by BlueZ itself (Orbit stores nothing). An empty name gives the device
    // its own name back.
    property bool renaming: false

    function rename(b, text) {
        renaming = false;
        if (!b || !b.device)
            return;
        const next = text.trim();
        if (next === b.name)
            return;
        b.device.name = next;
    }

    // Escape steps back one level (menu, hidden list, detail card) before it
    // may close the host. A Shortcut runs before the host's own key handler
    // (the bar popout and Control Center keep keyboard focus for themselves),
    // and it is only enabled while there is something to step back from.
    Shortcut {
        sequence: "Escape"
        enabled: scene.active && (scene.menuOpen || scene.hiddenOpen || !!scene.focusBody)
        onActivated: {
            if (scene.renaming)
                scene.renaming = false;
            else
            // cancel the rename, keep the card
            if (scene.menuOpen)
                menu.close();
            else if (scene.hiddenOpen)
                scene.closeHidden();
            else
                scene.clearFocus();
        }
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
        card: worldItem.focusCard
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
    // Contextual hint
    OrbitHint {
        scene: orbitRoot
        bodyCount: devices.model.count
    }

    // Offer card for a newly found, unpaired device
    OfferCard {
        scene: orbitRoot
    }

    // Scan chip. On glass it is centered, carries its own smoky pill so it
    // reads on any wallpaper, and only shows while the widget is in use.
    ScanChip {
        scene: orbitRoot
    }

    // What did not work, with a link to the guide
    OrbitNote {
        scene: orbitRoot
    }

    // Bluetooth off / missing adapter
    AdapterNotice {
        scene: orbitRoot
    }

    // Right-click menu, above everything else
    OrbitMenu {
        id: menu
        scene: orbitRoot
        z: 30000
    }
}
