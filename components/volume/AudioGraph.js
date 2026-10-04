.pragma library

// What PipeWire's graph says of an output while it is looked at (D260): the
// delay the output reports, LDAC's quality setting, and the quantum the
// graph runs at. Pure: no process, no QML; AudioGraph.qml runs the two
// commands and hands their text here. A value that is not there is left
// out, never guessed.

// `pw-dump`'s text -> { sink name: { latencyMs, quality } }. Only sinks;
// each key is there only when PipeWire reported it
function parseDump(text) {
    let list;
    try {
        list = JSON.parse(text);
    } catch (e) {
        return {};
    }
    const out = {};
    if (!Array.isArray(list))
        return out;
    for (const object of list) {
        const info = object && object.info;
        const props = info && info.props;
        if (!props || props["media.class"] !== "Audio/Sink" || typeof props["node.name"] !== "string")
            continue;
        const found = {};
        const params = info.params || {};
        // The sink's own side of the chain, in nanoseconds: what it adds
        // before the sound is heard (Bluetooth buffering, mostly)
        for (const l of params["Latency"] || [])
            if (l.direction === "Input" && l.maxNs > 0)
                found.latencyMs = l.maxNs / 1e6;
        for (const p of params["Props"] || [])
            if (Number.isInteger(p.quality))
                found.quality = p.quality;
        out[props["node.name"]] = found;
    }
    return out;
}

// `pw-top -b`'s text -> { sink name: { quantum, quantumRate } } for the nodes that
// run. The first block of a batch run is empty (it has nothing to compare
// with), so the last block counts; a node that follows another one shows
// no quantum of its own and is left out
function parseTop(text) {
    const blocks = String(text || "").split(/^S\s+ID\s+QUANT.*$/m);
    const out = {};
    for (const line of blocks[blocks.length - 1].split("\n")) {
        const m = /^R\s+\d+\s+(\d+)\s+(\d+)\s+.*\s(\S+)$/.exec(line);
        if (m && +m[1] > 0 && +m[2] > 0)
            out[m[3]] = { "quantum": +m[1], "quantumRate": +m[2] };
    }
    return out;
}

function _round(ms) {
    return ms < 10 ? Math.round(ms * 10) / 10 : Math.round(ms);
}

// 606.4 -> "606 ms", 5.33 -> "5.3 ms"; "" when there is no latency
function latencyText(ms) {
    return ms > 0 ? _round(ms) + " ms" : "";
}

// 1024 samples at 192 kHz -> "1024 samples (5.3 ms)"; "" when unknown
function quantumText(quantum, rate) {
    return quantum > 0 && rate > 0 ? quantum + " samples (" + _round(quantum / rate * 1000) + " ms)" : "";
}
