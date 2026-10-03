.pragma library

// Original line art for true-wireless earbuds and their case, picked by
// the device name. No product photos (they belong to the brands); the
// shapes follow the real form factors: stem buds (AirPods-like) or pebble
// buds (Galaxy Buds, Sony WF...), a tall, wide or pebble case.
// Paths are in a 100 x 100 box; the right bud is the left one mirrored.

// Returns { bud: "stem"|"pebble", box: "tall"|"wide"|"pebble", finish: "white"|"graphite" }
function style(name) {
    name = name || "";
    var apple = /AirPods|Beats/i.test(name);
    var stem = apple || /Nothing Ear|^Ear ?\(|CMF Buds|FreeBuds|Redmi Buds [46] Active|realme Buds T/i.test(name);
    // The case shape is independent of the buds' (FreeBuds Pro: stems, oval case)
    var box = /AirPods Pro|Nothing|^Ear ?\(|CMF/i.test(name) ? "wide" : apple ? "tall" : "pebble";
    return {
        "bud": stem ? "stem" : "pebble",
        "box": box,
        "finish": apple || /FreeBuds/i.test(name) ? "white" : "graphite"
    };
}

// Surface colors per finish: [light, dark, detail (mesh, seam)]
var FINISH = {
    "white": ["#F6F6F4", "#BFC1C6", "#6E7078"],
    "graphite": ["#5A5E68", "#1B1C21", "#0B0B0E"]
};

var BUD = {
    // Round head + straight stem, facing right
    "stem": {
        "body": "M 18 30 A 24 22 0 1 1 66 30 A 24 22 0 1 1 18 30 Z M 40 42 L 56 42 L 58 91 Q 58 97 52.5 97 Q 47 97 47 91 Z",
        "detail": "M 49 24 A 5 4 0 1 1 59 24 A 5 4 0 1 1 49 24 Z",
        "shine": "M 26 22 Q 34 12 46 13"
    },
    // Rounded pebble with the ear tip on the left
    "pebble": {
        "tip": "M 12 42 A 14 15 0 1 1 40 42 A 14 15 0 1 1 12 42 Z",
        "body": "M 22 52 C 20 30 38 16 58 18 C 80 20 90 40 84 60 C 78 80 56 88 40 82 C 28 78 23 66 22 52 Z",
        "detail": "M 67.5 62 A 2.5 2.5 0 1 1 72.5 62 A 2.5 2.5 0 1 1 67.5 62 Z",
        "shine": "M 40 28 Q 54 20 70 26"
    }
};

var BOX = {
    // Upright, AirPods-like
    "tall": {
        "body": "M 24 6 H 76 Q 90 6 90 20 V 80 Q 90 94 76 94 H 24 Q 10 94 10 80 V 20 Q 10 6 24 6 Z",
        "detail": "M 11 36 H 89 M 48 62 A 2 2 0 1 1 52 62 A 2 2 0 1 1 48 62 Z",
        "shine": "M 20 14 Q 50 9 80 14"
    },
    // Landscape, AirPods Pro / Nothing-like
    "wide": {
        "body": "M 26 16 H 74 Q 96 16 96 38 V 64 Q 96 86 74 86 H 26 Q 4 86 4 64 V 38 Q 4 16 26 16 Z",
        "detail": "M 5 40 H 95 M 48 66 A 2 2 0 1 1 52 66 A 2 2 0 1 1 48 66 Z",
        "shine": "M 16 24 Q 50 18 84 24"
    },
    // Rounded pebble, Galaxy Buds / Sony-like
    "pebble": {
        "body": "M 50 14 C 80 14 96 30 96 52 C 96 74 80 88 50 88 C 20 88 4 74 4 52 C 4 30 20 14 50 14 Z",
        "detail": "M 6 46 Q 50 54 94 46 M 48 70 A 2 2 0 1 1 52 70 A 2 2 0 1 1 48 70 Z",
        "shine": "M 22 24 Q 50 16 78 24"
    }
};
