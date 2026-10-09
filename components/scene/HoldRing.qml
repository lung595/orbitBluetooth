pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.Common
import "Hold.js" as Hold

// The long press of a pointer (D368): fills a ring over the zone it sits on while
// the press is held, and says `held` once when the hold is done. The pointer
// calls begin() on a press, cancel() when the press ends or turns into a drag,
// and reads `fired` on the release to know that the click is spent. The Timer
// runs only during the press (30 Hz, a Timer and not an animation, so only this
// window redraws, never the whole shell); at rest nothing here exists in the
// scene graph's way: the ring is not visible and the Timer is stopped.
Item {
    id: hold

    // The scene's night palette, for the ring's colour
    required property var night
    // True once the hold has been done, until the pointer calls cancel()
    readonly property bool fired: hold._fired
    readonly property bool active: tick.running

    property bool _fired: false
    property double _start: 0
    property double _elapsed: 0
    readonly property double elapsed: hold._elapsed

    signal held

    anchors.fill: parent

    function begin() {
        hold._fired = false;
        hold._start = Date.now();
        hold._elapsed = 0;
        tick.start();
    }
    // Ends the press: the ring goes, `fired` is forgotten
    function cancel() {
        tick.stop();
        hold._fired = false;
        hold._elapsed = 0;
    }

    Timer {
        id: tick
        interval: 33
        repeat: true
        onTriggered: {
            hold._elapsed = Date.now() - hold._start;
            if (!Hold.done(hold.elapsed))
                return;
            tick.stop();
            hold._fired = true;
            hold.held();
        }
    }

    // Painted only while the press is held and past the plain-click delay
    Loader {
        anchors.fill: parent
        active: tick.running && Hold.ringVisible(hold.elapsed)
        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.withAlpha(hold.night.primary, 0.9)
                strokeWidth: 3
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    centerX: hold.width / 2
                    centerY: hold.height / 2
                    radiusX: hold.width / 2 - 2
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * Hold.progress(hold.elapsed)
                }
            }
        }
    }
}
