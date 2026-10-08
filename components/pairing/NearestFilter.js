.pragma library

// Should this PC open the "new device" pop-up now, or wait for a nearer PC?
// Pure logic, free of QML so it can be tested (tests/nearestFilter.test.js).
//
// Every PC judges alone, from the signal its own adapter reads while it
// discovers (BlueZ Device1.RSSI): nothing is exchanged between PCs, so there
// is no message to forge, flood or replay. The nearest PC waits the least and
// shows the pop-up first; if the device gets connected elsewhere meanwhile it
// leaves discovery and the later PCs never open theirs. Anything unclear
// keeps today's behavior: the pop-up opens at once.

// Starting points, to be measured with real adapters (Q81)
var defaults = {
    // Weaker than this is the next room or a neighbour: no pop-up at all
    "floor": -75,
    // At least this strong counts as within arm's reach: no wait
    "near": -45,
    // Wait of a device right at the floor
    "maxDelayMs": 6000,
    // What the tie-breakers add or remove, small against the signal spread
    "tieMs": 1500
};

// BlueZ reports a signed dBm value, always below 0 in practice; 0 and
// positive values are "no reading", and 127 is its own "unavailable" marker
function isReading(rssi) {
    return typeof rssi === "number" && isFinite(rssi) && rssi < 0;
}

function _num(value, fallback) {
    return typeof value === "number" && isFinite(value) ? value : fallback;
}

// The wait before this PC offers a device, from the signal alone: 0 at
// "near" or stronger, growing linearly to maxDelayMs at the floor. A missing
// reading waits for nothing (today's behavior).
function delayMs(rssi, opts) {
    if (!isReading(rssi))
        return 0;
    const near = _num(opts && opts.near, defaults.near);
    const floor = _num(opts && opts.floor, defaults.floor);
    const max = Math.max(0, _num(opts && opts.maxDelayMs, defaults.maxDelayMs));
    if (floor >= near)
        return 0;
    const t = (near - Math.max(floor, Math.min(near, rssi))) / (near - floor);
    return Math.round(t * max);
}

// ctx: {rssi, screenOn, recentUse, opts}
//   rssi: dBm read from BlueZ, undefined when there is none
//   screenOn / recentUse: booleans, undefined when unknown (counts for nothing)
// Returns {offer, delayMs, reason}: offer false means "do not open here",
// otherwise open after delayMs (0 = at once).
function shouldOffer(ctx) {
    if (!ctx || !isReading(ctx.rssi))
        return { "offer": true, "delayMs": 0, "reason": "no signal reading" };
    const floor = _num(ctx.opts && ctx.opts.floor, defaults.floor);
    if (ctx.rssi < floor)
        return { "offer": false, "delayMs": 0, "reason": "below the signal floor" };
    const tie = Math.max(0, _num(ctx.opts && ctx.opts.tieMs, defaults.tieMs));
    let wait = delayMs(ctx.rssi, ctx.opts);
    // A PC whose screen is off, or that nobody used lately, is less likely to
    // be the owner's: it gives way to one that is awake and in use
    if (ctx.screenOn === false)
        wait += tie;
    if (ctx.recentUse === true)
        wait -= tie;
    return { "offer": true, "delayMs": Math.max(0, wait), "reason": "nearest first" };
}
