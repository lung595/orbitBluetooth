import QtQuick
import "Polar.js" as Polar

// What the vectorscope shows of the sound, computed once for every screen
// that shows it (the pop-up on each screen, the island): PolarVisual only
// paints it. Moved by its feed's frames (cava's rate), and by its own
// Timer only while the light fades after the sound stops; it stops by
// itself. Styles (Settings → Sound → Visualizer):
//  - points: a dense cloud, each dot born from one band of the latest
//    frame (Polar.spawn), fading as it drifts outward like phosphor;
//  - rays:   the spectrum as a fan of rays with falling peak marks;
//  - waves:  the spectrum as one live curve, nothing left behind.
Item {
    id: model

    // A ScopeFeed: its frames move the picture (null in previews: simulate)
    property var feed: null
    property string style: "points"
    // The volume heard (0..1): the picture is drawn that big (Polar.scaleFor),
    // eased so a volume step makes it grow, not jump
    property real gain: 1
    property real heard: gain
    property int fps: 60

    // Something is still on screen
    property int alive: 0
    // A new picture to paint
    signal updated

    // --- Points ---------------------------------------------------------------
    readonly property int pool: 720
    readonly property real lifetime: 0.6 // seconds
    readonly property real rate: 1900 // dots per second at full loudness
    property var dots: []
    property real _carry: 0
    property int _band: 0

    // --- Rays and waves: meter-like levels ----------------------------------------
    readonly property int raysPerSide: 16
    property var levels: Polar.emptyLevels()
    property var peaks: []

    property double _last: 0
    function _step(frame) {
        const now = Date.now();
        const dt = _last ? Math.max(0.001, Math.min(0.1, (now - _last) / 1000)) : 1 / fps;
        _last = now;
        advance(dt, frame);
    }
    Connections {
        target: model.feed
        function onArrived() {
            fade.stop();
            model._step(model.feed.frame);
            if (model.alive > 0)
                silence.restart();
            else
                silence.stop();
        }
        function onActiveChanged() {
            if (!model.feed.active)
                model.clear();
        }
    }
    readonly property int _period: Math.round(1000 / Math.max(10, fps))
    // No frame for two periods (paused player): the light starts fading out
    // alone. Waiting a single period would race cava's own clock, and a frame
    // a little late would get a blank step before it
    Timer {
        id: silence
        interval: 2 * model._period
        onTriggered: fade.start()
    }
    Timer {
        id: fade
        interval: model._period
        repeat: true
        onTriggered: {
            model._step(null);
            if (model.alive === 0)
                stop();
        }
    }
    // Exposed for tests: nothing runs at rest
    readonly property bool animating: silence.running || fade.running

    function advance(dt, frame) {
        const was = alive;
        heard = Polar.ease(heard, gain, dt, 9);
        if (style === "points")
            _advanceDots(dt, frame);
        else if (style === "rays" || style === "waves")
            _advanceLevels(dt, frame);
        else
            alive = 0;
        // Silence on a blank picture: nothing new to paint
        if (was > 0 || alive > 0)
            updated();
    }

    function _advanceDots(dt, frame) {
        const r = radiusFor(1);
        const kept = [];
        for (let i = 0; i < dots.length; i++) {
            const p = dots[i];
            p.life += dt / lifetime;
            if (p.life < 1)
                kept.push(p);
        }
        if (frame) {
            _carry += rate * dt * (0.2 + 0.8 * Polar.loudness(frame));
            const bands = frame.l.length;
            // A silent band spawns nothing: a bounded number of tries
            for (let tries = 0; _carry >= 1 && kept.length < pool && tries < pool; tries++) {
                // Bands in turn, so every part of the sound gets its dots
                _band = (_band + 1) % bands;
                _carry -= 1;
                const p = Polar.spawn(frame, _band, r, Math.random(), Math.random(), Math.random());
                if (p)
                    kept.push(p);
            }
            _carry = Math.min(_carry, 8);
        }
        dots = kept;
        alive = kept.length;
    }

    function _advanceLevels(dt, frame) {
        const n = frame ? frame.l.length : levels.l.length;
        let live = 0;
        const next = Polar.emptyLevels();
        for (let i = 0; i < n; i++) {
            next.l.push(Polar.follow(levels.l[i] || 0, frame ? frame.l[i] : 0, dt));
            next.r.push(Polar.follow(levels.r[i] || 0, frame ? frame.r[i] : 0, dt));
            if (next.l[i] > 0.004 || next.r[i] > 0.004)
                live++;
        }
        levels = next;
        if (style === "rays") {
            // Peak marks hold, then fall slower than the rays
            const angles = Polar.rayAngles(raysPerSide);
            const kept = [];
            for (let k = 0; k < angles.length; k++) {
                const v = Polar.levelAt(next, angles[k]);
                kept.push(Math.max(v, (peaks[k] || 0) - dt * 0.45, 0));
                if (kept[k] > 0.004)
                    live++;
            }
            peaks = kept;
        }
        alive = live;
    }

    // Dots are stored for a unit radius: each screen scales them to its own
    // size, so one cloud serves screens of any size
    function radiusFor(r) {
        return r * Polar.scaleFor(heard);
    }

    function clear() {
        silence.stop();
        fade.stop();
        dots = [];
        _carry = 0;
        levels = Polar.emptyLevels();
        peaks = [];
        heard = gain;
        _last = 0;
        alive = 0;
        updated();
    }
    onStyleChanged: clear()

    // Fills the picture from a made-up frame, for previews and tests
    function simulate(frame, seconds) {
        for (let t = 0; t < seconds; t += 1 / fps)
            advance(1 / fps, frame);
    }
}
