import QtQuick
import qs.Common
import "components/device"
import "components/scene"

// Test of the charge's colour: the energy beam, the earbuds' bolt (through
// NightColors.chargingTheme) and the battery arc all read the same tone, and
// where the theme has no tone to tell it from the primary (the stock Blue and
// Cyan, light and dark) the arc carries a bolt marker instead of a shifted hue.
// The themes below are DMS's stock ones (no tertiary: it falls back to the
// secondary). Run with tests/qml/run.sh.
Item {
    id: h
    width: 80
    height: 80

    NightColors {
        id: tones
    }
    EnergyBeam {
        id: beam
        width: 20
        height: 10
    }
    QtObject {
        id: fake
        property int battery: 60
        property bool charging: true
        property bool connected: true
        property bool focused: false
        property string ancMode: ""
        property real diameter: 60
        readonly property var night: tones
        readonly property var scene: ({
                "motion": false,
                "awake": false,
                "fxTime": 0
            })
    }
    BodyArcs {
        id: arcs
        anchors.fill: parent
        body: fake
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // WCAG contrast of a colour on the night sky: how well it reads there
    function lum(c) {
        const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }
    function contrastOnSky(c) {
        const a = lum(c), b = lum(tones.sky);
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    }
    function apart(a, b) {
        return Math.hypot(a.r - b.r, a.g - b.g, a.b - b.b);
    }
    function marker() {
        return arcs.children.find(c => c.orbit !== undefined);
    }
    function theme(light, primary, secondary) {
        Theme.isLightMode = light;
        Theme.primary = primary;
        Theme.secondary = secondary;
        Theme.tertiary = secondary;
        Theme.info = "#2196F3";
    }

    Component.onCompleted: {
        // [name, light, primary, secondary, a tone of its own?]
        const stock = [["lime (the preview's default)", false, "#C5E66A", "#BFCBAD", true], ["Blue dark", false, "#42a5f5", "#8ab4f8", false], ["Blue light", true, "#1976d2", "#42a5f5", false], ["Cyan dark", false, "#00bcd4", "#4dd0e1", false], ["Cyan light", true, "#0097a7", "#00bcd4", false]];
        for (const [name, light, primary, secondary, own] of stock) {
            theme(light, primary, secondary);
            check(name + ": the arc, the beam and the card's bolt share one tone", [arcs.tint === tones.charging, beam.color === tones.charging, tones.night(tones.chargingTheme) === tones.charging], [true, true, true]);
            check(name + ": the charge reads on the night sky (contrast >= 3)", contrastOnSky(tones.charging) >= 3, true);
            check(name + ": a tone of its own is told from the primary: " + own, tones.chargingApart, own);
            check(name + ": the bolt marker shows only where the tone is not its own", marker().visible, !own);
            check(name + ": the marker reads on the sky too", contrastOnSky(arcs.tint) >= 3, true);
        }

        theme(false, "#42a5f5", "#8ab4f8");
        fake.charging = false;
        check("not charging: no marker, even in Blue", marker().visible, false);
        fake.charging = true;
        fake.focused = true;
        check("a focused device draws no ring and no marker", marker().visible, false);
        fake.focused = false;
        fake.battery = 25;
        const lowAngle = marker().angle;
        fake.battery = 75;
        check("the marker rides the head of the level arc (25 % to 75 % is half a turn)", Math.round((marker().angle - lowAngle) / Math.PI * 180), 180);

        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }
}
