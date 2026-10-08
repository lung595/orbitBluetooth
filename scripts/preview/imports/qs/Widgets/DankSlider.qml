import QtQuick

// Stands in for DMS's DankSlider offscreen: the same value, range and signals,
// and two helpers that do to them what the pointer does. A drag assigns `value`
// (which breaks a plain binding of it), then says so; letting go says it ended.
Item {
    id: slider

    property int value: 50
    property int minimum: 0
    property int maximum: 100
    property int step: 1
    property string unit: "%"
    property bool showValue: true
    property bool wheelEnabled: true

    signal sliderValueChanged(int newValue)
    signal sliderDragFinished(int finalValue)

    height: 48

    // The thumb dragged to `v`: rounded to the step and held within the range
    function dragTo(v) {
        const stepped = step > 1 ? Math.round(v / step) * step : Math.round(v);
        const next = Math.max(minimum, Math.min(maximum, stepped));
        if (next !== value) {
            value = next;
            sliderValueChanged(next);
        }
    }
    // The pointer let go, wherever the thumb is
    function release() {
        sliderDragFinished(value);
    }
}
