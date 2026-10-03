.pragma library

// Is the desktop of one screen hidden behind windows? Ambient motion keeps
// the desktop orbit drifting while nobody hovers it; behind windows that
// drift is never seen, so it pauses there (P123).
// Reads niri's state as DMS's NiriService keeps it (event-driven, no polling).
//
// niri gives the size of each tile and its column, not where it sits on
// screen. But niri scrolls the view as little as possible to keep the
// focused column in view, so columns that add up to the screen's width
// leave no empty space: the desktop only shows through the gaps.

// Tiles this close to the screen size leave only the gaps visible.
// Height is looser: the bar's exclusive zone takes part of it.
var minWidth = 0.9;
var minHeight = 0.9;

// workspaces: { id: { id, output, is_active } }
// windows: [{ workspace_id, is_floating, layout: { tile_size: [w, h], pos_in_scrolling_layout: [column, row] } }]
// output: the screen's name (e.g. "DP-2"); width, height: its logical size.
function covered(workspaces, windows, output, width, height, inOverview) {
    // The overview shows the desktop behind the zoomed-out workspaces
    if (inOverview || !output || !(width > 0) || !(height > 0))
        return false;
    let active = null;
    for (const id in workspaces || {}) {
        const ws = workspaces[id];
        if (ws && ws.output === output && ws.is_active) {
            active = ws.id !== undefined ? ws.id : Number(id);
            break;
        }
    }
    if (active === null)
        return false;

    // Width and stacked height of each column of the active workspace.
    // Floating windows can be anywhere, so they never count.
    const columns = {};
    for (const w of windows || []) {
        const l = w && w.layout;
        const size = l && l.tile_size;
        const pos = l && l.pos_in_scrolling_layout;
        if (!w || w.workspace_id !== active || w.is_floating || !size || !pos)
            continue;
        const c = columns[pos[0]] || (columns[pos[0]] = { w: 0, h: 0 });
        c.w = Math.max(c.w, size[0]);
        c.h += size[1];
    }
    // Only columns as tall as the screen hide the desktop behind them
    let filled = 0;
    for (const k in columns)
        if (columns[k].h >= height * minHeight)
            filled += columns[k].w;
    return filled >= width * minWidth;
}
