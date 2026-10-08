.pragma library

// mulberry32: a small seeded generator, so what the radar draws with it (its sky,
// the dials' offsets) is the same each time. Its own file because Radar.js and
// RadarSky.js both need it and RadarSky.js already imports Radar.js.
function random(seed) {
    let s = seed >>> 0;
    return () => {
        s = (s + 0x6D2B79F5) >>> 0;
        let t = s;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}
