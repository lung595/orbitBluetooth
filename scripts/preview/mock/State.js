.pragma library

// Made-up plugin state (connection times, battery history, noise control)
// and a made-up sound, so the previews show a lived-in sky.

// A noise-control entry the daemon reports as ready; `state` is what changes per shot
function ready(features, state) {
    return {
        "status": "ready",
        "live": true,
        "model": "",
        "features": features,
        "state": state
    };
}

// The daemon's global variables as the scene reads them. `t` is "now" in ms,
// `mode` the preview mode (the buds shots vary the earbuds' charging).
function globals(mode, t) {
    const m = 60000;
    return {
        "orbitBluetooth": {
            "since": {
                "02:00:00:00:10:06": t - 42 * m,
                "98:7A:14:22:C1:0E": t - 95 * m
            },
            "batteryLog": {
                "02:00:00:00:10:06": [[t - 34 * m, 38], [t - 24 * m, 43], [t - 14 * m, 48], [t - 4 * m, 53], [t - 1 * m, 54]],
                "98:7A:14:22:C1:0E": [[t - 95 * m, 81], [t - 60 * m, 77], [t - 20 * m, 73], [t - 5 * m, 72]]
            },
            "power": {},
            "anc": {
                // The demo headset
                "02:00:00:00:10:06": ready({
                    "modes": ["nc", "ambient", "off", "adaptive"],
                    "ambientMax": 20,
                    "levelMode": "ambient",
                    "voice": true,
                    "chat": true
                }, {
                    "mode": mode === "ancfocus" ? "ambient" : "nc",
                    "ambient": 14,
                    "voice": true,
                    "chat": false,
                    "battery": {}
                }),
                // Earbuds: case charging; in "budsdock" both buds charge in it
                "00:11:22:33:44:55": ready({
                    "modes": ["nc", "adaptive", "ambient", "off"],
                    "ambientMax": 0,
                    "levelMode": "ambient",
                    "voice": true,
                    "chat": false
                }, {
                    "mode": "nc",
                    "ambient": null,
                    "voice": false,
                    "chat": null,
                    "battery": {
                        "left": {
                            "level": mode === "budsdock" ? 64 : 94,
                            "charging": mode === "budsdock"
                        },
                        "right": {
                            "level": mode === "budsdock" ? 58 : 100,
                            "charging": mode === "budsdock"
                        },
                        "case": {
                            "level": 60,
                            "charging": mode !== "budsdock"
                        }
                    }
                })
            }
        }
    };
}

// One frame of a made-up stereo sound for the card's scope
var soundFrame = {
    "l": [0.92, 0.85, 0.8, 0.72, 0.66, 0.62, 0.55, 0.5, 0.44, 0.4, 0.33, 0.28, 0.22, 0.18, 0.12, 0.08],
    "r": [0.9, 0.8, 0.7, 0.66, 0.58, 0.5, 0.47, 0.4, 0.36, 0.3, 0.26, 0.2, 0.16, 0.12, 0.08, 0.05]
};

// What `pactl` would say of the headset and this PC's filter, for the audio details
var fakeSinks = {
    "bluez_output.02_00_00_00_10_06.1": {
        "connection": "Bluetooth",
        "codec": "LDAC",
        "rate": 96000,
        "bits": 24,
        "channels": 2
    },
    "orbit_pc_filter": {
        "connection": "",
        "codec": "",
        "rate": 48000,
        "bits": 32,
        "channels": 2
    }
};
