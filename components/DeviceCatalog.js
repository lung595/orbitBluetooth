.pragma library

// Name-pattern recognition: maps a Bluetooth device to one of the glyphs in
// Glyphs.js. A handful of ordered regex rules covers whole product families
// (every MX Master, every WH-1000XMx, every Galaxy Buds...). The BlueZ icon
// category is used both as a tie-breaker and as a fallback.

// Glyph kind -> coarse family, used to reject rules that contradict what
// BlueZ reports (e.g. a "G733" headset must not become a gaming mouse).
var families = {
    headphones: "audio", headphonesSlim: "audio", headphonesPremium: "audio", headset: "audio",
    earbudsStem: "audio", earbudsRound: "audio", earbudsCase: "audio",
    speaker: "audio", speakerTall: "audio", soundbar: "audio",
    mouse: "pointer", mouseErgo: "pointer", mouseGaming: "pointer", trackpad: "pointer",
    keyboard: "keyboard", gamepad: "gaming",
    phone: "phone", laptop: "computer", desktop: "computer"
};

// Ordered: first match wins. Specific families before generic words.
var rules = [
    // Premium / studio over-ear
    [/airpods\s*max|sonos\s*ace|\bpx[78]\b|bathys|\bmw75\b|\bmw65\b|dyson\s*zone/i, "headphonesPremium"],
    // Stem earbuds
    [/airpods|earpods|nothing\s*ear|cmf\s*buds|freebuds(?!\s*(studio|pro\s*[1-9]?\s*$))|(xiaomi|redmi)\s*buds|oneplus\s*buds|liberty\s*[34]|soundpeats\s*air/i, "earbudsStem"],
    // Round earbuds
    [/\bwf-|galaxy\s*buds|pixel\s*buds|jabra\s*elite|linkbuds|beats\s*(fit|studio\s*buds|solo\s*buds|flex)|powerbeats|momentum\s*(true\s*wireless|tw)|\bmtw\d|bose.*earbuds|qc\s*earbuds|ultra\s*open|sport\s*earbuds|\btws\b|earbuds?|\bbuds\b|earphones?|ecouteurs?|écouteurs?/i, "earbudsRound"],
    // Gaming headsets (before gaming mice: Logitech reuses the G prefix)
    [/arctis|hyperx|\bcloud\s*(ii|iii|alpha|flight|stinger|mix)|barracuda|kraken|blackshark|\bnari\b|virtuoso|\bhs\d{2}\b|\bvoid\b|astro\s*a\d|g\s?(335|435|535|633|635|733|735|933|935)\b|g\s*pro\s*x(?!\s*superlight)|\bnova\s*\d|headset|casque\s*gamer/i, "headset"],
    // Slim, oval-cup headphones
    [/\bwh-|1000xm\d|ult\s*wear|sony.*\bxm\d|bose\s*(qc|quietcomfort|nc\s*700|700)|momentum\s*[34]|accentum|\bhd\s*\d{3}\s*bt|beats\s*(studio|solo)|marshall\s*(major|monitor|motif)|soundcore\s*(life|space|q\d)|jbl\s*(tune|live|tour)\s*\d{3}/i, "headphonesSlim"],
    [/headphones?|kopfh[oö]rer|casque|auriculares/i, "headphones"],

    // Soundbars and speakers
    [/soundbar|sound\s*bar|sonos\s*(arc|beam|ray)|\bht-[a-z0-9]+/i, "soundbar"],
    [/sonos|homepod|\becho\b|nest\s*(audio|mini|hub)|google\s*home|alexa|bose\s*(home|portable\s*smart|music)|marshall\s*(acton|stanmore|woburn)|\bera\s*\d{3}/i, "speakerTall"],
    [/jbl\s*(flip|charge|go|clip|xtreme|boombox|pulse)|ultimate\s*ears|\bue\s*(boom|wonderboom|megaboom|hyperboom)|wonderboom|soundlink|\bsrs-|ult\s*field|marshall\s*(emberton|willen|middleton|stockwell|kilburn|tufton)|beats\s*pill|soundcore\s*(motion|boom|flare|select)|tribit|speaker|enceinte|lautsprecher|altavoz/i, "speaker"],

    // Pointing devices
    [/mx\s*master|mx\s*vertical|\blift\b|m720|ergo\s*m575|\bm575\b|triathlon|sculpt\s*ergo|vertical\s*mouse|ergonomic/i, "mouseErgo"],
    [/g\s?(203|302|303|304|305|309|403|502|603|604|700|703|705|900|903)\b|g\s*pro(\s*wireless|\s*x\s*superlight|\s*superlight)?\b|superlight|viper|deathadder|basilisk|orochi|\bnaga\b|pro\s*click|pulsar|zowie|glorious|lamzu|finalmouse|aerox|\brival\b|harpoon|dark\s*core|katar|sabre|atk\b|vxe/i, "mouseGaming"],
    [/magic\s*trackpad|trackpad|touchpad/i, "trackpad"],
    [/mx\s*anywhere|\bm\d{3}\b|pebble|signature\s*m|magic\s*mouse|arc\s*mouse|surface\s*mouse|mouse|maus|souris|rat[oó]n/i, "mouse"],

    // Keyboards, controllers, pens
    [/mx\s*keys|mx\s*mechanical|\bk\d{3}\b|keychron|magic\s*keyboard|nuphy|lofree|hhkb|pop\s*keys|\bcraft\b|keyboard|clavier|tastatur|teclado/i, "keyboard"],
    [/xbox|dualsense|dualshock|wireless\s*controller|pro\s*controller|joy-?con|8bitdo|gamesir|stadia|steam\s*controller|controller|gamepad|manette/i, "gamepad"],
    [/pencil|stylus|s\s*pen|\bpen\b|stylet/i, "pen"],

    // Wearables
    [/apple\s*watch|amazfit\s*(gts|bip)|fitbit|watch\s*fit|mi\s*band|smart\s*band|\bband\s*\d|whoop/i, "watch"],
    [/galaxy\s*watch|pixel\s*watch|garmin|fenix|forerunner|venu|epix|instinct|huawei\s*watch|amazfit|ticwatch|fossil|withings|polar|suunto|coros|watch|montre/i, "watchRound"],
    [/ray-?ban|meta\s*glasses|glasses|spectacles|xreal|viture|rokid|lunettes/i, "glasses"],
    [/quest|oculus|vision\s*pro|valve\s*index|\bpico\b|\bvr\b/i, "vr"],

    // Phones, tablets, computers, TVs, cars
    [/ipad|galaxy\s*tab|\btab\s*s\d|pixel\s*tablet|surface\s*(pro|go)|matepad|tablet|tablette/i, "tablet"],
    [/iphone|pixel(?!\s*(buds|watch|tablet))|galaxy\s*(s|a|z|m|note|fold|flip)\s*\d*|oneplus|xiaomi|redmi|poco|nothing\s*phone|fairphone|motorola|\bmoto\b|huawei|honor|oppo|vivo|realme|nokia|phone|t[eé]l[eé]phone|android/i, "phone"],
    [/macbook|thinkpad|\bxps\b|laptop|notebook|zenbook|vivobook|surface\s*laptop|framework|chromebook|ideapad|yoga|spectre|envy|elitebook|latitude|portable/i, "laptop"],
    [/imac|mac\s*mini|mac\s*studio|mac\s*pro|desktop|\bpc\b|workstation|tower/i, "desktop"],
    [/\btv\b|bravia|webos|tizen|fire\s*tv|chromecast|roku|apple\s*tv|shield|t[eé]l[eé]vision|fernseher/i, "tv"],
    [/car\b|carplay|android\s*auto|tesla|bmw|audi|\bvw\b|volkswagen|mercedes|toyota|ford|sync\s*\d|peugeot|renault|citro[eë]n|\bkia\b|hyundai|skoda|seat|volvo|honda|nissan|mazda|uconnect|polestar|opel|fiat|dacia|lexus|porsche|voiture/i, "car"]
];

// BlueZ Device1.Icon -> fallback glyph.
function kindFromBluezIcon(icon) {
    const i = (icon || "").toLowerCase();
    if (i.indexOf("headphone") >= 0) return "headphonesSlim";
    if (i.indexOf("headset") >= 0) return "headphones";
    if (i.indexOf("speaker") >= 0 || i.indexOf("audio-card") >= 0) return "speaker";
    if (i.indexOf("mouse") >= 0) return "mouse";
    if (i.indexOf("tablet") >= 0) return "pen";
    if (i.indexOf("keyboard") >= 0) return "keyboard";
    if (i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0) return "gamepad";
    if (i.indexOf("phone") >= 0) return "phone";
    if (i.indexOf("computer") >= 0) return "laptop";
    if (i.indexOf("display") >= 0 || i.indexOf("video") >= 0) return "tv";
    if (i.indexOf("watch") >= 0) return "watchRound";
    return "";
}

function familyFromBluezIcon(icon) {
    const i = (icon || "").toLowerCase();
    if (i.indexOf("audio") >= 0) return "audio";
    if (i.indexOf("mouse") >= 0) return "pointer";
    if (i.indexOf("keyboard") >= 0) return "keyboard";
    if (i.indexOf("gaming") >= 0) return "gaming";
    if (i.indexOf("phone") >= 0) return "phone";
    if (i.indexOf("computer") >= 0) return "computer";
    return "";
}

function deviceName(device) {
    if (!device)
        return "";
    return device.name || device.deviceName || "";
}

// A device is "unnamed" when BlueZ only knows its address.
function isUnnamed(device) {
    const n = deviceName(device).trim();
    if (!n)
        return true;
    return /^([0-9a-f]{2}[:\-_]){5}[0-9a-f]{2}$/i.test(n);
}

function kindFor(name, bluezIcon) {
    const fam = familyFromBluezIcon(bluezIcon);
    for (let r = 0; r < rules.length; r++) {
        if (!rules[r][0].test(name))
            continue;
        const kind = rules[r][1];
        const ruleFam = families[kind] || "";
        if (fam && ruleFam && fam !== ruleFam)
            continue;
        return kind;
    }
    return kindFromBluezIcon(bluezIcon) || "bluetooth";
}

// Resolve with user overrides first ({ "AA:BB:..": "mouseErgo" }).
function resolve(device, overrides) {
    if (!device)
        return "bluetooth";
    const o = overrides ? overrides[device.address] : undefined;
    if (o && o !== "auto")
        return o;
    return kindFor(deviceName(device), device.icon);
}

// Stable 0..1 pseudo-random value derived from a string (the MAC address).
function hash01(str) {
    let h = 2166136261;
    const s = str || "";
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619);
    }
    return ((h >>> 0) % 100000) / 100000;
}

function formatDuration(ms) {
    const total = Math.max(0, Math.floor(ms / 1000));
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const pad = v => (v < 10 ? "0" : "") + v;
    return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s);
}
