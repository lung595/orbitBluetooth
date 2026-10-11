# Orbit · GitHub mark beside "Copy report" (NAK-539)

Page to judge: `docs/design/report-github/index.html` (one self-contained file, no network, no image). Switches: theme (stock, green, wallpaper-generated), light / dark, panel width (518 wide, 436 narrow, 360 stress), Reduce motion, clipboard tool present / missing, state shown in the panel. Under the panel: the row as it is on `main` (before), every state of the new row side by side, the target, motion, contrast and copy tables.

Model (D453): the row approved on Sands, commit `5ce1046`, `docs/design/copy-report.md`. Same layout and same behaviour. Only three things are Orbit's own, listed in "Differences from the model". A difference found anywhere else is a defect of this spec.

Idea: the report is copied, then the next step lights up beside it. Why it is not generic: no toast, no green tick; "Copied" is marked by the dotted orbit of Orbit's sky (2 px on, 6 px off) at the foot of the button.

## Place

Settings, category "Reset & help" (`components/settings/ResetPage.qml`), last row, after the three reset buttons. It replaces the layout of `components/settings/ReportRow.qml`. Nothing else on the page changes.

## Before (main, 1.15.0)

One 12 px sentence (title and hint joined), an `ActionButton` 34 px high, and a `GuideLink` (14 px mark in a 24 x 24 target) that opens the guide, not the place where the report is pasted. A `Row` that does not wrap: at a 152 px column the sentence is squeezed to a few pixels. The failure is told by red text only.

## Anatomy, sizes, tokens

| Part | Size | Token |
|---|---|---|
| Row | wrapping row, gaps 8 px (vertical) and 16 px (horizontal), centred vertically | none |
| Text block | flexible, wraps under 160 px | none |
| Title | `Theme.fontSizeMedium` (14), weight Medium, line 20 px | `Theme.surfaceText` |
| Help line | `Theme.fontSizeSmall` (12), line 16 px | `Theme.surfaceVariantText` |
| Button | 112 x 44 px, padding 16 px, radius `Theme.cornerRadius` (12), border 1 px, label 14 px centred | border `Theme.outline`, label `Theme.surfaceText`, no fill |
| Button hover fill | whole button | `Theme.surfaceContainerHigh` |
| Copied tint | whole button | `Theme.primary` at 14 % |
| Copied border, check (16 px, 1.5 px round stroke) | | `Theme.primary` |
| Dotted orbit (copied only) | 1 px high, 16 px from each side, 6 px above the bottom edge, 2 px on / 6 px off | `Theme.primary` |
| GitHub mark beside the button | existing `GitHubMark` 18 px in a 44 x 44 target, 8 px right of the button | `Theme.surfaceVariantText`; hover, focus and while "Copied": `Theme.primary` |
| Mark label | 12 / 16 px, padding 4 / 8 px, radius 12, 4 px under the controls, wraps, never leaves the column | fill `Theme.surfaceContainerHigh`, text `Theme.surfaceText`, edge `Theme.withAlpha(Theme.outline, 0.24)` |
| Guided message | existing `HelpNote` look, full row width, padding 8 / 12 px, radius 12, gap 4 px, its own `GitHubMark` in a 44 x 44 target | fill `Theme.surfaceContainerHighest`, border `Theme.withAlpha(Theme.outline, 0.24)`, title `Theme.surfaceText` Bold 14, hint `Theme.surfaceVariantText` 12 |

The button width is fixed (112 px) so nothing moves when its label changes.

## Layout at each width (measured in WebKit, rail 160 px)

| Panel | Column | Controls | Mark |
|---|---|---|---|
| 518 px | 310 px | under the help line, left aligned, 8 px below | 8 px right of the button, same top |
| 436 px | 228 px | same | same |
| 360 px (stress) | 152 px | same | drops under the button, 8 px below, left aligned |
| column of 340 px or more | | on the text's line, at the right | 8 px right of the button |

Button + gap + mark = 164 px. With the 160 px text block and the 16 px gap they need 340 px to share a line. Nothing overlaps at any width.

## States

| Part | State | What is drawn |
|---|---|---|
| Button | Rest | outline button "Copy report" |
| Button | Hover | fill `surfaceContainerHigh` under the label |
| Button | Pressed | hover fill, button at 97 % |
| Button | Focus-visible | 2 px `Theme.primary` ring, 2 px offset |
| Button | Collecting | label "Collecting…" in `surfaceVariantText`, presses ignored (about 2 s) |
| Button | Copied | primary border, 14 % primary tint, check + "Copied", dotted orbit; help line changes; back to rest alone after 4 s |
| Button | No clipboard tool | button back to rest, guided message under the row; stays until the next press or until the page closes |
| Mark | Rest | `Theme.surfaceVariantText` |
| Mark | Hover | `Theme.primary`, label shown |
| Mark | Focus-visible | `Theme.primary`, 2 px primary ring, 2 px offset, label shown |
| Mark | After "Copied" | `Theme.primary` for as long as "Copied" is shown |
| Row | Disabled, empty, error, loading | no disabled or empty form: the row is always available. Error = the guided message. Loading = Collecting |

Keyboard order: "Copy report", the GitHub mark beside it, then the mark of the guided message when it is shown. Enter and Space press the focused control. The help line and the message are announced (`Accessible.name` / `Accessible.description` updated with the state).

## Target of the mark

`https://github.com/lung595/orbitBluetooth/issues/new/choose`, opened with `Qt.openUrlExternally` on click or key press only (Q153). The address is a constant: the report is never put in it, nothing is prefilled, the plugin makes no network access. `bug.yml` already exists in the repository. The mark of the guided message keeps its own target: `docs/GUIDE.md#report-a-problem`.

## Motion (kit durations, `OutCubic`; exits never longer than entries)

| What | Property | Duration |
|---|---|---|
| Hover fill | opacity | 150 ms in, 100 ms out |
| Press | scale to 0.97 | 100 ms in, 100 ms out |
| Copied label, tint, dotted orbit | opacity | 150 ms in, 100 ms out |
| Guided message | opacity | 150 ms in, 100 ms out |
| GitHub mark colour, mark label | colour / opacity | 150 ms in, 100 ms out |
| Reduce motion (`SettingsData.reduceMotion`) | opacity only | 150 ms, nothing scales |

All are one-shot `Behavior`s. Nothing moves at rest. The only `Timer` (4000 ms, single shot) runs while "Copied" is shown.

## Exact copy (English only, no em dash)

| Part | Text |
|---|---|
| Title | Anonymous report |
| Help line | Versions, states and error codes only. It stays on this PC until you paste it. |
| Button | Copy report |
| Button while collecting | Collecting… |
| Button once copied | Copied |
| Help line once copied | Report copied. Read it, then paste it in a GitHub issue. |
| Help line once copied, DMS clipboard history on | Report copied. Read it, then paste it in a GitHub issue. It holds nothing personal, but DMS's clipboard history may keep it. |
| Guided message, reason | The report could not be copied |
| Guided message, what to do | Install wl-clipboard, or run dms ipc call orbitBluetooth diagnostics in a terminal. |
| GitHub mark beside the button, accessible name | Open a new issue for Orbit on GitHub |
| GitHub mark beside the button, label on hover or focus | Open an issue on GitHub |
| GitHub mark in the guided message, accessible name | Open the guide: Report a problem |

## Contrast

Same roles and same fictitious palettes as the model, so the model's table holds (lowest values: text 12.57, help line 8.83, button outline 4.24, primary on surface 6.08, primary on 14 % tint 4.99, mark at rest 8.83). The dotted orbit is primary on the primary tint (lowest 4.99, need 3). The page recomputes every pair live for the palette shown; the checker found no failure in the six palettes. To re-measure on the build with real themes (`HelpNote` uses `surfaceContainerHighest`, the page draws it with `high`).

## Differences from the model (assumptions, conservative, not asked)

1. Sands' sand heap is not copied (story). In its place: the dotted orbit described above, opacity only. It changes no size and no position; it can be removed without touching the layout if the Design Director prefers nothing.
2. The clipboard-history sentence Orbit already has (`Guide.reportNote(state, inHistory)`) is kept as a longer help line. Drawn as its own state.
3. The page draws Orbit's rail at its full 160 px at the three widths. The compact rail (48 px) only makes the column wider, so the same rules apply (controls back on the text's line from 340 px).

Battery pill (D419): none. The row costs nothing until pressed.

## What the engineer builds (separate story)

1. `components/settings/ReportRow.qml` rewritten as a wrapping row (title, help line, button, mark, guided message); the button in its own small component; colours from `Theme` only.
2. A new constant for the issue address next to `Guide.url` in `components/common/Guide.js`; `Guide.reportNote` keeps the states and gives the new texts; gjs tests updated.
3. The guided message reuses the existing `HelpNote` and `GitHubMark`; it stays until the next press.
4. Offscreen test: no overlap of title, help line, button, mark, label and message at 518, 436 and 360 px, in every state; button 112 x 44 and both mark targets 44 x 44.
5. README *Troubleshooting*, `docs/GUIDE.md#report-a-problem` and the changelog follow.

## Verification

Done, offscreen in WebKitGTK 6.0 through gjs (`gjs tools/check.js "$PWD/index.html"` from `docs/design/report-github/`): 3 themes x light / dark x 3 widths x 10 states, panel and state sheets each time = 180 cases. 0 console error, 0 overlap, 0 overflow, 0 clipped text, button 112 x 44 and mark targets 44 x 44 everywhere, mark 8 px right of the button at 518 and 436 px and under it at 360 px, label inside the column, 0 contrast failure, no em or en dash, no URL / src / href / import.

The "before" sentence is left out of the clipped-text check on purpose: at the 360 px stress width it is squeezed, which is the defect shown.

Not done: no real-size render was looked at by eye in this run (geometry is measured, the rail drawing and the dotted orbit are not eye-checked); HiDPI render; the live press sequence and its transitions (the offscreen view has no frame clock), only end states; Reduce motion checked by reading the CSS, not measured.
