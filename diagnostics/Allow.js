.pragma library

// The allowlist at the heart of the diagnostics (value 8): a value is written
// down only when it is a number, a yes/no, or one of the words the plugin
// listed in advance for that key. Anything else becomes "?". Free text
// (a device name, an address, a path) therefore cannot get in, whatever a
// caller passes. A spec is "bool", "int" or an array of allowed words.

// Integers are clamped so a runaway counter stays short in a report
var INT_LIMIT = 1000000000;

// The text of one value, or null when the spec does not allow it
function value(spec, v) {
    if (spec === "bool")
        return v === true ? "yes" : v === false ? "no" : null;
    if (spec === "int")
        return typeof v === "number" && isFinite(v) ? String(Math.max(-INT_LIMIT, Math.min(INT_LIMIT, Math.round(v)))) : null;
    if (Array.isArray(spec))
        return typeof v === "string" && spec.indexOf(v) >= 0 ? v : null;
    return null;
}

// "key=value" for every key of the schema that the object carries, in the
// schema's order (so a line never depends on the caller's property order).
// A key the schema does not know is dropped; a value it does not allow is "?".
function pick(schema, obj) {
    var out = [];
    if (!obj || typeof obj !== "object")
        return out;
    for (var key in schema) {
        if (!Object.prototype.hasOwnProperty.call(schema, key) || !Object.prototype.hasOwnProperty.call(obj, key) || obj[key] === undefined)
            continue;
        var text = value(schema[key], obj[key]);
        out.push(key + "=" + (text === null ? "?" : text));
    }
    return out;
}
