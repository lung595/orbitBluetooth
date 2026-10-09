.pragma library
.import "../noise/Anc.js" as Anc

// What the right-click menu of an orbiting device offers, in order (OrbitMenu).
// Pure: the QML gathers the facts, this decides the entries, so a change of
// wording or of order is tested. Short on purpose: a member of a group can
// leave it (a Bluetooth one also shows Hide, which only explains, Q83),
// nothing more; adding a device and stopping the group belong to the group
// itself (its radar), not to one of its members.
// Tested by tests/menuEntries.test.js.
//
// `f` is the facts about the body: `device` (a Bluetooth device: a wired output
// has none), `wired`, `phase` ("connecting" while a connection is made),
// `connected`, `modes` (the noise-control modes it reports) and `mode` (the
// current one), `member` (it listens together), `groupEntry` (the words of the
// group entry, "" when no group can be made on it), `paired` and
// `confirmForget` ("Forget" was clicked once).
function list(f) {
    const out = [];
    if (f.wired)
        // An output on a cable stays plugged in: leaving the group is all its Disconnect can mean
        out.push({ "id": "leave", "icon": "link_off", "label": "Disconnect" });
    else if (f.device)
        out.push(f.phase === "connecting" ? { "id": "cancel", "icon": "close", "label": "Cancel" } : f.connected ? { "id": "disconnect", "icon": "link_off", "label": "Disconnect" } : { "id": "connect", "icon": "link", "label": "Connect" });
    for (const m of Anc.ordered(f.modes))
        out.push({ "id": "anc:" + m, "icon": Anc.ICONS[m], "label": Anc.SHORT[m], "checked": f.mode === m });
    // A group is made or added to from a device outside it; a member's own entry is the radar's
    if (f.groupEntry && !f.member)
        out.push({ "id": "group", "icon": "group_add", "label": f.groupEntry });
    if (f.member && !f.wired)
        out.push({ "id": "leave", "icon": "group_remove", "label": "Remove from group" });
    // A member plays on, so hiding it would only explain (OrbitHidden.hide): a wired one has
    // nothing else to do but leave, so Hide is not offered (a Bluetooth member's is, as before)
    if (!(f.wired && f.member))
        out.push({ "id": "hide", "icon": "visibility_off", "label": "Hide" });
    if (f.paired)
        out.push({ "id": "forget", "icon": f.confirmForget ? "delete_forever" : "delete", "label": f.confirmForget ? "Click to forget" : "Forget", "danger": true });
    return ruled(out);
}

// The Listen together entries sit together, under one hairline
function isTogether(id) {
    return id === "group" || id === "leave";
}

// The entries with `rule` on those a hairline goes before: the Listen together
// entries or "Hide" (once), and the first noise-control mode
function ruled(entries) {
    return entries.map(function (e, i) {
        const prev = i > 0 ? entries[i - 1].id : "";
        const rule = i > 0 && ((isTogether(e.id) && !isTogether(prev)) || (e.id === "hide" && !isTogether(prev)) || (e.id.indexOf("anc:") === 0 && prev.indexOf("anc:") !== 0));
        return Object.assign({}, e, { "rule": rule });
    });
}
