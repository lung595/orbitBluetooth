import QtQuick
import "Physics.js" as Physics

// Drives the orbit scene: one step() moves every body and the black hole,
// advances the clocks, then decides how often the next step comes.
//  - display-synced (FrameAnimation) only during a gesture and its
//    aftermath: a running QML animation keeps every shell window (bars,
//    wallpaper...) redrawing at the display rate (rule 23);
//  - otherwise a plain Timer: 60 Hz for a fast effect (a comet, an open
//    card), 30 Hz for the drift, 20 Hz for Ambient alone on the desktop;
//  - nothing at all once the scene has settled.
Item {
    id: physics
    required property var scene
    required property Repeater repeater  // the device bodies
    required property var card           // the detail card: a focused body becomes its glyph

    readonly property bool _stepping: scene.active && scene.visible && scene.width > 0 && !scene.settled
    readonly property bool _fullRate: !!scene.dragBody || _lively
    // Lively: a gesture's aftermath (a device released, snapping into or out
    // of the ring, flying to its card) stays display-synced until everything
    // has slowed down, so the motion is smooth to the very end.
    property bool _lively: false
    property real _calmFor: 0
    property bool _fxFast: false
    property bool _ambientOnly: false
    // The black hole moves with the same spring as the bodies; homeHash
    // orders it among the devices of the outer belt
    readonly property var _hole: ({
            "px": 0,
            "py": 0,
            "vx": 0,
            "vy": 0,
            "spawned": false,
            "homeHash": 0.62
        })

    function kick() {
        _lively = true;
        _calmFor = 0;
        scene.settled = false;
    }

    // Places a body for its first frame: spat out of the black hole, or at
    // its own spot just outside the belt
    function _spawn(b) {
        const from = scene.spawnFrom[b.address];
        if (from) {
            b.px = from.x;
            b.py = from.y;
            const next = Object.assign({}, scene.spawnFrom);
            delete next[b.address];
            scene.spawnFrom = next;
            b.pop();
        } else {
            const a = b.homeHash * Math.PI * 2;
            b.px = scene.cx + Math.cos(a) * scene.rx * 1.25;
            b.py = scene.cy + Math.sin(a) * scene.ry * 1.25;
        }
        b.spawned = true;
    }

    // Where body b wants to be this step, and how stiffly it gets there
    function _target(b, all, inner, outer, innerPhase, outerPhase, amp) {
        const s = scene;
        let t;
        if (b.focused) {
            t = {
                "x": s.cx,
                "y": card.y + s.focusGlyphLift,
                "k": 150,
                "zeta": 0.78
            };
        } else if (b.dragging) {
            t = Physics.dragTarget(s, b, s.dragX, s.dragY);
        } else if (b.inSlot) {
            const slot = Physics.ringSlot(s, inner.indexOf(b), inner.length, innerPhase);
            b.depth = slot.depth;
            t = {
                "x": slot.x,
                "y": slot.y,
                "k": 80,
                "zeta": 0.7
            };
        } else {
            const slot = Physics.beltSlot(s, outer.indexOf(b), outer.length, outerPhase, b.homeHash, Physics.beltRadius(s, b.signal), s.clock, amp);
            b.depth = 0;
            t = {
                "x": slot.x,
                "y": slot.y,
                "k": 70,
                "zeta": 0.58
            };
        }
        if (b.swallowing) {
            t = {
                "x": s.holeX,
                "y": s.holeY,
                "k": 260,
                "zeta": 0.9
            };
        } else if (b.leaving) {
            const a = Math.atan2(b.py - s.cy, b.px - s.cx);
            t.x = s.cx + Math.cos(a) * s.rx * 1.3;
            t.y = s.cy + Math.sin(a) * s.ry * 1.3;
            t.k = 30;
        }
        if (!b.dragging && !b.focused && !b.swallowing)
            Physics.separate(s, b, t, all, !!s.focusBody);
        if (!s.motion && !b.dragging)
            t.zeta = 1;
        return t;
    }

    function step(dt) {
        const s = scene;
        dt = Math.min(dt, 1 / 30);
        // Effects clock (charge glow and beam, comet, earbuds, gauge, scan):
        // effects are plain bindings on it, never looping QML animations
        s.fxTime += dt;
        // Time-driven motion (orbits, float, twinkles) only while awake: asleep,
        // the targets hold still so the bodies can settle and the loop stops.
        const timeDriven = s.motion && s.awake;
        if (timeDriven) {
            s.clock += dt;
            s.orbitTime += dt;
            s.holeSpin += dt * (0.32 + 1.8 * s.holeFeed);
        }

        const all = [];
        for (let i = 0; i < repeater.count; i++) {
            const b = repeater.itemAt(i);
            if (b)
                all.push(b);
        }

        // Slot assignment: connected ring and outer field, both address-sorted for stability
        const inner = all.filter(b => b.inSlot && !b.leaving).sort((a, b) => a.address < b.address ? -1 : 1);
        const outer = all.filter(b => !b.inSlot && !b.leaving && !b.swallowing).concat([physics._hole]).sort((a, b) => a.homeHash - b.homeHash);
        const innerPhase = s.orbitTime * 0.11 - Math.PI / 2;
        const outerPhase = s.orbitTime * 0.018 - Math.PI / 2;
        const amp = timeDriven ? (s.dragBody ? 7 : 3.5) : 0;

        let moving = !!s.dragBody;
        let maxLag = 0;     // px, farthest any body is from where it should be
        for (const b of all) {
            if (!b.spawned)
                _spawn(b);
            const t = _target(b, all, inner, outer, innerPhase, outerPhase, amp);
            Physics.spring(b, t.x, t.y, t.k, t.zeta, dt);
            if (!b.dragging)
                maxLag = Math.max(maxLag, Math.hypot(t.x - b.px, t.y - b.py));
            moving = moving || Physics.moving(b, t.x, t.y);
        }

        // The black hole: an outer-belt slot, floating like the others
        const h = physics._hole;
        const slot = Physics.beltSlot(s, outer.indexOf(h), outer.length, outerPhase, h.homeHash, Physics.beltRadius(s, 0.2), s.clock, amp);
        if (!h.spawned) {
            h.px = slot.x;
            h.py = slot.y;
            h.spawned = true;
        }
        Physics.spring(h, slot.x, slot.y, s.motion ? 70 : 120, s.motion ? 0.58 : 1, dt);
        s.holeX = h.px;
        s.holeY = h.py;
        moving = moving || Physics.moving(h, slot.x, slot.y);

        // A body far from its place (released, snapping, flying to a card)
        // switches to display-synced frames; back to the timer after 0.25 s
        // with every body tracking its place (a few px of lag while orbiting,
        // whatever the orbit speed or the view size)
        if (maxLag > 24)
            kick();
        else if (_lively && !s.dragBody && maxLag < 6) {
            _calmFor += dt;
            if (_calmFor > 0.25)
                _lively = false;
        } else
            _calmFor = 0;

        // Visible effects keep the steps coming: a comet while connecting (even
        // with Reduce motion, it is the progress indicator), the rest only
        // with motion on
        let fx = false, comet = false;
        if (s.awake) {
            fx = (s.discovering || !!s.focusBody) && s.motion;
            for (const b of all) {
                if (b.phase === "connecting")
                    comet = true;
                if (b.charging && s.motion)
                    fx = true;
            }
            fx = fx || comet;
        }
        const fast = comet || !!s.focusBody;
        if (_fxFast !== fast)
            _fxFast = fast;
        // Ambient's slow drift on the desktop with nobody around: bodies move
        // a few px per second, more frames would not show (P123)
        const ambientOnly = s.freezeWhenIdle && !s.interacting && !s.dragBody && !s.focusBody && !fx;
        if (_ambientOnly !== ambientOnly)
            _ambientOnly = ambientOnly;

        // Sleep when nothing moves and time-driven motion is off
        if (!moving && !timeDriven && !fx) {
            s.settled = true;
            _lively = false;
        }
    }

    FrameAnimation {
        running: physics._stepping && physics._fullRate
        onTriggered: physics.step(frameTime)
    }
    Timer {
        interval: physics._fxFast ? 16 : (physics._ambientOnly ? 50 : 33)
        repeat: true
        running: physics._stepping && !physics._fullRate
        property double last: 0
        onRunningChanged: last = Date.now()
        onTriggered: {
            const t = Date.now();
            physics.step((t - last) / 1000);
            last = t;
        }
    }
}
