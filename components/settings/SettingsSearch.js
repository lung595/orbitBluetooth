.pragma library

// Search over a list of settings: the words typed find a setting by its
// label, its help or the keywords it is filed under, whatever its exact name.
// Pure logic, no state, nothing about any one plugin: the same file serves
// every settings page. Tested by tests/settingsSearch.test.js.
//
// An entry is { id, label, help, keywords[] } (a `category` may ride along: it
// is not searched, the view groups by it). A result is
// { id, score, label: [[from, to)...], help: [[from, to)...] }: the ranges are
// offsets in the original label and help, ready to be highlighted.

var MAX_RESULTS = 20;
// A longer query is cut, not refused: the first words are what the user meant
var MAX_QUERY = 64;
// Words beyond these are ignored: every one of them must match (AND), so a
// long sentence would only ever find nothing
var MAX_WORDS = 6;
// Typos are forgiven from this length on: a short word has too many neighbours
var TYPO_FROM = 5;

// Where a word was found counts for more or less
var WEIGHT = { "label": 1, "keyword": 0.8, "help": 0.5 };
// How the word was found: the typed word is the whole word, starts it, or is one edit away
var EXACT = 100, PREFIX = 80, TYPO = 50;

// Accents are dropped and case is folded one character at a time, so every
// letter keeps the offset it has in the original text (the highlight needs it).
// "" for a combining mark on its own (a decomposed accent).
function _fold(ch) {
    const code = ch.charCodeAt(0);
    if (code < 0x80)
        return ch.toLowerCase();
    const base = ch.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
    return base.length ? base[0] : "";
}

// A letter or a digit of any script; everything else separates words. Written
// as ranges because the engine behind QML does not take \p{...} on every Qt version.
function _isWord(ch) {
    const code = ch.charCodeAt(0);
    if (code < 0x80)
        return (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
    return code >= 0xc0 && !(code >= 0x2000 && code <= 0x206f) && !(code >= 0x3000 && code <= 0x303f);
}

// The words of a text: [{ t: folded word, at: offset of each of its letters in the text }]
function _words(text) {
    const out = [];
    let cur = null;
    for (let i = 0; i < text.length; i++) {
        const f = _fold(text[i]);
        if (f === "") {
            // A combining mark belongs to the letter before it
            continue;
        }
        if (_isWord(f)) {
            if (!cur) {
                cur = { "t": "", "at": [] };
                out.push(cur);
            }
            cur.t += f;
            cur.at.push(i);
        } else {
            cur = null;
        }
    }
    return out;
}

// Is `a` one edit (a letter added, dropped, changed or two swapped) from `b`?
// A linear walk, not a table: this runs against every word of every setting.
function _oneEdit(a, b) {
    const la = a.length, lb = b.length;
    if (Math.abs(la - lb) > 1 || a === b)
        return false;
    let i = 0;
    while (i < la && i < lb && a[i] === b[i])
        i++;
    if (la === lb) {
        if (a.slice(i + 1) === b.slice(i + 1))
            return true;
        return a[i] === b[i + 1] && a[i + 1] === b[i] && a.slice(i + 2) === b.slice(i + 2);
    }
    return la > lb ? a.slice(i + 1) === b.slice(i) : a.slice(i) === b.slice(i + 1);
}

// How a typed word matches one word of a text: { score, to } with `to` the
// number of letters of the text's word to highlight, or null for no match
function _match(q, w) {
    if (w.t === q)
        return { "score": EXACT, "to": q.length };
    if (w.t.startsWith(q))
        return { "score": PREFIX, "to": q.length };
    if (q.length >= TYPO_FROM) {
        // A typo in a word being typed still counts: compare with the same length of the word
        if (_oneEdit(q, w.t))
            return { "score": TYPO, "to": w.t.length };
        if (w.t.length > q.length && _oneEdit(q, w.t.slice(0, q.length)))
            return { "score": TYPO, "to": q.length };
    }
    return null;
}

function _ranges(words, picks) {
    const spans = picks.map(p => {
        const w = words[p.word];
        return [w.at[0], w.at[p.to - 1] + 1];
    }).sort((x, y) => x[0] - y[0]);
    const out = [];
    for (const s of spans) {
        const last = out[out.length - 1];
        if (last && s[0] <= last[1])
            last[1] = Math.max(last[1], s[1]);
        else
            out.push(s);
    }
    return out;
}

// Folds the entries once; search() takes the result so typing does not fold
// the same help texts again on every key
function prepare(entries) {
    const list = [];
    for (const e of Array.isArray(entries) ? entries : []) {
        if (!e || typeof e.id !== "string" || typeof e.label !== "string")
            continue;
        const help = typeof e.help === "string" ? e.help : "";
        list.push({
            "id": e.id,
            "label": _words(e.label),
            "help": _words(help),
            "keywords": (Array.isArray(e.keywords) ? e.keywords : []).filter(k => typeof k === "string").map(_words)
        });
    }
    return { "list": list };
}

// How the typed word `q` is found in one setting: the best score over its label,
// keywords and help, and the words to highlight in the label and the help
function _scan(q, item) {
    const out = { "score": 0, "label": [], "help": [] };
    const visit = (words, kind, marks) => {
        words.forEach((w, i) => {
            const m = _match(q, w);
            if (!m)
                return;
            out.score = Math.max(out.score, m.score * WEIGHT[kind]);
            if (marks)
                marks.push({ "word": i, "to": m.to });
        });
    };
    visit(item.label, "label", out.label);
    for (const k of item.keywords)
        visit(k, "keyword", null);
    visit(item.help, "help", out.help);
    return out;
}

// Ranked results for `query`. `source` is the entries or what prepare() made of
// them. Nothing for an empty query; no regular expression is built from it.
function search(source, query) {
    if (typeof query !== "string")
        return [];
    const typed = _words(query.slice(0, MAX_QUERY)).slice(0, MAX_WORDS).map(w => w.t);
    if (typed.length === 0)
        return [];
    const prepared = Array.isArray(source) ? prepare(source) : source;
    const items = prepared && Array.isArray(prepared.list) ? prepared.list : [];
    const found = [];
    items.forEach((item, order) => {
        let score = 0;
        const label = [], help = [];
        for (const q of typed) {
            const hit = _scan(q, item);
            // Every typed word must be found somewhere (AND)
            if (hit.score === 0)
                return;
            score += hit.score;
            label.push(...hit.label);
            help.push(...hit.help);
        }
        found.push({
            "order": order,
            "id": item.id,
            "score": score,
            "label": _ranges(item.label, label),
            "help": _ranges(item.help, help)
        });
    });
    // Equal scores keep the order of the page, so the list never shuffles
    found.sort((a, b) => b.score - a.score || a.order - b.order);
    return found.slice(0, MAX_RESULTS).map(f => ({ "id": f.id, "score": f.score, "label": f.label, "help": f.help }));
}
