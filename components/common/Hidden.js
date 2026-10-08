.pragma library
.import "../together/Member.js" as Member
.import "../together/Wired.js" as Wired

// The store of hidden devices (the black hole's "Hidden · N"): a map from a
// member id (a Bluetooth address or the node name of a wired output, Member.js)
// to the name it had when it was hidden, kept in the plugin's own settings
// (hiddenDevices). Pure functions, so that whoever reads the store (the orbit,
// the group chooser, the hole's counter, the ghost group) asks the same
// question in the same place. Tested by tests/hidden.test.js.

// A hole this full is a mistake, not a choice: nothing real hides this many
var MAX = 64;

function _map(store) {
    return store && typeof store === "object" && !Array.isArray(store) ? store : {};
}

function _has(map, key) {
    return typeof key === "string" && key !== "" && Object.prototype.hasOwnProperty.call(map, key);
}

// Is `id` in the store? The id is read in any spelling (a Bluetooth address in
// lower case, with underscores...), as the store holds it in the one form of
// Member.clean; what an older version stored under its own spelling still counts.
function isHidden(hiddenDevices, id) {
    const map = _map(hiddenDevices);
    return _has(map, id) || _has(map, Member.clean(id));
}

// Why `id` cannot be put in the store: "bad-id" when it is no output Orbit knows
// (Member.js), "full" when the store holds MAX already; "" when it can
function refusal(hiddenDevices, id) {
    const map = _map(hiddenDevices);
    if (!Member.clean(id))
        return "bad-id";
    return !isHidden(map, id) && Object.keys(map).length >= MAX ? "full" : "";
}

// The store with `id` hidden under `name`, or brought back (`hidden` false); a
// new object, `hiddenDevices` is never changed. An id that cannot be hidden
// (see `refusal`) leaves the store as it was.
function set(hiddenDevices, id, name, hidden) {
    const next = Object.assign({}, _map(hiddenDevices));
    const token = Member.clean(id);
    if (!hidden) {
        // Whatever spelling it was stored under
        for (const key of Object.keys(next))
            if (key === id || (token && Member.clean(key) === token))
                delete next[key];
        return next;
    }
    if (refusal(next, id))
        return next;
    next[token] = name ? Wired.labelOf(name) : token;
    return next;
}

// What the store holds, as [{ id, name }] (the id in the one form of
// Member.clean), by name and then by id, for whoever lists it: keys that are no
// output (a hand-edited file) are left out
function entries(hiddenDevices) {
    const map = _map(hiddenDevices);
    const seen = {};
    const out = [];
    for (const key of Object.keys(map)) {
        const id = Member.clean(key);
        if (!id || seen[id])
            continue;
        seen[id] = true;
        out.push({ "id": id, "name": typeof map[key] === "string" ? map[key] : "" });
    }
    return out.sort((a, b) => {
        const x = (a.name || a.id).toLowerCase(), y = (b.name || b.id).toLowerCase();
        return x !== y ? (x < y ? -1 : 1) : (a.id < b.id ? -1 : 1);
    });
}
