.pragma library

// Which devices may have a picture looked up online (only when the user
// turned "Real device pictures" on). The name of the model is the only thing
// that ever leaves the machine, so this is deliberately strict: only paired
// or connected devices, or an audio device offered in the "new device"
// pop-up (allowed by the owner, see CLAUDE.md); never a stranger's phone
// seen while scanning, and never a name that looks personal.

// "WH-1000XM6" -> "WH-1000XM6"; "" when nothing should be sent
function queryFor(name, known) {
    const n = (name || "").replace(/\s*[\(\[][^\)\]]*[\)\]]\s*/g, " ").trim();
    if (!known || n.length < 4 || n.length > 40)
        return "";
    // Only the address, or a name with no letter and digit mix to recognise
    if (/^([0-9a-f]{2}[:\-_]){5}[0-9a-f]{2}$/i.test(n) || !/[a-z]/i.test(n))
        return "";
    // "Marie's iPhone", "iPhone de Marie": a person's name, not a model
    if (/['’]s\b|\b(de|von|van|di|del)\s+\p{Lu}/u.test(n))
        return "";
    return n;
}

// "Photo by Ada · CC BY · Wikimedia Commons"
function creditText(credit) {
    if (!credit)
        return "";
    const by = credit.author ? "by " + credit.author : "";
    return [credit.title ? "“" + credit.title + "”" : "", by, credit.license, credit.source].filter(x => x).join(" · ");
}
