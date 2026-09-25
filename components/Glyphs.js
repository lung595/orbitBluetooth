.pragma library

// Built-in line-art glyph set. Every glyph lives on a 24x24 grid and is drawn
// as a single stroked path (round caps/joins), so the whole set shares one
// visual weight and is tinted by the active Material You palette.
// "h.01" segments render as dots thanks to the round cap.

var paths = {
    bluetooth: "M7 7l10 10-5 4.5V2.5l5 4.5L7 17",

    laptop: "M5 15V6.5A1.5 1.5 0 0 1 6.5 5h11A1.5 1.5 0 0 1 19 6.5V15 M2.5 16.5h19v.5a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2z",
    desktop: "M3.5 5.5A1.5 1.5 0 0 1 5 4h14a1.5 1.5 0 0 1 1.5 1.5v9A1.5 1.5 0 0 1 19 16H5a1.5 1.5 0 0 1-1.5-1.5z M12 16v3.5 M8.5 20h7",
    tablet: "M4.5 5a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-11a2 2 0 0 1-2-2z M11 18.2h2",
    phone: "M7 4.5A2.5 2.5 0 0 1 9.5 2h5A2.5 2.5 0 0 1 17 4.5v15a2.5 2.5 0 0 1-2.5 2.5h-5A2.5 2.5 0 0 1 7 19.5z M11 4.8h2",

    headphones: "M4 14v-2a8 8 0 0 1 16 0v2 M4 14.5A1.5 1.5 0 0 1 5.5 13h1A1.5 1.5 0 0 1 8 14.5v4A1.5 1.5 0 0 1 6.5 20h-1A1.5 1.5 0 0 1 4 18.5z M16 14.5a1.5 1.5 0 0 1 1.5-1.5h1a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-1a1.5 1.5 0 0 1-1.5-1.5z",
    headphonesSlim: "M5 13.4V11a7 7 0 0 1 14 0v2.4 M3.8 16.5a2.2 3.2 0 1 0 4.4 0a2.2 3.2 0 1 0-4.4 0 M15.8 16.5a2.2 3.2 0 1 0 4.4 0a2.2 3.2 0 1 0-4.4 0",
    headphonesPremium: "M5 12V9.5a7 7 0 0 1 14 0V12 M7.5 11V9.5a4.5 4.5 0 0 1 9 0V11 M4 13.5A1.5 1.5 0 0 1 5.5 12H7a1.5 1.5 0 0 1 1.5 1.5v5A1.5 1.5 0 0 1 7 20H5.5A1.5 1.5 0 0 1 4 18.5z M15.5 13.5A1.5 1.5 0 0 1 17 12h1.5a1.5 1.5 0 0 1 1.5 1.5v5a1.5 1.5 0 0 1-1.5 1.5H17a1.5 1.5 0 0 1-1.5-1.5z",
    headset: "M4 14v-2a8 8 0 0 1 16 0v2 M4 14.5A1.5 1.5 0 0 1 5.5 13h1A1.5 1.5 0 0 1 8 14.5v4A1.5 1.5 0 0 1 6.5 20h-1A1.5 1.5 0 0 1 4 18.5z M16 14.5a1.5 1.5 0 0 1 1.5-1.5h1a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-1a1.5 1.5 0 0 1-1.5-1.5z M6 20v.3a2 2 0 0 0 2 2h3 M12.5 22.3h.01",
    earbudsStem: "M10 8v10.5a1 1 0 0 1-1 1h-.2a1 1 0 0 1-1-1v-7.2A3.2 3.2 0 1 1 10 8z M14 8v10.5a1 1 0 0 0 1 1h.2a1 1 0 0 0 1-1v-7.2A3.2 3.2 0 1 0 14 8z",
    earbudsRound: "M3.5 10.5a4 4 0 1 0 8 0a4 4 0 1 0-8 0 M5.9 10.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0-3.2 0 M12.5 13.5a4 4 0 1 0 8 0a4 4 0 1 0-8 0 M14.9 13.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0-3.2 0",
    earbudsCase: "M4 9a4 4 0 0 1 4-4h8a4 4 0 0 1 4 4v6a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4z M4 10.5h16 M11 13.5h2",

    speaker: "M3 9.5A3.5 3.5 0 0 1 6.5 6h11A3.5 3.5 0 0 1 21 9.5v5a3.5 3.5 0 0 1-3.5 3.5h-11A3.5 3.5 0 0 1 3 14.5z M5.5 12a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0-3 0 M15.5 12a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0-3 0 M11 12h2",
    speakerTall: "M7 5a3 3 0 0 1 3-3h4a3 3 0 0 1 3 3v14a3 3 0 0 1-3 3h-4a3 3 0 0 1-3-3z M9.5 14.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0 M12 7h.01",
    soundbar: "M2 10.5A1.5 1.5 0 0 1 3.5 9h17a1.5 1.5 0 0 1 1.5 1.5v3a1.5 1.5 0 0 1-1.5 1.5h-17A1.5 1.5 0 0 1 2 13.5z M6 12h.01 M9 12h.01 M15 12h.01 M18 12h.01",

    mouse: "M6.5 9.5a5.5 5.5 0 0 1 11 0v5a5.5 5.5 0 0 1-11 0z M12 4v4.5",
    mouseErgo: "M8 3.6c3.5-.8 8 1.2 8.8 6.2l.6 4.3c.6 4.2-2.2 7-5.8 7h-1.3c-2.3 0-4.3-1.5-4.8-3.8l-.6-2.5c-.3-1.2-1.7-1.6-2.3-2.7-.5-1 0-2.4 1-2.8l1.2-.5C5.3 6.6 5.8 4.1 8 3.6z M11.6 4.2l.4 4.6 M5.4 10.9l2.2-.8",
    mouseGaming: "M12 3.5c-3 0-5 1.8-5 5.5v6a5 5 0 0 0 10 0V9c0-3.7-2-5.5-5-5.5z M12 3.5V9 M12 5.5v1.5 M9 11.5v1.2 M9 14.2v1.2 M10 18.5h4",
    trackpad: "M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",
    keyboard: "M2.5 7.5A1.5 1.5 0 0 1 4 6h16a1.5 1.5 0 0 1 1.5 1.5v9A1.5 1.5 0 0 1 20 18H4a1.5 1.5 0 0 1-1.5-1.5z M6 10h.01 M9 10h.01 M12 10h.01 M15 10h.01 M18 10h.01 M7.5 13h.01 M10.5 13h.01 M13.5 13h.01 M16.5 13h.01 M8 15.5h8",
    gamepad: "M6.5 7h11a4.5 4.5 0 0 1 4.4 3.6l.9 5a2.7 2.7 0 0 1-4.9 2L16.3 16H7.7l-1.6 1.6a2.7 2.7 0 0 1-4.9-2l.9-5A4.5 4.5 0 0 1 6.5 7z M7 10v3 M5.5 11.5h3 M16 10.8h.01 M18 12.5h.01",
    pen: "M16.5 3.5l4 4L9 19l-5 1.5L5.5 15.5z M14.5 5.5l4 4",

    watch: "M7 9a2.5 2.5 0 0 1 2.5-2.5h5A2.5 2.5 0 0 1 17 9v6a2.5 2.5 0 0 1-2.5 2.5h-5A2.5 2.5 0 0 1 7 15z M9 6.5L9.5 3h5l.5 3.5 M9 17.5l.5 3.5h5l.5-3.5 M17 11v2",
    watchRound: "M6.5 12a5.5 5.5 0 1 0 11 0a5.5 5.5 0 1 0-11 0 M9 7.2L9.5 3h5l.5 4.2 M9 16.8l.5 4.2h5l.5-4.2 M12 12V9.5 M12 12l1.5 1",
    glasses: "M2.5 10.5h19 M3.5 10.5V12a3.5 3.5 0 0 0 7 0v-1.5 M13.5 10.5V12a3.5 3.5 0 0 0 7 0v-1.5",
    vr: "M3 9.5A2.5 2.5 0 0 1 5.5 7h13A2.5 2.5 0 0 1 21 9.5v5a2.5 2.5 0 0 1-2.5 2.5h-3l-2-2.5h-3L8.5 17h-3A2.5 2.5 0 0 1 3 14.5z",
    tv: "M2.5 6A1.5 1.5 0 0 1 4 4.5h16A1.5 1.5 0 0 1 21.5 6v10a1.5 1.5 0 0 1-1.5 1.5H4A1.5 1.5 0 0 1 2.5 16z M8 20.5h8",
    car: "M5 16.5v2 M19 16.5v2 M3.5 16.5v-4l2-5A2 2 0 0 1 7.4 6h9.2a2 2 0 0 1 1.9 1.5l2 5v4z M3.5 12.5h17 M7 14.5h.01 M17 14.5h.01"
};

// Human readable names, also used as the glyph picker order.
var labels = {
    headphonesSlim: "Headphones",
    headphones: "Over-ear",
    headphonesPremium: "Studio headphones",
    headset: "Gaming headset",
    earbudsStem: "Earbuds (stem)",
    earbudsRound: "Earbuds",
    earbudsCase: "Earbuds case",
    speaker: "Portable speaker",
    speakerTall: "Smart speaker",
    soundbar: "Soundbar",
    mouse: "Mouse",
    mouseErgo: "Ergonomic mouse",
    mouseGaming: "Gaming mouse",
    trackpad: "Trackpad",
    keyboard: "Keyboard",
    gamepad: "Controller",
    pen: "Stylus",
    phone: "Phone",
    tablet: "Tablet",
    watch: "Watch",
    watchRound: "Round watch",
    glasses: "Smart glasses",
    vr: "VR headset",
    tv: "TV",
    car: "Car",
    laptop: "Laptop",
    desktop: "Desktop",
    bluetooth: "Device"
};

var order = Object.keys(labels);

function path(kind) {
    return paths[kind] || paths.bluetooth;
}

function label(kind) {
    return labels[kind] || labels.bluetooth;
}
