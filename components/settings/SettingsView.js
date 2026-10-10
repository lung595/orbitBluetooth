.pragma library

// What the settings page needs to know about a search, as plain data: which
// settings matched, how many per category, and the first match (the one Enter
// opens). Pure, so the page only binds to it and the test can read it.

// Settings key → category id, from the index entries
function categoryOf(entries) {
    const map = {};
    for (const e of Array.isArray(entries) ? entries : [])
        map[e.id] = e.category;
    return map;
}

// `results` come from SettingsSearch.search(), best first. `categories` is
// the map made by categoryOf(). The first match is the best-ranked one;
// `firsts` names the best-ranked match of each category.
function group(results, categories) {
    const out = { "ids": {}, "counts": {}, "firsts": {}, "first": null };
    for (const r of Array.isArray(results) ? results : []) {
        const category = categories[r.id];
        if (!category)
            continue;
        out.ids[r.id] = true;
        out.counts[category] = (out.counts[category] || 0) + 1;
        if (!out.firsts[category])
            out.firsts[category] = r.id;
        if (out.first === null)
            out.first = { "id": r.id, "category": category };
    }
    return out;
}

// Index entries by id, to read a setting's label and help
function byId(entries) {
    const map = {};
    for (const e of Array.isArray(entries) ? entries : [])
        map[e.id] = e;
    return map;
}

// The category entry for `id` (or null)
function find(list, id) {
    return list.find(c => c.id === id) || null;
}
