.pragma library

// The data SettingsSearch.js searches: one entry per setting of the plugin's
// settings page, with the words a user may type for it that its label does
// not say (synonyms go in `keywords`, the help text is searched too).
// `id` is the settings key (or, for a row without one, a stable name),
// `category` the tab the setting sits in today. Kept in step with the real
// tabs by tests/settingsSearch.test.js: it fails when a tab has a setting
// that is missing here, or this file lists one the tabs no longer have.

function _entry(id, category, label, help, keywords) {
    return { "id": id, "category": category, "label": label, "help": help, "keywords": keywords };
}

// The audio facts the sound tab can show on the card line and in the detail
// view (the same keys as Audiophile.INFOS, checked by the test)
var FACTS = [
    ["connection", "Connection", ["cable", "wired", "usb", "hdmi", "analog", "optical"]],
    ["profile", "Profile", ["a2dp", "hfp", "headset", "mode"]],
    ["codec", "Codec", ["ldac", "aac", "aptx", "sbc", "format", "quality"]],
    ["bitrate", "Bit rate", ["bitrate", "kbps", "speed", "quality"]],
    ["rate", "Sample rate", ["frequency", "hz", "khz", "quality"]],
    ["bits", "Bit depth", ["resolution", "24 bit", "quality"]],
    ["channels", "Channels", ["stereo", "mono", "surround"]],
    ["latency", "Latency", ["delay", "lag", "sync"]],
    ["quantum", "Quantum", ["buffer", "pipewire", "delay"]],
    ["chain", "PC to device", ["path", "route", "pipewire", "volume"]]
];

var ENTRIES = [
    // --- Orbit tab ---------------------------------------------------------------
    _entry("maxDevices", "orbit", "Devices in orbit", "Connected devices always show", ["count", "number", "how many", "limit", "max"]),
    _entry("showLabels", "orbit", "Always show names", "Otherwise on hover", ["labels", "text", "title", "hover"]),
    _entry("showUnnamed", "orbit", "Show unnamed devices", "Devices with only an address", ["hidden", "unknown", "mac", "anonymous", "nameless"]),
    _entry("quickDisconnect", "orbit", "Quick disconnect button", "An × on connected devices, on hover", ["close", "cross", "remove", "unplug"]),
    _entry("hostGlyph", "orbit", "Center device", "The icon in the middle of the orbit", ["computer", "laptop", "desktop", "pc", "icon", "host", "middle"]),
    _entry("togetherCentre", "orbit", "The listening source takes the center", "While Listen together plays, the source sits in the middle and the other outputs orbit it", ["group", "middle", "share", "centre"]),
    _entry("togetherFineDelay", "orbit", "Wired delay", "Nudge the automatic wait that lines up wired outputs with Bluetooth ones", ["cable", "sync", "lag", "offset", "latency", "echo", "group"]),
    _entry("learnHabits", "orbit", "Learn my groups", "The suggested group is the one you listen to most, remembered on this computer only", ["habits", "memory", "suggestion", "history", "privacy", "remember"]),
    _entry("togetherHabits", "orbit", "Forget what Orbit learned", "Erases the groups Orbit remembers", ["habits", "clear", "delete", "erase", "reset", "history", "privacy"]),
    _entry("glyphOverrides", "orbit", "Reset device icons", "Puts back the icon Orbit picks for each device", ["reset", "restore", "default", "pictures", "glyph"]),
    _entry("hiddenDevices", "orbit", "Show hidden devices", "Brings back the devices sent to the black hole", ["reset", "restore", "unhide", "black hole"]),
    _entry("ignoredDevices", "orbit", "Offer ignored devices again", "Devices refused with Ignore in the pop-up are offered again", ["reset", "restore", "refused", "dismissed", "new device"]),
    _entry("report", "orbit", "Report a problem", "Copies a report with nothing personal in it", ["bug", "issue", "diagnostic", "debug", "log", "support", "copy"]),

    // --- Scanning tab ------------------------------------------------------------
    _entry("autoScan", "scanning", "Scan automatically", "When a view opens; otherwise click the center", ["search", "discover", "find", "start"]),
    _entry("offerNew", "scanning", "Offer new devices", "A card with Connect inside the view when an unpaired device shows up", ["pair", "unpaired", "discover", "card", "connect"]),
    _entry("offerPopup", "scanning", "Pop-up for new headphones", "Headphones in pairing mode are offered under the bar, even with the view closed", ["notification", "pairing", "earbuds", "alert", "new device"]),
    _entry("offerScan", "scanning", "Background scan", "Also look for new headphones by itself, a few seconds at a time", ["search", "battery", "power", "periodic", "discover"]),
    _entry("offerEvery", "scanning", "Background scan interval", "How often the background scan looks for new headphones", ["frequency", "period", "minutes", "seconds", "battery"]),
    _entry("offerMinBattery", "scanning", "No background scan below", "Battery level of this computer, when it is not plugged in", ["power", "laptop", "percent", "threshold", "low"]),
    _entry("scanSeconds", "scanning", "Scan duration", "How long a scan runs after it starts", ["time", "length", "seconds", "battery", "search"]),
    _entry("sounds", "scanning", "Sounds", "On snap, connect and disconnect", ["sound", "audio", "effects", "mute", "silent", "noise", "beep", "click"]),
    _entry("volumeTick", "scanning", "Volume tick", "A soft tick on each step, so you hear the level where it plays", ["sound", "click", "feedback", "audio", "beep", "notch"]),
    _entry("tickEvery", "scanning", "Tick every", "How big a step is: every 1 % ticks once per percent, every 5 % is sparser", ["sound", "click", "step", "percent", "density"]),
    _entry("tickAlone", "scanning", "Orbit's tick only", "While you change a level, DMS's own volume sound waits, so only the tick plays", ["sound", "click", "double", "dms", "feedback"]),
    _entry("soundVolume", "scanning", "Volume", "How loud the sounds and ticks are", ["sound", "loudness", "level", "quiet", "tick"]),

    // --- Headphones tab ----------------------------------------------------------
    _entry("ancEnabled", "headphones", "Noise control", "Supported headphones, 13 brands (needs python3)", ["anc", "ambient", "transparency", "cancelling", "cancellation", "sony", "bose", "airpods"]),
    _entry("ancEngine", "headphones", "Engine", "\"Always connected\" shows headset button presses live", ["anc", "connection", "button", "battery", "demand"]),
    _entry("ancChatOff", "headphones", "Turn off conversation awareness on disconnect", "A disconnected headset would stay in conversation mode with no way to leave it", ["speak to chat", "talk", "voice", "anc", "sony", "chat"]),
    _entry("wearPause", "headphones", "Pause when you take the headset off", "Pauses what plays when you take the headset off, resumes when you put it back on", ["wear", "sensor", "music", "media", "player", "resume", "ears", "earbuds"]),
    _entry("realPictures", "headphones", "Real device pictures (uses the internet)", "Looks up each device's model name online; the only feature that goes online", ["photo", "image", "download", "network", "privacy", "wikimedia", "sketchfab"]),
    _entry("picturesClear", "headphones", "Delete downloaded pictures", "Erases the pictures kept on this computer", ["cache", "clear", "remove", "photo", "image", "privacy", "disk"]),

    // --- Sound tab ---------------------------------------------------------------
    _entry("separatePc", "sound", "Separate PC volume", "For devices with a volume of their own: the device's level and what this PC sends to it, set apart", ["two", "double", "pipewire", "level", "device volume"]),
    _entry("volumeSteps", "sound", "Steps", "Smart: slow notches move by 1 %, a quick run builds up speed. Fixed: the same step every time", ["wheel", "keys", "scroll", "smart", "fixed", "acceleration", "notch"]),
    _entry("volumeSpeed", "sound", "Speed-up", "How far a quick run can go per notch: Gentle, Balanced or Fast", ["acceleration", "wheel", "scroll", "keys", "fast", "slow", "step"]),
    _entry("volumeStep", "sound", "Step", "The fixed volume step, in percent", ["percent", "increment", "keys", "wheel", "size"]),
    _entry("volumeKeys", "sound", "Volume keys", "Hand the volume keys to Orbit's smart steps, or give them back to DMS", ["keyboard", "shortcut", "keybind", "bindings", "media keys", "hotkey", "dms"]),
    _entry("popupMode", "sound", "Pop-up", "Shows both levels whenever one changes; DMS's own OSD is switched off", ["osd", "island", "indicator", "overlay", "bar", "edge", "notification"]),
    _entry("popupSize", "sound", "Size", "How big the volume pop-up is", ["compact", "medium", "large", "bigger", "smaller", "osd"]),
    _entry("popupScreens", "sound", "Screens", "Where the pop-up shows when a volume changes: the screen you work on, or every screen", ["monitor", "display", "multi", "every", "osd"]),
    _entry("scopeStyle", "sound", "Visualizer", "How the sound is drawn inside the half circles: points, rays or waves", ["spectrum", "cava", "analyzer", "equalizer", "animation", "graphics", "music"]),
    _entry("scopeFps", "sound", "Visualizer motion", "While the pop-up or a card shows, nothing otherwise; Smooth draws twice as often", ["fps", "frame rate", "smooth", "light", "battery", "animation", "cpu"])
].concat(FACTS.map(f => _entry("factCard_" + f[0], "sound", f[1] + ": on the line", "Shown under the device's name and in the pop-up", ["audio details", "line", "card", "pipewire"].concat(f[2]))),
         FACTS.map(f => _entry("factMore_" + f[0], "sound", f[1] + ": more info", "Shown when the info button unfolds the card", ["audio details", "more", "detail", "pipewire"].concat(f[2]))),
         [
    // --- Desktop tab -------------------------------------------------------------
    _entry("desktopBackdrop", "desktop", "Backdrop", "Veil behind the orbit", ["background", "dim", "darkness", "opacity", "transparency", "blur", "veil"]),
    _entry("desktopAmbient", "desktop", "Ambient motion", "Keep moving when the pointer is away", ["animation", "idle", "battery", "cpu", "drift", "wallpaper"]),

    // --- Look tab ----------------------------------------------------------------
    _entry("holeStyle", "look", "Black hole", "Where hidden devices go", ["hide", "hidden", "shadow", "bubble", "style", "space"]),
    _entry("chargeBeamStyle", "look", "Charging beam", "How power flows to charging devices", ["battery", "power", "pulse", "filament", "chain", "horizon", "animation", "plug"]),
    _entry("shootingStars", "look", "Shooting stars", "Streaks that cross the night sky now and then", ["meteor", "comet", "animation", "sky", "falling"]),
    _entry("starDensity", "look", "Stars", "How many stars the night sky has", ["sky", "background", "low", "normal", "high", "density", "count"]),
    _entry("imageFolder", "look", "Custom images folder", "PNGs named after devices replace their icons", ["pictures", "icons", "png", "directory", "path", "theme", "photos"])
]);
