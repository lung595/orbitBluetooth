.pragma library

// Text that comes from outside the plugin (a device's name, a driver's
// description) made safe to show on one line (value 11). Pure logic, tested by
// tests/text.test.js.

// A name is never longer than a card can show
var MAX_NAME = 40;

// Control characters, plus the invisible ones that could reorder or hide text
// (zero width, bidi overrides, byte order mark). Written as ranges: the engine
// behind QML does not take \p{...} on every Qt version.
var UNSEEN = /[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁠-⁤⁦-⁩﻿]/g;

// One printable line of at most `max` characters (MAX_NAME when not given):
// spaces made plain and trimmed, nothing invisible left, "" when nothing is
// left or when `text` is not a text
function line(text, max) {
    const clean = (typeof text === "string" ? text : "").replace(UNSEEN, " ").replace(/\s+/g, " ").trim();
    // Cut by characters, not by UTF-16 units, so an emoji is never split in two
    return Array.from(clean).slice(0, typeof max === "number" && max > 0 ? max : MAX_NAME).join("").trim();
}
