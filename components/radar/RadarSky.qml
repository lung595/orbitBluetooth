import QtQuick
import "../card"
import "Radar.js" as Radar
import "RadarSky.js" as Sky

// The sky behind the radar's dials: the card's glass seen as a night sky with two
// faint nebulae in the group's colors, a few stars and the ring the small dials
// orbit on (RadarSky.js decides where everything goes and keeps it clear of what
// has to be read). One Canvas, painted when the radar opens and again only when
// what it draws changes: its size, the theme, the group's colors, the dials' places
// or the room of the actions. Never for the hero, a level, a mute, the pointer or
// the clock, and no Timer or animation here, so an open radar costs nothing more.
// Decoration only: it takes no click and says nothing to a screen reader.
Canvas {
    id: sky

    required property PaperColors paper
    // The group's colors (MemberPalette) and the one to fall back on for the second nebula
    required property var colors
    required property color fallback
    // Where the dials are: Radar.layout's places around (cx, cy), at the radar's side
    required property var places
    required property real cx
    required property real cy
    required property real side
    // Where the band the actions are laid out in begins, and how far down the card's header goes
    required property real actionsY
    required property real headerHeight

    readonly property color tint: paper.level(colors[0])
    readonly property color tint2: paper.level(colors[1] ?? fallback)
    readonly property bool light: paper.light

    function rgba(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function nebula(ctx, x, y, radius, color, alpha) {
        const g = ctx.createRadialGradient(x, y, 0, x, y, radius);
        g.addColorStop(0, rgba(color, alpha));
        g.addColorStop(1, rgba(color, 0));
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, width, height);
    }

    function draw(ctx) {
        ctx.reset();
        const w = width, h = height;
        const top = Sky.top(headerHeight), body = h - top;
        const clear = Sky.clearings(places, cx, cy, w, actionsY);

        // Inside the card's rounded glass, and under the header
        ctx.save();
        const corner = Math.round(w * 0.075);
        ctx.beginPath();
        ctx.roundedRect(1, 1, w - 2, h - 2, corner, corner);
        ctx.clip();
        ctx.beginPath();
        ctx.rect(0, top, w, body);
        ctx.clip();

        nebula(ctx, 0.20 * w, top + 0.30 * body, 0.55 * Math.max(w, body), tint, light ? 0.10 : 0.08);
        nebula(ctx, 0.85 * w, top + 0.70 * body, 0.45 * Math.max(w, body), tint2, light ? 0.08 : 0.06);

        for (const s of Sky.stars(w, top, body, clear)) {
            ctx.fillStyle = s.tinted ? rgba(tint, s.a) : paper.fg(s.a);
            ctx.beginPath();
            ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
            ctx.fill();
        }

        // The orbit, in the card's ink: the group's color lives in the nebulae and stars
        const radius = Radar.ORBIT * side;
        ctx.lineWidth = 1;
        for (const group of Sky.dashes(radius, cx, cy, light, clear)) {
            ctx.strokeStyle = paper.fg(group.a);
            ctx.beginPath();
            for (const [from, to] of group.spans) {
                ctx.moveTo(cx + Math.cos(from) * radius, cy + Math.sin(from) * radius);
                ctx.arc(cx, cy, radius, from, to, false);
            }
            ctx.stroke();
        }
        ctx.restore();

        // The sky fades in under the header
        ctx.save();
        ctx.globalCompositeOperation = "destination-out";
        const fade = ctx.createLinearGradient(0, top, 0, top + Sky.FADE);
        fade.addColorStop(0, "rgba(0,0,0,1)");
        fade.addColorStop(1, "rgba(0,0,0,0)");
        ctx.fillStyle = fade;
        ctx.fillRect(0, top, w, Sky.FADE);
        ctx.restore();
    }

    enabled: false
    Accessible.ignored: true
    renderStrategy: Canvas.Cooperative
    onPaint: draw(getContext("2d"))
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLightChanged: requestPaint()
    onTintChanged: requestPaint()
    onTint2Changed: requestPaint()
    onPlacesChanged: requestPaint()
    // actionsY is chips.y = cy + hero.r + UNDER, so it also moves whenever cy, the hero's
    // radius or the header (skyTop) change: those feed the paint but need no trigger of
    // their own. Cooperative coalesces the calls. If RadarChips stops following cy, add them here.
    onActionsYChanged: requestPaint()
}
