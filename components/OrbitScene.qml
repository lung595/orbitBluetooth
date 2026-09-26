import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets
import "DeviceCatalog.js" as Catalog
import "Anc.js" as Anc

// The planetary Bluetooth scene shared by the Control Center panel, the bar
// popout and the desktop widget.
//
// Performance model:
//  - one FrameAnimation drives everything (physics, orbits, twinkles) and only
//    runs while the scene is active and not settled;
//  - bodies are plain items whose px/py are written in a single JS pass;
//  - static art (stars, nebulae, orbit rings) is painted once;
//  - discovery only runs while the scene is open and stops on its own.
Item {
    id: scene
    readonly property NightColors night: NightColors {}

    // --- Inputs ----------------------------------------------------------------
    property bool active: true               // visible to the user right now
    property bool autoScan: true             // start discovery when active
    property bool freezeWhenIdle: false      // desktop: stop animating when idle
    property bool interacting: false         // desktop: pointer is over the widget
    property bool glass: false               // desktop: frameless, fades into the wallpaper
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
    // Scene height at which the open detail card fits without scrolling (0
    // when none is open): card content, glyph overlap and margins, with the
    // glyph at its width-bound size. It does not depend on the scene's own
    // height, so a host can grow to it without a binding loop.
    readonly property real focusFitHeight: {
        if (!focusBody)
            return 0;
        const glyph = focusCardWidth * focusGlyphRatio;
        const content = focusCard.implicitHeight - focusOverlap - Theme.spacingL;
        return content + glyph * 0.7 + 8 + Theme.spacingL + glyph * 0.35 + Theme.spacingM;
    }

    // --- State -----------------------------------------------------------------
    property var deviceMap: ({})
    property var focusBody: null
    property var dragBody: null
    property real dragX: 0
    property real dragY: 0
    property real clock: 0
    property real orbitTime: 0
    property bool settled: false
    property double now: Date.now()
    readonly property alias world: worldItem
    readonly property alias tetherLayer: tetherLayerItem

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
    readonly property real holeHorizon: blackHole.horizon
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
    // Time-driven motion (orbits, float, twinkles) runs only while awake;
    // otherwise the clock stops as soon as every body has settled.
    readonly property bool awake: active && visible && width > 0 && (!freezeWhenIdle || interacting || prefs.desktopAmbient || !!dragBody || !!focusBody)
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

    // --- Noise control (the daemon runs the helper, see AncService) ----------
    readonly property var _ancService: PluginService.pluginDaemonInstances[prefs.pluginId]?.anc ?? null

    function ancFor(address) {
        const a = _globals.anc || {};
        return address ? (a[address] || null) : null;
    }
    function ancCapable(body) {
        return prefs.ancEnabled && !!body && body.connected && body.paired && Anc.family(body.name) !== "";
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
            for (let i = 0; i < bodies.count; i++) {
                const b = bodies.itemAt(i);
                if (b && b.ancCapable)
                    want.push(b.address);
            }
        }
        const had = _ancViewing;
        if (want.length === had.length && want.every(a => had.indexOf(a) >= 0))
            return;
        want.forEach(a => {
            if (had.indexOf(a) < 0)
                ancWatch(a, true);
        });
        had.forEach(a => {
            if (want.indexOf(a) < 0)
                ancWatch(a, false);
        });
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
        updateScan();
        ancSyncViews();
        if (!active)
            dismiss();
    }

    // --- Device list -----------------------------------------------------------
    ListModel {
        id: bodyModel
    }

    function refresh() {
        const a = adapter;
        const all = (a && a.devices ? a.devices.values : []).concat(previewDevices);
        const map = {};
        let list = [];
        for (let i = 0; i < all.length; i++) {
            const d = all[i];
            if (!d || d.blocked || prefs.isHidden(d.address))
                continue;
            if (!prefs.showUnnamed && Catalog.isUnnamed(d) && !d.connected)
                continue;
            // Quickshell does not expose RSSI (signalStrength is undefined), so
            // anything BlueZ lists while discovering is treated as in range.
            if (!(d.connected || d.paired || d.bonded || d.signalStrength === undefined || d.signalStrength > 0))
                continue;
            list.push(d);
        }
        list.sort((x, y) => {
            if (x.connected !== y.connected)
                return x.connected ? -1 : 1;
            const px = x.paired || x.bonded, py = y.paired || y.bonded;
            if (px !== py)
                return px ? -1 : 1;
            const nx = Catalog.isUnnamed(x), ny = Catalog.isUnnamed(y);
            if (nx !== ny)
                return nx ? 1 : -1;
            return (y.signalStrength || 0) - (x.signalStrength || 0);
        });
        const room = Math.max(0, prefs.maxDevices - list.filter(c => c.connected).length);
        let kept = 0;
        list = list.filter(d => d.connected || kept++ < room);
        for (const d of list)
            map[d.address] = d;
        if (!btOn) {
            for (const k in map)
                delete map[k];
        }

        // Diff into the model so existing bodies keep their physics state
        for (let i = bodyModel.count - 1; i >= 0; i--) {
            const addr = bodyModel.get(i).address;
            if (!map[addr] && !bodyModel.get(i).leaving)
                bodyModel.setProperty(i, "leaving", true);
            else if (map[addr] && bodyModel.get(i).leaving)
                bodyModel.setProperty(i, "leaving", false);
        }
        for (const addr in map) {
            let found = false;
            for (let i = 0; i < bodyModel.count; i++) {
                if (bodyModel.get(i).address === addr) {
                    found = true;
                    break;
                }
            }
            if (!found)
                bodyModel.append({
                    "address": addr,
                    "leaving": false
                });
        }
        // Keep leaving devices resolvable while they fade out
        for (let i = 0; i < bodyModel.count; i++) {
            const addr = bodyModel.get(i).address;
            if (!map[addr] && deviceMap[addr])
                map[addr] = deviceMap[addr];
        }
        deviceMap = map;
        wake();
    }

    function finalizeRemoval(address) {
        for (let i = 0; i < bodyModel.count; i++) {
            const e = bodyModel.get(i);
            if (e.address === address && e.leaving) {
                if (focusBody && focusBody.address === address)
                    clearFocus();
                bodyModel.remove(i);
                return;
            }
        }
    }

    Connections {
        target: scene.adapter?.devices ?? null
        function onValuesChanged() {
            scene.refresh();
            Qt.callLater(scene.ancSyncViews);
        }
    }
    Connections {
        target: scene.prefs
        function onShowUnnamedChanged() {
            scene.refresh();
        }
        function onMaxDevicesChanged() {
            scene.refresh();
        }
        function onHiddenDevicesChanged() {
            scene.refresh();
        }
    }
    onBtOnChanged: {
        refresh();
        updateScan();
    }

    // Membership/RSSI changes are not all signalled by the model; a slow poll
    // while someone is looking (or discovery runs) catches the stragglers.
    Timer {
        interval: 1500
        repeat: true
        running: scene.active && scene.btOn && (scene.awake || scene.discovering)
        onTriggered: {
            scene.refresh();
            scene.ancSyncViews();
        }
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
        updateScan();
        Qt.callLater(ancSyncViews);   // bodies exist once the model is filled
    }
    Component.onDestruction: {
        stopScan();
        _ancViewing.forEach(a => ancWatch(a, false));
    }

    // --- Discovery -------------------------------------------------------------
    property bool _ownsDiscovery: false

    function startScan() {
        if (!adapter || !btOn)
            return;
        if (!adapter.discovering) {
            adapter.discovering = true;
            _ownsDiscovery = true;
        }
        if (prefs.scanSeconds > 0)
            scanStopTimer.restart();
    }

    function stopScan() {
        scanStopTimer.stop();
        if (adapter && _ownsDiscovery && adapter.discovering)
            adapter.discovering = false;
        _ownsDiscovery = false;
    }

    // With the autoScan preference off, only the center or the Scan chip start
    // discovery; a manual scan is still stopped when the view closes.
    function updateScan() {
        if (active && btOn && autoScan && prefs.autoScan)
            startScan();
        else if (!active || !btOn || !autoScan)
            stopScan();
    }

    onAutoScanChanged: updateScan()
    readonly property bool _autoScanPref: prefs.autoScan
    on_AutoScanPrefChanged: updateScan()

    Timer {
        id: scanStopTimer
        interval: Math.max(5, scene.prefs.scanSeconds) * 1000
        onTriggered: scene.stopScan()
    }

    // --- Connection flow -------------------------------------------------------
    function startConnect(b) {
        if (!b || !b.device || b.connected || b.phase === "connecting")
            return;
        const d = b.device;
        b.phase = "connecting";
        pendingTimer.restart();
        wake();
        if (d.paired || d.bonded) {
            BluetoothService.connectDeviceWithTrust(d);
            return;
        }
        BluetoothService.pairDevice(d, res => {
            // The user may have pulled it back out while pairing was in flight
            if (b.phase !== "connecting")
                return;
            if (res && res.error) {
                failConnect(b);
                return;
            }
            if (!d.connected)
                BluetoothService.connectDeviceWithTrust(d);
        });
    }

    function failConnect(b) {
        if (!b || b.phase !== "connecting")
            return;
        b.phase = "idle";
        b.shake();
        sounds.play("error");
        wake();
    }

    // Abort an in-flight pairing/connection (device pulled back out of the belt)
    function cancelConnect(b) {
        if (!b || b.phase !== "connecting")
            return;
        const d = b.device;
        b.phase = "idle";
        b.cancelledAt = Date.now();
        if (d) {
            if (d.pairing)
                d.cancelPair();
            d.disconnect();
        }
        b.release();
        emitWave(false);
        sounds.play("disconnect");
        wake();
    }

    function startDisconnect(b) {
        if (!b || !b.device || !b.connected)
            return;
        b.phase = "disconnecting";
        b.device.disconnect();
        wake();
    }

    function forget(b) {
        if (!b || !b.device)
            return;
        clearFocus();
        b.device.forget();
    }

    // Any connection edge, including ones made elsewhere (auto-reconnect)
    function onBodyConnectionChanged(b, isConnected) {
        // BlueZ can still land a connection right after a cancel: undo it quietly
        if (isConnected && Date.now() - b.cancelledAt < 6000) {
            b.device.disconnect();
            return;
        }
        if (isConnected) {
            b.phase = "idle";
            b.celebrate();
            corePulseAnim.restart();
            emitWave(true);
            sounds.play("connect");
        } else {
            b.phase = "idle";
            b.release();
            emitWave(false);
            sounds.play("disconnect");
        }
        wake();
    }

    Timer {
        id: pendingTimer
        interval: 25000
        onTriggered: {
            for (let i = 0; i < bodies.count; i++) {
                const b = bodies.itemAt(i);
                if (b && b.phase === "connecting" && !b.connected)
                    scene.failConnect(b);
            }
        }
    }

    // --- Drag ------------------------------------------------------------------
    function norm(x, y) {
        return Math.hypot((x - cx) / rx, (y - cy) / ry);
    }

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
        const n = norm(p.x, p.y);
        const wasArmed = b.armed;
        // Over the black hole: it wins over connecting or disconnecting
        const hd = Math.hypot(p.x - holeX, p.y - holeY);
        const wasHide = b.hideArmed;
        b.hideArmed = hd < Math.max(holeHorizon * 2.4, bodySize * 0.75);
        holeFeed = Math.max(0, Math.min(1, 1 - (hd - bodySize * 0.6) / (bodySize * 1.6)));
        b.armed = b.hideArmed ? false : b.holding ? n > detachNorm : n < snapNorm;
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
        for (let i = 0; i < bodies.count; i++) {
            const b = bodies.itemAt(i);
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
        if (!focusBody)
            return;
        focusBody = null;
        wake();
    }

    // Escape steps back one level (menu, hidden list, detail card) before it
    // may close the host. A Shortcut runs before the host's own key handler
    // (the bar popout and Control Center keep keyboard focus for themselves),
    // and it is only enabled while there is something to step back from.
    Shortcut {
        sequence: "Escape"
        enabled: scene.active && (scene.menuOpen || scene.hiddenOpen || !!scene.focusBody)
        onActivated: {
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
        const w = waveA.busy ? waveB : waveA;
        w.fire(outward);
    }

    // --- Physics ---------------------------------------------------------------
    function _spring(b, tx, ty, k, zeta, dt) {
        const c = 2 * zeta * Math.sqrt(k);
        b.vx += (k * (tx - b.px) - c * b.vx) * dt;
        b.vy += (k * (ty - b.py) - c * b.vy) * dt;
        b.px += b.vx * dt;
        b.py += b.vy * dt;
    }

    function step(dt) {
        dt = Math.min(dt, 1 / 30);
        clock += dt;
        if (motion) {
            orbitTime += dt;
            holeSpin += dt * (0.32 + 1.8 * holeFeed);
        }

        const n = bodies.count;
        const all = [];
        for (let i = 0; i < n; i++) {
            const b = bodies.itemAt(i);
            if (b)
                all.push(b);
        }

        // Slot assignment: connected ring and outer field, both address-sorted for stability
        const inner = all.filter(b => b.inSlot && !b.leaving).sort((a, b) => a.address < b.address ? -1 : 1);
        const outer = all.filter(b => !b.inSlot && !b.leaving && !b.swallowing).concat([_hole]).sort((a, b) => a.homeHash - b.homeHash);
        const innerPhase = orbitTime * 0.11 - Math.PI / 2;
        const outerPhase = orbitTime * 0.018 - Math.PI / 2;
        const floatAmp = motion ? (dragBody ? 7 : 3.5) : 0;

        let moving = !!dragBody;

        for (const b of all) {
            let tx, ty, k = 70, zeta = 0.58;

            if (!b.spawned) {
                const from = spawnFrom[b.address];
                if (from) {
                    // Spat back out of the black hole
                    b.px = from.x;
                    b.py = from.y;
                    const next = Object.assign({}, spawnFrom);
                    delete next[b.address];
                    spawnFrom = next;
                    b.pop();
                } else {
                    const a = b.homeHash * Math.PI * 2;
                    b.px = cx + Math.cos(a) * rx * 1.25;
                    b.py = cy + Math.sin(a) * ry * 1.25;
                }
                b.spawned = true;
            }

            if (b.focused) {
                tx = cx;
                ty = focusCard.y + focusGlyphLift;
                k = 150;
                zeta = 0.78;
            } else if (b.dragging) {
                tx = dragX;
                ty = dragY;
                k = 700;
                zeta = 0.85;
                const nrm = norm(dragX, dragY);
                // Nearest point on the connected ring, at the pointer's angle
                const ang = Math.atan2((dragY - ringCy) / ringRy, (dragX - cx) / (rx * innerNorm));
                const sx = cx + Math.cos(ang) * rx * innerNorm;
                const sy = ringCy + Math.sin(ang) * ringRy;
                let pull = 0;
                if (b.holding) {
                    // Elastic resistance: gravity holds it until it tears free
                    pull = b.armed ? 0.08 : Math.max(0, 0.5 - (nrm - innerNorm) * 1.4);
                } else if (b.armed) {
                    // Magnet: the closer it gets, the harder the ring pulls
                    const t = Math.min(1, Math.max(0, (snapNorm - nrm) / (snapNorm - innerNorm * 0.6)));
                    pull = 0.45 + 0.4 * t * t * (3 - 2 * t);
                    k = 380;
                    zeta = 0.62;
                }
                tx += (sx - tx) * pull;
                ty += (sy - ty) * pull;
                // The black hole pulls it in, over any ring attraction
                if (b.hideArmed) {
                    tx += (holeX - tx) * 0.55;
                    ty += (holeY - ty) * 0.55;
                    k = 420;
                    zeta = 0.7;
                }
            } else if (b.inSlot) {
                const i = inner.indexOf(b);
                const a = innerPhase + (i / Math.max(1, inner.length)) * Math.PI * 2;
                tx = cx + Math.cos(a) * rx * innerNorm;
                ty = ringCy + Math.sin(a) * ringRy;
                b.depth = Math.sin(a);
                k = 80;
                zeta = 0.7;
            } else {
                const i = outer.indexOf(b);
                const a = outerPhase + ((i + 0.5) / Math.max(1, outer.length)) * Math.PI * 2 + (b.homeHash - 0.5) * 0.35;
                const r = 1 - (1 - outerMinNorm) * Math.min(1, b.signal);
                const ph = b.homeHash * 40;
                tx = cx + Math.cos(a) * rx * r + Math.sin(clock * 0.8 + ph) * floatAmp;
                ty = cy + Math.sin(a) * ry * r + Math.cos(clock * 0.63 + ph) * floatAmp * 0.8;
                b.depth = 0;
            }

            if (b.swallowing) {
                tx = holeX;
                ty = holeY;
                k = 260;
                zeta = 0.9;
            } else if (b.leaving) {
                const a = Math.atan2(b.py - cy, b.px - cx);
                tx = cx + Math.cos(a) * rx * 1.3;
                ty = cy + Math.sin(a) * ry * 1.3;
                k = 30;
            }

            // Gentle repulsion from the dragged body + soft collisions
            if (!b.dragging && !b.focused && !b.swallowing) {
                for (const o of all) {
                    if (o === b || o.leaving)
                        continue;
                    const dx = b.px - o.px, dy = b.py - o.py;
                    const d = Math.max(0.001, Math.hypot(dx, dy));
                    const R = o.dragging ? bodySize * 2.1 : bodySize * 1.05;
                    if (d < R) {
                        const push = (R - d) / R * (o.dragging ? 30 : 12);
                        tx += dx / d * push;
                        ty += dy / d * push;
                    }
                }
                // Keep clear of the host core (the ring may pass behind it)
                const cd = Math.max(0.001, Math.hypot(tx - cx, ty - cy));
                const minD = coreSize * 0.5 + bodySize * 0.55;
                if (cd < minD && !focusBody && !b.inSlot) {
                    tx = cx + (tx - cx) / cd * minD;
                    ty = cy + (ty - cy) / cd * minD;
                }
                // ... and of the black hole, which only takes what is dropped in
                const hd = Math.max(0.001, Math.hypot(tx - holeX, ty - holeY));
                const holeD = holeHorizon * 2.2 + bodySize * 0.6;
                if (hd < holeD && !focusBody) {
                    tx = holeX + (tx - holeX) / hd * holeD;
                    ty = holeY + (ty - holeY) / hd * holeD;
                }
            }

            if (!motion && !b.dragging)
                zeta = 1;

            _spring(b, tx, ty, k, zeta, dt);

            if (Math.abs(b.vx) + Math.abs(b.vy) > 0.6 || Math.abs(tx - b.px) + Math.abs(ty - b.py) > 0.6)
                moving = true;
        }

        // The black hole: an outer-belt slot, floating like the others
        {
            const h = _hole;
            const i = outer.indexOf(h);
            const a = outerPhase + ((i + 0.5) / outer.length) * Math.PI * 2 + (h.homeHash - 0.5) * 0.35;
            const r = 1 - (1 - outerMinNorm) * 0.2;
            const ph = h.homeHash * 40;
            const tx = cx + Math.cos(a) * rx * r + Math.sin(clock * 0.8 + ph) * floatAmp;
            const ty = cy + Math.sin(a) * ry * r + Math.cos(clock * 0.63 + ph) * floatAmp * 0.8;
            if (!h.spawned) {
                h.px = tx;
                h.py = ty;
                h.spawned = true;
            }
            _spring(h, tx, ty, motion ? 70 : 120, motion ? 0.58 : 1, dt);
            holeX = h.px;
            holeY = h.py;
            if (Math.abs(h.vx) + Math.abs(h.vy) > 0.6 || Math.abs(tx - h.px) + Math.abs(ty - h.py) > 0.6)
                moving = true;
        }

        // Sleep when nothing moves and time-driven motion is off
        const timeDriven = motion && awake;
        if (!moving && !timeDriven)
            settled = true;
    }

    FrameAnimation {
        running: scene.active && scene.visible && scene.width > 0 && !scene.settled
        onTriggered: scene.step(frameTime)
    }

    component Wave: Shape {
        id: wave
        property bool busy: anim.running
        property bool outward: true
        // Centered on the ring (not the scene), so it grows from the ring's middle
        width: parent.width
        height: scene.ringCy * 2
        preferredRendererType: Shape.CurveRenderer
        opacity: 0
        transformOrigin: Item.Center

        function fire(out) {
            outward = out;
            anim.restart();
        }

        ShapePath {
            strokeColor: scene.night.primary
            strokeWidth: 1.6
            fillColor: "transparent"
            PathAngleArc {
                centerX: scene.cx
                centerY: scene.ringCy
                radiusX: scene.rx * scene.innerNorm
                radiusY: scene.ringRy
                startAngle: 0
                sweepAngle: 360
            }
        }

        ParallelAnimation {
            id: anim
            NumberAnimation {
                target: wave
                property: "scale"
                from: wave.outward ? 0.35 : 1.15
                to: wave.outward ? 1.35 : 0.3
                duration: 900
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: wave
                    property: "opacity"
                    from: 0
                    to: 0.75
                    duration: 120
                }
                NumberAnimation {
                    target: wave
                    property: "opacity"
                    to: 0
                    duration: 780
                    easing.type: Easing.InQuad
                }
            }
        }
    }

    // --- Background --------------------------------------------------------------
    // Desktop glass: a theme-tinted smoky veil that dissolves into the wallpaper
    Vignette {
        visible: scene.glass
        color: Qt.tint("#05060a", Theme.withAlpha(scene.night.primary, 0.07))
        strength: scene.prefs.desktopBackdrop
    }

    Starfield {
        id: stars
        x: -12 + (scene.dragBody ? -(scene.dragX - scene.cx) * 0.025 : 0)
        y: -12 + (scene.dragBody ? -(scene.dragY - scene.cy) * 0.025 : 0)
        width: scene.width + 24
        height: scene.height + 24
        clock: scene.clock
        animate: scene.motion && scene.active
        shootingStars: scene.prefs.shootingStars && scene.awake
        density: scene.prefs.starDensity
        vignette: scene.glass
        radius: scene.cornerRadius
        inset: 12
        Behavior on x {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
            }
        }
    }

    BlackHole {
        id: blackHole
        scene: orbitRoot
        sky: stars
        x: scene.holeX - width / 2
        y: scene.holeY - height / 2
        count: scene.hiddenCount
        feed: scene.holeFeed
        spin: scene.holeSpin
        visible: scene.btOn && scene.width > 0
        onClicked: scene.hiddenOpen ? scene.closeHidden() : scene.openHidden()
        Behavior on feed {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // Dims the backdrop in focus mode (elliptical on glass: no hard edge)
    Item {
        anchors.fill: parent
        opacity: scene.focusBody || scene.hiddenOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: !scene.glass
            radius: scene.cornerRadius
            color: "black"
            opacity: 0.4
        }
        Vignette {
            visible: scene.glass
            color: "black"
            strength: 0.6
        }
    }

    // Click on empty space leaves focus mode
    MouseArea {
        anchors.fill: parent
        enabled: !!scene.focusBody || scene.hiddenOpen
        onClicked: {
            scene.clearFocus();
            scene.closeHidden();
        }
    }

    // --- World -------------------------------------------------------------------
    Item {
        id: worldItem
        anchors.fill: parent

        readonly property real dim: scene.focusBody || scene.hiddenOpen ? 0.12 : 1

        // Outer field: dotted orbit
        Repeater {
            model: 64
            Rectangle {
                readonly property real a: index / 64 * Math.PI * 2
                readonly property real r: (1 + scene.outerMinNorm) / 2
                x: scene.cx + Math.cos(a) * scene.rx * r - 0.75
                y: scene.cy + Math.sin(a) * scene.ry * r - 0.75
                width: 1.5
                height: 1.5
                radius: 0.75
                color: "white"
                opacity: 0.2 * worldItem.dim * (scene.btOn ? 1 : 0.3)
                visible: scene.width > 0
            }
        }

        // Connected orbit ring
        Shape {
            id: innerRing
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: worldItem.dim * (scene.btOn ? 1 : 0.3)

            readonly property bool guiding: !!scene.dragBody && !scene.dragBody.holding
            readonly property bool armedIn: guiding && scene.dragBody.armed

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }

            ShapePath {
                strokeColor: innerRing.armedIn ? Theme.withAlpha(scene.night.primary, 0.85) : innerRing.guiding ? Theme.withAlpha(scene.night.primary, 0.45) : Qt.rgba(1, 1, 1, 0.1)
                strokeWidth: innerRing.armedIn ? 1.8 : 1
                fillColor: innerRing.armedIn ? Theme.withAlpha(scene.night.primary, 0.05) : "transparent"
                PathAngleArc {
                    centerX: scene.cx
                    centerY: scene.ringCy
                    radiusX: scene.rx * scene.innerNorm
                    radiusY: scene.ringRy
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // Radar ping while discovering
        Rectangle {
            id: ping
            x: scene.cx - width / 2
            y: scene.cy - height / 2
            width: scene.coreSize
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: scene.night.primary
            opacity: 0
            visible: scene.discovering && scene.active && scene.motion

            ParallelAnimation {
                running: ping.visible
                loops: Animation.Infinite
                ScaleAnimator {
                    target: ping
                    from: 1
                    to: 3.2
                    duration: 2600
                    easing.type: Easing.OutCubic
                }
                OpacityAnimator {
                    target: ping
                    from: 0.35
                    to: 0
                    duration: 2600
                    easing.type: Easing.OutQuad
                }
            }
        }

        // Connection waves (elliptical, follow the orbit's perspective)
        Wave {
            id: waveA
        }
        Wave {
            id: waveB
        }

        Item {
            id: tetherLayerItem
            anchors.fill: parent
        }

        // Host core
        Item {
            id: core
            x: scene.cx - width / 2
            y: scene.cy - height / 2
            width: scene.coreSize
            height: width
            z: 50
            opacity: scene.focusBody || scene.hiddenOpen ? 0.15 : scene.btOn ? 1 : 0.45
            scale: (scene.motion ? 1 + 0.018 * Math.sin(scene.clock * 1.3) : 1) * corePulse.value

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }

            QtObject {
                id: corePulse
                property real value: 1
            }

            SequentialAnimation {
                id: corePulseAnim
                NumberAnimation {
                    target: corePulse
                    property: "value"
                    to: 1.08
                    duration: 140
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: corePulse
                    property: "value"
                    to: 1
                    duration: 520
                    easing.type: Easing.OutBack
                    easing.overshoot: 2
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.9
                height: width
                radius: width / 2
                color: Theme.withAlpha(scene.night.primary, scene.btOn ? 0.05 : 0.0)
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.4
                height: width
                radius: width / 2
                color: Theme.withAlpha(scene.night.primary, scene.btOn ? 0.08 : 0.02)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: scene.night.whiteBodies ? Qt.tint("#FFFFFF", Theme.withAlpha(Theme.primary, 0.08)) : Qt.tint("#1a1c22", Theme.withAlpha(scene.night.primary, 0.22))
                    }
                    GradientStop {
                        position: 1
                        color: scene.night.whiteBodies ? Qt.tint("#E6ECF2", Theme.withAlpha(Theme.primary, 0.16)) : Qt.tint("#0b0c10", Theme.withAlpha(scene.night.primary, 0.1))
                    }
                }
                border.width: 1
                border.color: Theme.withAlpha(scene.night.primary, scene.btOn ? 0.4 : 0.12)
            }
            DeviceGlyph {
                anchors.centerIn: parent
                width: parent.width * 0.5
                height: width
                kind: scene.prefs.hostGlyph !== "auto" ? scene.prefs.hostGlyph : (BatteryService.batteryAvailable ? "laptop" : "desktop")
                color: scene.btOn ? (scene.night.whiteBodies ? scene.night.bodyInk : Qt.lighter(scene.night.primary, 1.2)) : (scene.night.whiteBodies ? scene.night.bodyMuted : Qt.rgba(1, 1, 1, 0.4))
                stroke: 1.4
            }

            // Only the inner 70% starts a scan, and never over a device
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: scene.btOn && !scene.focusBody
                onPressed: mouse => {
                    const inner = Math.hypot(mouse.x - width / 2, mouse.y - height / 2) < width * 0.35;
                    const p = mapToItem(scene, mouse.x, mouse.y);
                    mouse.accepted = inner && !scene.bodyAt(p.x, p.y);
                }
                onClicked: {
                    scene.startScan();
                    scene.emitWave(true);
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: core.horizontalCenter
            y: core.y + core.height + 4
            z: 50
            text: UserInfoService.hostname || ""
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: Math.max(9, Math.round(scene.coreSize * 0.14))
            font.letterSpacing: 0.6
            opacity: scene.focusBody ? 0 : 1
        }

        Repeater {
            id: bodies
            model: bodyModel
            delegate: DeviceBody {
                scene: orbitRoot
            }
        }

        // Black hole contents, slides up like the focus card
        HiddenCard {
            scene: orbitRoot
            z: 15000
            width: scene.focusCardWidth
            height: Math.min(implicitHeight, scene.height - Theme.spacingM * 2)
            x: (scene.width - width) / 2
            y: scene.hiddenOpen ? scene.height - height - Theme.spacingM : scene.height + 20
            opacity: scene.hiddenOpen ? 1 : 0
            visible: opacity > 0.01

            Behavior on y {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 260
                }
            }
        }

        // Focus card (bodies are siblings, so the focused glyph can sit above it)
        FocusCard {
            id: focusCard
            scene: orbitRoot
            z: 15000
            width: scene.focusCardWidth
            height: Math.min(implicitHeight, scene.height - scene.focusGlyphSize * 0.35 - Theme.spacingM)
            x: (scene.width - width) / 2
            y: scene.focusBody ? scene.height - height - Theme.spacingM : scene.height + 20
            opacity: scene.focusBody ? 1 : 0
            visible: opacity > 0.01

            Behavior on y {
                NumberAnimation {
                    duration: 480
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }
    }

    // --- Chrome --------------------------------------------------------------------
    // Contextual hint
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: scene.glass ? Math.round(scene.height * 0.1) : Theme.spacingS
        opacity: scene.focusBody || scene.hiddenOpen ? 0 : text ? 0.6 : 0
        color: "white"
        font.pixelSize: Theme.fontSizeSmall - 1
        font.letterSpacing: 0.4
        text: {
            const b = scene.dragBody;
            if (b && b.hideArmed)
                return "Release to hide";
            if (b) {
                if (b.phase === "connecting")
                    return b.armed ? "Release to cancel" : "Pull away to cancel";
                if (b.connected)
                    return b.armed ? "Release to disconnect" : "Pull away to disconnect";
                return b.armed ? "Release to connect" : "Bring it closer to connect";
            }
            if (!scene.btOn)
                return "";
            if (bodyModel.count === 0)
                return scene.discovering ? "Looking for devices..." : "Tap the center to scan";
            return "";
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // Scan chip. On glass it is centered, carries its own smoky pill so it
    // reads on any wallpaper, and only shows while the widget is in use.
    Rectangle {
        anchors.top: parent.top
        anchors.right: scene.glass ? undefined : parent.right
        anchors.horizontalCenter: scene.glass ? parent.horizontalCenter : undefined
        anchors.margins: Theme.spacingS
        anchors.topMargin: scene.glass ? Math.round(scene.height * 0.07) : Theme.spacingS
        height: 24
        width: chipRow.implicitWidth + 16
        radius: 12
        color: scene.glass ? (chipArea.containsMouse ? Qt.rgba(0.1, 0.11, 0.14, 0.78) : Qt.rgba(0.04, 0.045, 0.06, 0.6)) : chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
        border.width: scene.glass ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.08)
        readonly property bool shown: scene.btOn && !scene.focusBody && !scene.hiddenOpen && (!scene.glass || scene.interacting || scene.discovering)
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Rectangle {
                id: scanDot
                width: 6
                height: 6
                radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: scene.discovering ? scene.night.primary : Qt.rgba(1, 1, 1, 0.35)
                // Animators: the blink runs on the render thread
                SequentialAnimation on opacity {
                    running: scene.discovering && scene.active && scene.motion
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                        scanDot.opacity = 1
                    OpacityAnimator {
                        to: 0.25
                        duration: 700
                    }
                    OpacityAnimator {
                        to: 1
                        duration: 700
                    }
                }
            }
            StyledText {
                text: scene.discovering ? "Scanning" : "Scan"
                color: Qt.rgba(1, 1, 1, 0.75)
                font.pixelSize: Theme.fontSizeSmall - 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: scene.discovering ? scene.stopScan() : scene.startScan()
        }
    }

    // Bluetooth off / missing adapter
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.cy + scene.coreSize * 0.5 + 26
        spacing: Theme.spacingS
        visible: !scene.btOn

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: BluetoothService.available ? "Bluetooth is off" : "No Bluetooth adapter"
            color: Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: Theme.fontSizeSmall
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: BluetoothService.available
            width: onText.implicitWidth + 28
            height: 30
            radius: 15
            color: onArea.containsMouse ? Theme.withAlpha(scene.night.primary, 0.35) : Theme.withAlpha(scene.night.primary, 0.2)
            StyledText {
                id: onText
                anchors.centerIn: parent
                text: "Turn on"
                color: scene.night.primary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }
            MouseArea {
                id: onArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.setBluetoothEnabled(true)
            }
        }
    }

    // Right-click menu, above everything else
    OrbitMenu {
        id: menu
        scene: orbitRoot
        z: 30000
    }
}
