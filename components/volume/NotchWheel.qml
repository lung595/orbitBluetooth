import QtQuick

// A mouse wheel or touchpad counted in whole notches: touchpads send small
// deltas, which are added up until they make a notch. One place for it, so
// every volume gesture counts the same way.
WheelHandler {
    id: wheel

    // `notches` whole notches turned (positive: up) with the pointer at (x, y)
    signal turned(int notches, real x, real y)

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    property real _sum: 0
    onWheel: e => {
        _sum += e.angleDelta.y;
        const notches = Math.trunc(_sum / 120);
        if (notches === 0)
            return;
        _sum -= notches * 120;
        wheel.turned(notches, e.x, e.y);
    }
}
