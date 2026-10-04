import QtQuick

// The pairing sheet's time: the clock behind every loop, the card unfolding,
// the sections coming in one after another, the device falling into orbit,
// the burst when it connects and the pointer tilt. PairingSheet feeds it its
// state; the parts of the sheet only read the values. Invisible: an Item
// only because QML objects without one cannot own timers and animations.
Item {
    id: root

    required property bool shown
    required property bool reduceMotion
    // Locked or screens off (set by the window): the loop would redraw the
    // whole shell at the screen's rate for nobody
    required property bool asleep
    required property string phase
    required property int battery
    // The pointer over the card, as a fraction of its width and height
    property bool hovering: false
    property real pointerX: 0.5
    property real pointerY: 0.3
    // The ring the entrance flashes when the orbit catches the device
    property Item flash: null

    visible: false

    readonly property bool moving: shown && !reduceMotion && !asleep
    // Seconds since the sheet appeared: drives every loop (float, moon,
    // twinkle, sonar, shooting star). A plain 60 Hz timer, not a looping
    // QML animation: a running animation makes every shell window (bars,
    // wallpaper, both screens) redraw at the display rate, a timer only
    // repaints this sheet (measured: 75 % of a core -> see CHANGELOG).
    property real clock: 0
    Timer {
        id: clockTimer
        interval: 16
        repeat: true
        running: root.moving
        property double start: 0
        onRunningChanged: if (running)
            start = Date.now() - root.clock * 1000
        onTriggered: root.clock = (Date.now() - start) / 1000
    }
    // 0 -> 1: the card unfolds (springy on the way in, quick on the way out)
    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.reduceMotion ? 0 : root.shown ? 700 : 300
            easing.type: root.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 1.15
        }
    }
    // 0 -> 1: the sections come in one after another
    property real intro: 0
    // 0 -> 1: the device falls out of the bar along a comet trail
    property real fall: 0
    // 0 -> 1: caught by the orbit (flash, then sonar and moon)
    property real arrived: 0
    // 0 -> 1: star burst when connected, and the battery ring filling
    property real burst: 0
    property real shownBattery: 0
    // Pointer tilt of the device, in degrees
    property real tiltX: hovering && moving ? -(pointerY - 0.3) * 12 : 0
    property real tiltY: hovering && moving ? (pointerX - 0.5) * 18 : 0
    Behavior on tiltX {
        SmoothedAnimation {
            velocity: 30
        }
    }
    Behavior on tiltY {
        SmoothedAnimation {
            velocity: 40
        }
    }
    readonly property real floatY: arrived * 6 * Math.sin(clock * 1.6)
    readonly property real floatTurn: arrived * 1.8 * Math.sin(clock * 1.05)

    // How far section `i` has come in (0 -> 1), each one a beat after the last
    function stagger(i) {
        return Math.max(0, Math.min(1, (intro - i * 0.09) / 0.4));
    }

    SequentialAnimation {
        id: enter
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "intro"
                from: 0
                to: 1
                duration: 1300
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 260
                }
                NumberAnimation {
                    target: root
                    property: "fall"
                    from: 0
                    to: 1
                    duration: 1000
                    easing.type: Easing.OutCubic
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: root.flash
                        property: "scale"
                        from: 1
                        to: 2.1
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: root.flash
                        property: "opacity"
                        from: 0.9
                        to: 0
                        duration: 600
                    }
                    NumberAnimation {
                        target: root
                        property: "arrived"
                        from: 0
                        to: 1
                        duration: 700
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: celebrate
        NumberAnimation {
            target: root
            property: "burst"
            from: 0
            to: 1
            duration: 1100
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "shownBattery"
            from: 0
            to: Math.max(0, root.battery)
            duration: 1300
            easing.type: Easing.OutCubic
        }
    }

    function start() {
        enter.stop();
        if (reduceMotion) {
            intro = 1;
            fall = 1;
            arrived = 1;
            return;
        }
        intro = 0;
        fall = 0;
        arrived = 0;
        enter.restart();
    }
    onShownChanged: if (shown) {
        // The loops start over with each new sheet
        clock = 0;
        clockTimer.start = Date.now();
        start();
    }
    Component.onCompleted: if (shown)
        start()
    onPhaseChanged: {
        if (phase === "done") {
            if (reduceMotion) {
                burst = 1;
                shownBattery = Math.max(0, battery);
            } else {
                celebrate.restart();
            }
        } else {
            burst = 0;
            shownBattery = 0;
        }
    }
    onBatteryChanged: if (phase === "done" && !celebrate.running)
        shownBattery = Math.max(0, battery)
}
