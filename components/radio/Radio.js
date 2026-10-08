.pragma library
.import "../volume/Route.js" as Route

// Two Bluetooth outputs that play at once share their adapter's one radio:
// each stream takes airtime, and a heavy one (LDAC) loses quality or cuts
// when the link cannot keep up (D293, P170). Orbit never lowers a device's
// quality to make them fit: it says so once and points at the guide.
// Pure logic, tested in tests/radio.test.js.

// The outputs of the adapter that are fed sound right now, as sorted
// addresses. `links` lists PipeWire's link groups as { sink, active }: the
// name of the node the sound goes into, and whether the link runs; `known`
// maps the adapter's own devices (a device of another adapter has its own
// radio).
function playing(links, known) {
    var seen = {};
    (links || []).forEach(function (link) {
        var address = link && link.active ? Route.addressOfSink(link.sink) : "";
        if (address && known && known[address])
            seen[address] = true;
    });
    return Object.keys(seen).sort();
}

// What names the pair that shares the radio: the playing outputs joined, or
// "" while fewer than two play
function sharedKey(links, known) {
    var list = playing(links, known);
    return list.length >= 2 ? list.join("+") : "";
}

// How many Bluetooth outputs of the adapter exist among PipeWire's nodes:
// with fewer than two there is nothing to watch
function outputCount(nodes, known) {
    var seen = {};
    (nodes || []).forEach(function (node) {
        var address = node && node.isSink && !node.isStream ? Route.addressOfSink(node.name) : "";
        if (address && known && known[address])
            seen[address] = true;
    });
    return Object.keys(seen).length;
}

// Whether to say it now: a pair shares the radio, the orbit is open (the
// note is only seen there) and this pair was not told about yet
function due(key, told, open) {
    return key !== "" && !!open && told.indexOf(key) < 0;
}
