.pragma library
.import "../device/DeviceCatalog.js" as Catalog
.import "Member.js" as Member
.import "Together.js" as Together
.import "Wired.js" as Wired

// What the group chooser lists and what validating asks for (D298), as pure
// functions so that the QML (GroupChooser) is only display and wiring. The
// chooser is the page of the right-click menu where a Listen together group is
// made by ticking outputs: the wired ones that are plugged in and the Bluetooth
// devices that are connected and can take part. An output that is there but
// cannot be ticked is shown with the reason, and clicking it explains (never a
// silent refusal, value 10); one that is not there at all is not offered.
// Everything that reaches a command later is a member token (Member.js).
// Tested by tests/choice.test.js.

// The sections in the order they are drawn; a section with no row is not drawn
var SECTIONS = [
    { "id": "wired", "title": "Wired" },
    { "id": "bluetooth", "title": "Bluetooth" }
];

// A wired output is drawn by how it is connected (Wired.kindOf)
var WIRED_ICONS = { "usb": "usb", "hdmi": "settings_input_hdmi", "analog": "speaker", "other": "cable" };

// A Bluetooth device is drawn by the kind of its glyph (DeviceCatalog); the
// kinds that play sound have a picture of their own, the rest the generic one
var BLUETOOTH_ICONS = {
    "headphones": "headphones", "headphonesSlim": "headphones", "headphonesPremium": "headphones",
    "headset": "headset_mic",
    "earbudsStem": "earbuds", "earbudsRound": "earbuds", "earbudsCase": "earbuds",
    "speaker": "speaker", "speakerTall": "speaker", "soundbar": "speaker_group"
};
var FALLBACK_ICON = "bluetooth";

// What a row that cannot be ticked says where its tick would be, by why: the
// same reasons Guide.togetherNote explains when the row is clicked
var CAPTIONS = {
    "already": "In the group",
    "in-call": "Call mode",
    "no-audio": "No sound yet",
    "full": "Group is full"
};

// The words of the menu entry, of the chooser and of its button, for the
// members of the session there is ([] for none): a group is created, or
// outputs are added to the one that listens
function labels(members) {
    return _members(members).length ? {
        "entry": "Add to the group…",
        "title": "Add to the group",
        "action": "Add",
        "empty": "Nothing else to add: connect a Bluetooth output or plug in a wired one"
    } : {
        "entry": "Create a group…",
        "title": "Create a group",
        "action": "Listen together",
        "empty": "Nothing to listen with: connect another Bluetooth output or plug in a wired one"
    };
}

// The members of a session, or [] when there is none (a session has two or more)
function _members(list) {
    return Array.isArray(list) && list.length >= 2 ? list : [];
}

// `text` as a member of this kind ("bluetooth" or "wired"), or "" for anything else
function _token(text, kind) {
    const id = Member.clean(text);
    return Member.kind(id) === kind ? id : "";
}

// By name without regard to case, then by id so that two outputs with the same
// name keep a stable order
function _byLabel(a, b) {
    const x = a.label.toLowerCase(), y = b.label.toLowerCase();
    if (x !== y)
        return x < y ? -1 : 1;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

// What the session's refusal means for an output: "" when it can be ticked, the
// reason when it is shown but cannot be (in call, or an audio device whose
// output is not there yet), null when it is not offered (not there, or no
// sound device at all)
function _verdict(refusal, audio) {
    if (!refusal)
        return "";
    return refusal.why === "in-call" || (refusal.why === "no-audio" && audio) ? refusal.why : null;
}

// Everything the chooser may show, sorted: [{ section, id, label, icon, why }].
// `input.refusal(who)` is the session's memberCheck: null when `who` can take part.
function _offered(input) {
    const refusal = typeof input.refusal === "function" ? input.refusal : () => null;
    const out = [];
    const seen = {};
    const offer = (section, id, label, icon, audio) => {
        if (!id || seen[id])
            return;
        const why = _verdict(refusal(id), audio);
        if (why === null)
            return;
        seen[id] = true;
        out.push({ "section": section, "id": id, "label": Wired.labelOf(label), "icon": icon, "why": why });
    };
    for (const w of Array.isArray(input.wired) ? input.wired : [])
        if (w && typeof w === "object")
            offer("wired", _token(w.sink, "wired"), w.label, WIRED_ICONS[Wired.kindOf(w)], true);
    for (const b of Array.isArray(input.bluetooth) ? input.bluetooth : []) {
        if (!b || typeof b !== "object")
            continue;
        const id = _token(b.address, "bluetooth");
        const icon = Object.prototype.hasOwnProperty.call(BLUETOOTH_ICONS, b.kind) ? BLUETOOTH_ICONS[b.kind] : FALLBACK_ICON;
        offer("bluetooth", id, b.name || id, icon, Catalog.families[b.kind] === "audio");
    }
    return out.sort(_byLabel);
}

// What the chooser shows. `input`: { wired, bluetooth, members, chosen, refusal }
//  - wired: the plugged outputs (WiredWatch.outputs);
//  - bluetooth: the devices on screen, [{ address, name, kind }];
//  - members: the session's members ([] for none), shown ticked and locked;
//  - chosen: what is ticked, in the order it was;
//  - refusal: who => null | { why, address }, the session's memberCheck.
// Gives { sections: [{ id, title, rows }], chosen, enough }. A row is
// { id, label, icon, ticked, locked, why, caption }: `why` is "" when a click
// ticks it, else the reason it cannot be (and the caption that says it).
// `chosen` is what is really ticked: only outputs that can be, at most as many
// as the group has room for. `enough` is whether there is anything to make a
// group of (two outputs, or one to add to the group there is).
function build(input) {
    const given = input && typeof input === "object" ? input : {};
    const members = _members(given.members);
    const room = Math.max(0, Together.MAX_MEMBERS - members.length);
    const offered = _offered(given);
    const free = offered.filter(o => !o.why && members.indexOf(o.id) < 0);
    const ticks = Array.isArray(given.chosen) ? given.chosen : [];
    const chosen = ticks.filter((id, i) => ticks.indexOf(id) === i && free.some(o => o.id === id)).slice(0, room);
    const rows = offered.map(o => {
        const locked = members.indexOf(o.id) >= 0;
        const ticked = locked || chosen.indexOf(o.id) >= 0;
        const why = locked ? "already" : o.why || (!ticked && chosen.length >= room ? "full" : "");
        return {
            "section": o.section, "id": o.id, "label": o.label, "icon": o.icon,
            "ticked": ticked, "locked": locked, "why": why, "caption": CAPTIONS[why] || ""
        };
    });
    return {
        "sections": SECTIONS.map(s => ({ "id": s.id, "title": s.title, "rows": rows.filter(r => r.section === s.id) })).filter(s => s.rows.length),
        "chosen": chosen,
        "enough": free.length >= (members.length ? 1 : 2)
    };
}

// What is ticked after a click on `id`: ticked when it was not, else not
function toggle(chosen, id) {
    const now = Array.isArray(chosen) ? chosen : [];
    return now.indexOf(id) >= 0 ? now.filter(c => c !== id) : now.concat([id]);
}

// What validating asks of the session, for its members and what is ticked:
// { mode, list, why }. A new group takes everything ticked ("start"); a group
// there is takes the newcomers ("add"). `why` is "pick-more" while that is too
// little: a group needs two outputs, an addition one.
function outcome(members, chosen) {
    const there = _members(members);
    const adding = there.length > 0;
    const list = (Array.isArray(chosen) ? chosen : []).filter(id => there.indexOf(id) < 0);
    return {
        "mode": adding ? "add" : "start",
        "list": list,
        "why": list.length >= (adding ? 1 : 2) ? "" : "pick-more"
    };
}
