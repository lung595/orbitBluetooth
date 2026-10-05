.pragma library

// How a battery level is told apart at a glance (the arc around a device's
// disc): a traffic light by level, and a look of its own while charging.
// Pure: the QML maps each tone to a colour (BodyArcs), the numbers live here
// and nowhere else (the card's ramp borrows the red one: Charge.js).
// Tested by tests/battery.test.js.

var OK_FROM = 40;           // % and up: all is well
var LOW_FROM = 16;          // % and up: running low
var CRITICAL_MAX = LOW_FROM - 1;    // % and down: nearly empty

// "ok", "low" or "critical" for a level (0..100, a device that reports none
// has no arc), or "charging" whatever the level: what is being filled is not
// judged by how empty it still is
function tone(level, charging) {
    if (charging)
        return "charging";
    if (level >= OK_FROM)
        return "ok";
    return level >= LOW_FROM ? "low" : "critical";
}
