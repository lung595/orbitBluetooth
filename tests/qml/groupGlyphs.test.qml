import QtQuick
import qs.Common
import qs.Services
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of the group's icons (D298 follow-up): a Listen together is said by one
// round disc per member under the group, never by a name. Nothing exists
// without a group; with one, the discs are the members' in order, source first,
// each wearing the glyph its own body wears; no text is there until the pointer
// asks for the names; and in both views the row clears what is around it: the
// group's volume ring and Fedora's disc (the old name crossed it). Run with
// tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"

    FakeRoute {
        id: route
    }
    OrbitScene {
        id: scene
        anchors.fill: parent
        active: true
        autoScan: false
        previewDevices: Devices.list(false, 2)
        audioRoute: route
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // The row of icons: the one item that has `glyphOf`
    function find(item, prop) {
        for (const child of item.children) {
            if (prop in child)
                return child;
            const found = find(child, prop);
            if (found)
                return found;
        }
        return null;
    }
    // How many texts are drawn in the subtree (a name would be one)
    function texts(item) {
        let n = "text" in item && item.visible ? 1 : 0;
        for (const child of item.children)
            n += texts(child);
        return n;
    }
    // The row's box in the scene
    function box(item) {
        const p = item.mapToItem(scene, 0, 0);
        return {
            "x": p.x,
            "y": p.y,
            "w": item.width,
            "h": item.height
        };
    }
    // How far the box is from a circle's edge (px, negative: they overlap)
    function clearance(b, c) {
        const dx = Math.max(b.x - c.x, 0, c.x - (b.x + b.w));
        const dy = Math.max(b.y - c.y, 0, c.y - (b.y + b.h));
        return Math.hypot(dx, dy) - c.r;
    }
    // The two circles a row must not touch: Fedora's disc and the group's ring
    function around() {
        const c = scene.centre;
        return [c.core,
            {
                "x": c.group.x,
                "y": c.group.y,
                "r": c.sizes.ring * c.group.scale
            }
        ];
    }

    readonly property var steps: [
        {
            "then": 400,
            "run": () => {
                check("no group: no icons are made", h.find(scene, "glyphOf"), null);
                route.sharing = [h.headset, h.one, h.two];
            }
        },
        {
            "then": 2500,
            "run": () => {
                const icons = h.find(scene, "glyphOf");
                const bodyKind = a => scene.world.bodyList().find(b => b.address === a).kind;
                check("a group: the icons are made, the source first", [!!icons, icons.shown], [true, [h.headset, h.one, h.two]]);
                check("each disc wears the glyph its own body wears", icons.shown.map(a => icons.glyphOf(a)), icons.shown.map(bodyKind));
                check("no name is drawn, the glyphs are", [h.texts(icons), icons.children.length > 0], [0, true]);
                const b = h.box(icons);
                const c = scene.centre;
                check("in the middle: centred under the group, under its ring", [Math.abs(b.x + b.w / 2 - c.group.x) < 1, b.y >= c.group.y + c.sizes.ring * c.group.scale], [true, true]);
                check("and clear of the host's disc and of the ring", h.around().map(circle => h.clearance(b, circle) > 0), [true, true]);
                icons.named = true;
                check("the names are only in the tip, one line per member", h.texts(icons), icons.shown.length);
                icons.named = false;
                check("and gone again with it", h.texts(icons), 0);
                scene.centre.recall();
            }
        },
        {
            "then": 1500,
            "run": () => {
                const icons = h.find(scene, "glyphOf");
                const b = h.box(icons);
                const c = scene.centre;
                check("Fedora's view: the group is smaller, so are its discs", icons.disc < scene.coreSize * 0.34 + 0.5, true);
                check("the icons clear Fedora's disc and the group's ring (P183)", h.around().map(circle => h.clearance(b, circle) > 0), [true, true]);
                check("over the group on the far side of the ring, under it on the near side", b.y > c.group.y, c.group.depth >= 0);
                scene.centre.release();
            }
        },
        {
            "then": 1500,
            "run": () => {
                const icons = h.find(scene, "glyphOf");
                check("back on the group: the icons are under it again (counter-proof)", h.box(icons).y > scene.centre.group.y, true);
                route.sharing = [];
            }
        },
        {
            "then": 2500,
            "run": () => {
                check("the group ended: the icons are gone", h.find(scene, "glyphOf"), null);
            }
        }
    ]
    property int step: 0
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 30000
        running: true
        onTriggered: {
            print("FAIL timed out at step " + h.step);
            Qt.exit(1);
        }
    }
    Timer {
        id: clock
        onTriggered: h.next()
    }
    function next() {
        if (step >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        const s = steps[step++];
        s.run();
        clock.interval = s.then;
        clock.start();
    }
    Component.onCompleted: {
        PluginService.globalVars = State.globals("orbit", Date.now());
        Qt.callLater(next);
    }
}
