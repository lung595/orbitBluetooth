.pragma library

// Made-up Bluetooth devices for the previews: no real address, name or
// picture. Bonded always follows paired, as it does for a trusted device.
function make(address, name, icon, paired, connected, battery) {
    return {
        address: address,
        name: name,
        connected: connected,
        paired: paired,
        bonded: paired,
        blocked: false,
        batteryAvailable: battery > 0,
        battery: battery,
        icon: icon
    };
}

// disconnected: every device is shown as not connected (the "-none" shots);
// outputs: how many more connected speakers are there to listen together with
function list(disconnected, outputs) {
    const speakers = [
        make("02:00:00:00:20:01", "Marantz Cinema 50", "audio-speakers", true, true, 0),
        make("02:00:00:00:20:02", "JBL Charge 5", "audio-speakers", true, true, 0.8),
        make("02:00:00:00:20:03", "Sonos Roam", "audio-speakers", true, true, 0.45)
    ].slice(0, outputs || 0);
    const all = [
        make("02:00:00:00:10:06", "WH-1000XM6", "audio-headphones", true, true, 0.54),
        make("98:7A:14:22:C1:0E", "Xbox Wireless Controller", "input-gaming", true, true, 0.72),
        make("D4:1A:88:10:5B:77", "MX Master 3S", "input-mouse", true, false, 0),
        make("6C:4A:85:9E:03:21", "AirPods Pro", "audio-headset", false, false, 0),
        make("F0:65:AE:31:9C:40", "Galaxy Buds3", "audio-headset", false, false, 0),
        make("00:11:22:33:44:55", "HUAWEI FreeBuds Pro", "audio-headset", true, true, 0.92),
        make("3C:8D:20:54:AB:12", "Keychron K3", "input-keyboard", true, false, 0)
    ].concat(speakers);
    return disconnected ? all.map(d => Object.assign({}, d, {
            connected: false
        })) : all;
}
