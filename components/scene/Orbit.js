.pragma library

// Which Bluetooth devices the orbit shows, and how its list of bodies
// follows them. The scene passes BlueZ's devices and its preferences in.

// The devices worth a planet, best first: connected, then paired, then
// named, then the strongest signal. Connected devices never count against
// maxDevices. opts: { isHidden(address), isUnnamed(device), showUnnamed,
// maxDevices }
function pick(all, opts) {
    const list = [];
    for (let i = 0; i < all.length; i++) {
        const d = all[i];
        if (!d || d.blocked || opts.isHidden(d.address))
            continue;
        if (!opts.showUnnamed && opts.isUnnamed(d) && !d.connected)
            continue;
        // Quickshell does not expose RSSI (signalStrength is undefined), so
        // anything BlueZ lists while discovering is treated as in range.
        if (!(d.connected || d.paired || d.bonded || d.signalStrength === undefined || d.signalStrength > 0))
            continue;
        list.push(d);
    }
    list.sort((x, y) => {
        if (x.connected !== y.connected)
            return x.connected ? -1 : 1;
        const px = x.paired || x.bonded, py = y.paired || y.bonded;
        if (px !== py)
            return px ? -1 : 1;
        const nx = opts.isUnnamed(x), ny = opts.isUnnamed(y);
        if (nx !== ny)
            return nx ? 1 : -1;
        return (y.signalStrength || 0) - (x.signalStrength || 0);
    });
    const room = Math.max(0, opts.maxDevices - list.filter(c => c.connected).length);
    let kept = 0;
    return list.filter(d => d.connected || kept++ < room);
}

// Diffs `shown` (address -> device) into the bodies' list, so existing
// bodies keep their physics state. `entries` is the list as it is
// ([{address, leaving}]), `previous` the last address -> device map.
// Returns:
//  - marks: [[index, leaving]] for the entries whose fade-out starts or stops;
//  - added: the addresses that need a new body;
//  - devices: `shown` plus the leaving devices from `previous`, so they
//    stay resolvable while they fade out.
function plan(entries, shown, previous) {
    const marks = [];
    const added = [];
    const devices = Object.assign({}, shown);
    entries.forEach((e, i) => {
        if (!shown[e.address] && !e.leaving)
            marks.push([i, true]);
        else if (shown[e.address] && e.leaving)
            marks.push([i, false]);
        if (!shown[e.address] && previous[e.address])
            devices[e.address] = previous[e.address];
    });
    for (const address in shown) {
        if (!entries.some(e => e.address === address))
            added.push(address);
    }
    return {
        "marks": marks,
        "added": added,
        "devices": devices
    };
}
