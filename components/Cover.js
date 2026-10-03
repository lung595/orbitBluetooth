.pragma library

// Is the desktop of one screen hidden behind a window? Ambient motion keeps
// the desktop orbit drifting while nobody hovers it; behind a fullscreen or
// maximized window that drift is never seen, so it pauses there (P123).
// Reads niri's state as DMS's NiriService keeps it (event-driven, no polling).

// A tile this close to the screen size leaves only the gaps visible.
// Height is looser: the bar's exclusive zone takes part of it.
var minWidth = 0.97;
var minHeight = 0.9;

// workspaces: { id: { output, is_active, active_window_id } }
// windows: [{ id, is_floating, layout: { tile_size: [w, h] } }]
// output: the screen's name (e.g. "DP-2"); width, height: its logical size.
function covered(workspaces, windows, output, width, height, inOverview) {
    // The overview shows the desktop behind the zoomed-out workspaces
    if (inOverview || !output || !(width > 0) || !(height > 0))
        return false;
    let activeId = null;
    for (const id in workspaces || {}) {
        const ws = workspaces[id];
        if (ws && ws.output === output && ws.is_active) {
            activeId = ws.active_window_id;
            break;
        }
    }
    if (activeId === null || activeId === undefined)
        return false;
    // niri keeps the active column in view, so the active window is the one
    // in front; a floating window can be moved and is never trusted to cover.
    for (const w of windows || []) {
        if (!w || w.id !== activeId)
            continue;
        const size = w.layout && w.layout.tile_size;
        if (w.is_floating || !size || size.length < 2)
            return false;
        return size[0] >= width * minWidth && size[1] >= height * minHeight;
    }
    return false;
}
