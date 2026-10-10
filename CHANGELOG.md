# Changelog

All notable changes to Orbit Bluetooth are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- **Settings search engine (NAK-260), logic only.** `components/settings/SettingsSearch.js` ranks the settings that fit what is typed: case and accent insensitive, word prefix, one typo forgiven from 5 letters (a letter added, dropped, changed or two swapped), every typed word must match (AND), synonyms through each entry's keywords, label above keyword above help. Each result carries the ranges to highlight in the label and the help; at most 20 results, a query cut at 64 characters and 6 words, no regular expression built from the input. `components/settings/SettingsIndex.js` lists every setting of the current tabs with its keywords; `tests/settingsSearch.test.js` (142 checks) fails when a tab gains or loses a setting the index does not follow. Nothing is wired to a view yet and nothing runs at rest. Cost: a search over the whole index (prepared once) takes well under 1 ms.

### Fixed

- **A wired source's volume tick no longer sounds in the Listen together copies (NAK-251).** The copies of a wired source read the monitor of its sink, and the tick plays in that sink, so it was heard in every copy. Orbit now keeps the small filter in front of a wired source all through the session, even when nothing has to wait (it had one only while the Bluetooth outputs needed the wait), and the copies read that filter's monitor, the sound before the wait: the tick, played in the sink behind the filter, stays out of them. The sound they copy is untouched (no shift, no cut), the filter adds no delay of its own when nothing waits, and the wired wait (D298) is unchanged. Checked on a private PipeWire + WirePlumber with made-up outputs (`tests/graph/wired_tick.py`, the real commands and the real tick helper, each output's input recorded): a tick on the wired source is heard on it and not in the Bluetooth copy, a tick on the copy is heard on the copy and not on the source, the group's general level ticks both, the copied sound still reaches the copy, with and without a 150 ms wait and for a wired copy; the counter-proof (no filter) leaks the tick into the copy. Not listened to on real hardware. Until the filter has come up (a moment after the group forms) the copies still read the sink.

### Changed

- **The volume keys are Orbit's from the first start (NAK-214).** On a fresh install they stayed DMS's own (`dms ipc call audio increment`), which move the default output, so after a change on another device (the headset's buttons, a slider, `wpctl`) they did not follow the last device whose volume changed, until *Use smart steps* was clicked. Now Orbit asks DMS (`dms keybinds`) to bind them at its first start, with no click, on niri only; the DMS step they had is kept as the fallback. It leaves alone a shortcut of your own and does nothing when you gave the keys back: *Give back to DMS*, *Undo* and `volumeKeys off` are remembered (new setting `keysGivenBack`, listed in Privacy), `volumeKeys on` and *Use smart steps* forget it. Uninstalling Orbit still puts DMS's own lines back (with their step), whoever bound the keys, as the sweep reads DMS's listing itself after its wait. The volume scope says it once (*Smart volume keys on · Undo*) instead of offering it. Cost: one `dms keybinds show` at the first start and at most two `set`, nothing at rest. Tests: `tests/qml/volumeKeys.test.qml` (fresh start binds, give-back survives a restart, own shortcut left alone, refusal said) and the give-back run against a fake `dms` in `tests/volume.test.js`. [Guide](docs/GUIDE.md#volume-keys)

### Added

- **Setting: volume keys with a group (NAK-258).** *Sound > Volume keys with a group* chooses what the keys and `dms ipc call orbitBluetooth volume up|down` move while a group plays: *Follow the last change* (default, as before), *Always the group volume* or *Always the last single device* (the member touched last in this group, kept when the group's level was moved after; the group while none was touched or it left). Stored with Orbit's other settings (`groupKeys`), no new file, no timer or process. Tests: `tests/target.test.js` (group changed last, device changed last, no change yet, unknown value) and `tests/qml/volumeTarget.test.qml` (the three choices on a real route, keys moving the right node). [Guide](docs/GUIDE.md#volume-keys-with-a-group)
- **`togetherVolume`: the group's general volume from the command line.** `dms ipc call orbitBluetooth togetherVolume <up|down|0-100|+N|-N>` sets the level the ring around the center moves, with the same smart steps for `up`/`down` and the same scope (the shared PC level, or every output scaled with its gaps kept, nobody past 100 %). The value is validated and capped; with no group it answers *No group is playing* and writes nothing. The group's level logic moved out of `CentreVolume` into the display-free `GroupVolume.qml`, which the ring, the wheel and the command share (`CentreVolume` keeps the wheel over a member); `tests/qml/centre.test.qml` covers the command. Per-action cost: to be measured offscreen. [Guide](docs/GUIDE.md#the-volume-at-the-center)
- **Long press acts as a right click.** A press held 500 ms on a device, a wired output of a group or the ghost planet opens the same menu as a right click (the ghost planet is turned down), with a ring that fills while you hold; it works with touch. Moving past 5 px cancels the hold and the drag works as before, the release after a long press is not a click, and a press while a menu is open still closes it. The timer (30 Hz) exists only during the press. Per-action budget, measured offscreen on 16 cores: holding in a loop 2.50 → 2.57 % of a core (+0.07, within noise, 0.16 % of the machine against a 2 % budget), tapping in a loop 4.79 → 4.71 %. New: `components/scene/Hold.js` (pure, `tests/hold.test.js`) and `HoldRing.qml`; `tests/qml/longPress.test.qml` and the ghost group test cover the pointers. [Guide](docs/GUIDE.md#long-press)
- **A choice of charging beam (first slice).** *Settings → Look → Charging beam* picks how power flows to a charging device: **Pulse** (three capsules of light along a thin rail, no shader) or **Filament** (default). It applies at once, an unknown value is Filament, and `dms ipc call orbitBluetooth beamStyle <pulse|filament|chain|horizon|reset>` tries a style in memory only. Only the active style is built, and nothing while the beam is hidden; with Reduce motion each style is a still frame. The beam now runs from the theme's primary at the host to the charging arc's color at the device (also in the earbuds' trio). [Guide](docs/GUIDE.md#charging-beam)
- **Chain and Horizon charging beams (second slice).** The two other styles of *Settings → Look → Charging beam*. **Chain** is a string of small dots from the host to the device with a lit window running along it (one dashed line and one gradient bar, no item per dot, no shader); **Horizon** is light bent by the device's gravity: a thin arc bending toward the device, six grains falling along it faster and faster, and a thin ring seen almost edge-on round the device with a knot and a short tail (two thin shapes and fifteen small items, no shader). The ring shows flow, never the level, is at most 1.3 times the device wide, and nothing on it is lit above 0.7 alpha, so a charging device never outsizes or outshines the black hole. Several charging devices keep their steady delays, the two buds of the trio 0.4 s apart; under Reduce motion Chain freezes its window halfway along the link and Horizon its grain and knot. The unlit dots of Chain and the ring of Horizon use the theme's text tone (lifted for the night sky, `NightColors.skyText`) at 22 % and 30 %. The four GIFs are now rendered over the sky (they were transparent, so the faint layers dropped out of the palette). Same rules as the other styles: only the active style is built, nothing while the beam is hidden, everything bound to the scene's one 30 Hz clock (no animation). New: `BeamChain.qml`, `BeamHorizon.qml`, `HorizonShape.js` (pure geometry, tested), the clocks of both in `BeamMotion.js`, and `scripts/preview/record.sh beamstyles` for the two GIFs. [Guide](docs/GUIDE.md#charging-beam)
- **The volume keys follow the last member you touched (first slice).** While a Listen together group plays, `volume up|down` (the keys and the command line) moves the member whose own level you set or stepped last, in the scope, on the radar or by the wheel over its planet (also on its card). Touching the group's level, the member leaving or the group ending puts the keys back on the group; a member with no level of its own (it follows this PC) also falls back to the group. The choice is the pure `Target.resolve` (new `Target.js`, `tests/target.test.js`); `AudioRoute` keeps the one `touched` member and owns `ownNode` (moved from `CentreVolume`). Nothing runs in the background: it is one string set on a gesture. [Guide](docs/GUIDE.md#which-level-the-keys-move)
- **The member the keys move is lit in the volume scope (second slice).** Its arc gets a firmer track and a brighter glow; no animation, nothing runs for it. The tick already followed the target (the keys write to that member's own output).
- **Listen together finds the delay between outputs by itself.** When a group forms, and again when an output changes (a member joins, a codec or a profile changes), Orbit reads once, locally, the delay PipeWire reports for each output (`pw-dump`, no network, no new access), then stops. A Bluetooth copy that is quicker than the output you hear now waits for the difference, as the wired ones already did, so two codecs are heard together without `togetherDelay`; `togetherDelay` stays as an override and is added to the automatic wait. An output that reports no delay keeps its own timing and a short note names it (*… reports no delay*, with a link to the guide). The nudge of *Wired delay* still moves the wired copies only. The level is also shared when the output you hear is a wired one: moving the gauge moves the Bluetooth members' PC filters with it. Tests: 70 in `tests/delay.test.js`, `tests/qml/togetherSession.test.qml` extended. Checked on a simulated sound server only, not yet on real hardware; the measured cost per action is the Performance Engineer's.
- **The headset's buttons pick the target of the volume keys, and the target stays.** In a Listen together group, a change of a member's own level that nobody asked Orbit for (a headset with absolute volume reporting its buttons through PipeWire) makes that member the target of the keys, the wheel and `volume up|down`. The target no longer goes back to the group when the volume pop-up closes; it changes when another member or the group's level is touched, or when the group ends. Orbit's own writes (and the keys') are remembered for 500 ms and ignored when they come back, and the first reading of a node is not a change (pure `Target.expect`, `isEcho`, `fromHeadset`; one `HeadsetLevelWatch` per member of a playing group listens to the volume PipeWire already reports: no timer, no process, nothing while no group plays). Headsets without absolute volume are unchanged. [Guide](docs/GUIDE.md#which-level-the-keys-move)
- **Outside a group, the volume keys follow the last level that changed.** The keys, the wheel and `volume up|down` move the device whose own level, or this PC's level, changed last: set in Orbit, moved by the headset's buttons or by anything else on the PC. The target gets the keys even if it does not play the sound and the output you hear never changes; when it disconnects the keys go back to the output you hear, and a change of that output leaves the target as is. A small dot marks the target on its disc only while it is not the output you hear. In a group nothing changes, and a headset without absolute volume behaves as before. Pure `Target.resolveAlone`, `marked`, `settled` (`tests/target.test.js`), `tests/qml/volumeTargetAlone.test.qml` (foreign change, own echo, non-playing target, this PC, disconnect, output change, group). One `HeadsetLevelWatch` per connected device and one for this PC's level listen to what PipeWire already reports: no timer, no process, no new animation; the dot is a static `TargetMark` in a `Loader`. The level Orbit restores when a device's virtual sink appears is booked as an echo. Per-action cost: not yet measured. [Guide](docs/GUIDE.md#outside-a-group)
- **An anonymous diagnostics module (first slice).** `diagnostics/` builds a report you can paste into a GitHub issue without giving anything personal away: versions of Orbit, DMS, Quickshell, Qt, niri and the distribution, the active surfaces, the settings that choose a behaviour, a few counts, the shell's CPU over one second, the last events and the plugin's own journal lines. Events are a code plus fields from an allowlist (numbers, yes/no and listed words; anything else is written `?`), never free text, and every line is cleaned a second time (Bluetooth and network addresses, host names, home paths, the login, e-mails, tokens, device names) before it reaches the 200-entry memory buffer or the journal. Only `console.warn` and `console.error` are used (DMS keeps no other), tagged `[orbit]`. It costs nothing at rest: no timer, no file, no process, no network, one log call is one write into a fixed array; the CPU figure is computed only when a report is asked for, and says it is the whole shell, not Orbit's share. The codes are explained in [docs/DEBUGGING.md](docs/DEBUGGING.md). `tests/diagnostics.test.js` (87 checks) throws made-up names, addresses, paths and tokens at every entry point and fails if any comes out; it checks the allowed setting words against the real settings pages (so the next slice cannot drift) and fails if the module gains a timer, file access or network call.

- **Get the anonymous report (second slice).** *Settings → Orbit → Report a problem → Copy report* collects the report in about two seconds and puts it on the clipboard with `wl-copy --sensitive` (text through standard input, so DMS's clipboard history does not keep it); without `wl-clipboard` it falls back to `dms clipboard copy` and says the history may then hold it, and with neither it tells what to install, with a link to the guide (never Quickshell's own clipboard). `dms ipc call orbitBluetooth diagnostics` starts the report on the first call and hands it over on the next, once. `scripts/diagnose.sh` does both and adds the latest Quickshell crash folder, with the home folder, login, host name, addresses and long tokens replaced; it writes nothing and uses no network. `.github/ISSUE_TEMPLATE/bug.yml` asks for the report. One-line events (`ORB-I020`/`I021` surfaces loaded and unloaded, helper failures and missing tools, adapter, pairing, picture and noise-control faults) now feed the memory buffer: one call is one write, no timer, no disk, no network. The CPU measure still runs only on request. A tool that is not installed (Quickshell sends no signal for it) ends the step instead of hanging it, through `ToolProcess.qml`; `diagnose.sh` replaces the login, host name and home folder as plain text, never as a pattern. New files: `ToolProcess.qml`, `ReportService.qml`, `ReportCopy.qml`, `ReportRow.qml`, `Gather.js` (pure, tested) and `scripts/diagnose.sh` (tested by `tests/diagnose.test.sh`). [Guide](docs/GUIDE.md#report-a-problem)

- **The new-headphones pop-up now opens on the nearest PC first.** When a candidate headset shows up during a discovery, Orbit reads its signal strength once from BlueZ (`busctl get-property … Device1 RSSI`, a command array with the object path checked by `Address.js`; Quickshell 0.3.1 does not expose it) and applies the rule of `NearestFilter.js`: strong opens at once, weaker waits (up to 6 s), below -75 dBm this PC stays quiet. When the wait ends the signal is read again: gone while the adapter still discovers (the headset left or connected to another PC), under the floor, or no longer a candidate means no sheet. A sleeping screen waits a little longer. No reading, a missing or failing `busctl` (the read gives up after 2 s), or a discovery that already ended keeps today's behavior: the sheet opens at once. Nothing runs at rest: no timer, no process, until a new device appears. The thresholds (-45 / -75 dBm, 6 s) are starting points **to tune with real hardware**. New: `Signal.js` (command and parsing), `SignalRead.qml` (one `busctl` at a time, built on the kit's `ToolProcess` so a missing `busctl` still answers), tests with a fake `busctl` (`tests/signal.test.js`), the real reader (`tests/qml/signalRead.test.qml`: missing program, failure, two reads in a row) and the whole pop-up flow (`tests/qml/nearestWindow.test.qml`). The study and what was not measured are in [docs/nearest-pc-study.md](docs/nearest-pc-study.md).

### Changed

- **Volume ticks are live, on the right output and without crackle.** A fast burst of steps no longer plays a run of ticks late: a change that crosses a step plays one tick now, a tick within 25 ms of the last is dropped, and each new tick replaces the one still sounding in the output's player (`tick/orbit_tick.py`), so the sound stops with your hand. Every tick fades in (1.5 ms) and out (5 ms; 2 ms when replaced), and its gain falls as the output's level rises above 60 % (`Volume.tickGain`: 0.6 of its size at 100 %), so it cannot clip; at 0 % nothing starts, and an output that vanishes mid-burst ends its player quietly. A group member's own level ticks that member only; the group's general level still ticks every member, each at the gain of its own level. The pacing timer is gone: nothing runs between two changes. No new setting. **In Listen together a tick no longer leaks into the copies:** they read the monitor of the source's PC-level filter, so a tick played through that filter was heard on the other outputs too. The tick helper now links its stream straight to the device's own sink (autoconnect off, `pw-link`), round the filter, so a member's tick sounds on that member only, the source included; the group's general level still ticks every member. Checked on a private PipeWire + WirePlumber: the old route put the tick stream in the filter, the new one links it to the sink alone (not heard with a signal; the owner's session was not touched). Round the filter the tick takes the gain the filter would have given it, the level cubed (Quickshell and DMS show the cubic volume, the filter scales by its cube), and no player starts for a tick under 1 % of its size. Not benchmarked (the owner waived it); the helper was rendered against a stand-in `pw-cat` (40 ticks in 1 s: peak 0.18 of full scale, stops 4 ms after the last tick).
- **The volume scope moves at once (NAK-210).** It no longer waits for cava: while the scope shows, PipeWire's own peak meter (the existing fallback) draws the cloud from the first frame, and cava's first spectrum frame takes over (16 bands a side instead of one) without a gap; a late peak reading never overwrites cava. During a burst of volume keys, cava still waits for the keys to stop (D272, the burst is no worse), but the pop-up now shows a live picture meanwhile instead of an empty scope for 0.7 s; a cava already running is not stopped by a new key press. The card starts cava at once and shows the peak meter until it speaks. Nothing runs when the scope is hidden or with Reduce motion. New in `ScopeFeed.qml`: `steady` (cava may start); `TwoLevels.qml` forwards it and `VolumeOverlay.qml` sets it from its settle timer. `tests/qml/scopeFeed.test.qml` covers the hand-over, the hold during a burst, the stop when hidden and the missing-cava case. `pactl` and `pw-dump` for the audio facts wait for the end of a burst too (`looking`, `tests/qml/twoLevelsLooking.test.qml`). Cost: the peak meter runs for the first moments of each display and during bursts; measured offscreen (16 cores), a burst went from 0.14 % to 0.71 % of one core and a shown scope from 0.14 % to 0.79 % (about +0.04 % of the machine each, far under the 2 % per-action budget); hidden stays at about 0.
- **Filament is three interleaved strands (D376).** The beam's default style is now the design's three thin sine strands (swing 3 / 5 / 7 px, width 1.6 / 1 / 0.8 px, alpha 0.95 / 0.5 / 0.3, one cycle per 4 s, pinned at both ends) instead of the 11-line spindle: still `shaders/beam.frag` (recompiled), same colors (the host's primary to the charging arc's), same still frame under Reduce motion. A strand's width is measured across the curve, so a steep one is as thin as a flat one. The captures of the charging beam (`beam.gif`, `charging.png`, `charging-marker.png`, `earbuds-dock.png`) are redrawn.
- **One color for the charge.** The energy beam (and the flare where it leaves the host) and the lightning bolt and beam of the earbuds' case view now use the charging arc's color (`NightColors.charging`; on the cards, which are paper, the theme's own tone) instead of the theme's primary.
- **Hiding, polished.** A wired member of a group no longer offers *Hide* in its menu (it could only explain that a member plays on); its menu is *Disconnect*, which leaves the group and stays plugged in. A Bluetooth member keeps *Hide*, as before. In *Create a group…*, the *Hidden* section now opens by itself the first time something is hidden (or when the list opens on outputs hidden earlier), so you see where it went; after that Orbit keeps whatever you chose, open or folded, from one opening to the next (one saved setting, `hiddenSectionOpen`, written only when you toggle the section or when it opens by itself; bringing the last output back does not fold it). Pure rules in `Hidden.js` (`sectionOpen`, `opensAfterHide`), tested in `tests/hidden.test.js`, `tests/menuEntries.test.js` and the render tests `hideMenu` and `wiredMembers`. Checked off screen (OpenGL, made-up devices): the group chooser with two hidden outputs, and the black hole with the group in front and behind. Nothing runs at rest: no timer, no animation. [Guide](docs/GUIDE.md#hiding-devices-the-black-hole)
- **The volume tick plays at every 1 % by default.** One tick per step crossed, whichever way the level moves (card, pop-up, radar, keys, wheel, drag, `dms ipc`). A jump of several steps is a run of ticks paced about 40 a second (one every 25 ms), at most 12 waiting, so a sweep of the dial is heard as a run for 300 ms at most, never a burst at once; the pacing timer runs only while ticks wait. A tick is no longer a `pw-play` of its own (a process, a connection and a stream each, at least 1.7 ms of CPU per launch, measured by the bench): one small Python helper per output (`tick/orbit_tick.py`, standard library only) holds one PipeWire stream and mixes every tick sent to it, so ticks that overlap are all heard. It starts with the first tick, closes after 2 s without one, and dies with the shell (its input closes with it). Measured offscreen with the real helper and `pw-cat` on a private PipeWire server: a 1 % sweep at 40 a second into 4 outputs costs at most 5 % of one core in a second (0.3 % of a 16-core machine, 0.46 core·s over 19 s; 2 % of a core into one output), a 5 % step once a second at most 2 %, an open but silent player 0, the start about 0.01 core·s, and the helper and `pw-cat` are gone within 0.2 s of their input closing. Overlapping ticks add up exactly, without clipping at 40 a second. New option **Scanning → Tick every** (*1 %* or *5 %*; *5 %* is the former behaviour, minus its 45 ms limit). [Guide](docs/GUIDE.md#the-two-volumes)
- **The group's gauge takes its color from its angle.** The gradient along the level is now conical, turning with the arc from the speaker at its start to its end, instead of linear left to right: a place on the arc has the color of its position, so the thumb's color tells the level wherever the arc bends (the old one gave the whole left side one blue). It is Qt's own gradient drawn by the curve renderer, with no shader of ours, and the gauge stays static art: 0 frames at rest and the same CPU during a sweep as the linear one (measured off screen, OpenGL). Its colors are the night sky's own (`NightColors`), and a render test (`tests/qml/gaugeColors.test.qml`) checks that the colors run from the start color to the end color, one way and with no jump along the band (it fails on the first, mirrored mapping). [Guide](docs/GUIDE.md#the-volume-at-the-center)
- **A night sky behind the radar's dials.** The radar's card now shows a faint sky through its glass: two soft nebulae in the group's colors, a few stars and the ring the small dials orbit on, dashed and brightest along their arc, fainter all the way round. Everything readable keeps a clearing (the dials, their names, the actions), so the sky never sits behind text. The same sky at every opening, in the card's own ink in both themes. It is one canvas painted when the radar opens and again only if the card is resized, the theme or the group's colors change, or the dials' places move (not when you pick another dial, change a level or mute); no timer and no animation, so an open radar costs what it did. A paint takes about 1 ms here (360 px card, four small dials). New files: `RadarSky.qml` (the canvas) and `RadarSky.js` (pure, tested). [Guide](docs/GUIDE.md#the-volume-radar)
- **The radar's dials float, without moving.** Every dial, the big one included, now sits a little off its ideal place, unevenly and for good: the small ones a few pixels in or out of the dashed ring (alternately, by up to 1.8 % of the radar's width), the big one 0.8 % at most, in any direction. It reads as weightlessness and costs nothing: no animation, no timer, nothing runs. The offset belongs to a place's rank, not to a device, so choosing another dial moves nobody's place and the sky is not repainted. Targets, dragging a ring and the names are unchanged: where two names would come closer than they did, the offset is halved, then dropped. The sky's clearings follow the dials where they really are. The small seeded generator now has its own file, `RadarRandom.js`, shared by the sky and the layout.
- **Robustness proved by a test, not assumed.** Two offscreen tests play the hard cases: `tests/qml/robustness.test.qml` against the components (a headset that disconnects in the middle of playing and leaves the list, even destroyed while the list still holds it, an output that vanishes, comes back or has an empty name, a UPower battery that disappears, a helper that dies while a command waits or while the shell stops) and `tests/qml/robustViews.test.qml` against the real scene, with the headset's detail card open, then the group's volume radar open, while the headset disconnects, is destroyed and drops out of the list, while the group ends under the radar, and while PipeWire's default output goes to the headset, vanishes, returns and has no name (read by the real `AudioRoute`, with the headset playing). `tests/qml/run.sh` now fails any QML test that prints a warning or a TypeError. The only warning found is the one fixed below; nothing else warned, so **no other guard was added**: a guard is only worth having where a test shows the failure, and the seven days of the DMS journal agree. The connection-time, battery-log and UPower bookkeeping moved out of the daemon into `components/common/DeviceLog.qml` (same bindings, no new timer) so a test can run it without the daemon's other parts. Idea from @tahayerd (#6).

- `OrbitScene.qml` is split by role (467 → 374 lines): its own state (inputs,
  geometry, clocks, black hole, preferences) moves to its base type
  `OrbitState.qml` (108 lines), which never reads a part of the scene; a test
  checks that rule. No visible change.
- `DeviceBody.qml` is split by role (408 → 245 lines): what the body knows
  about its device moves to its base type `BodyState.qml` (75 lines, reads no
  part of the body nor its motion, checked by the same test) and the one-shot
  motions (focus, pop, shake, swallow, tether pulse) to `BodyMotion.qml`
  (141 lines). No visible change; offscreen A/B against the base before the
  split (16 cores, 7 to 8 passes per side): view at rest 2.29 % → 2.36 % of a
  core, a card opened and closed every 1.5 s 4.79 % → 4.79 %, the volume radar
  held open 4.93 % → 4.96 %, all under the noise.
- **A no to the best learned group is a no.** When you turn down the group Orbit learned you listen to most, the ghost planet no longer falls back on the next learned group or on a pair: it suggests nothing (until the shell restarts, or the devices that are there change so that the best group is another one). A refusal of a lesser group leaves the best one suggested. [Guide](docs/GUIDE.md#suggested-groups)
- **A session that lasts until the shell stops is counted.** A Listen together session still going when the shell restarts or reloads now counts as a use of its group (if it lasted a minute), where it used to be lost because only the end of a session was recorded. Still no timer: one count, at the stop. A shell killed outright cannot count it. [Guide](docs/GUIDE.md#learn-my-groups)
- **A lighter download.** The README and guide screenshots are recompressed losslessly (oxipng, gifsicle): same names, sizes, frames and timing, every visible pixel identical. `screenshots/` 6.86 MB → 4.98 MB, a shallow clone 16.8 MB → 13.4 MB. The published history is kept, so a full clone still holds the older images.

### Added

- **A bolt on the charging arc in Blue and Cyan.** Where the theme has no color to tell the charge from the primary (the stock Blue and Cyan, light and dark), a small bolt rides the head of the level arc while the device charges, in place of a shifted, off-theme hue. It is static: no timer, no animation. Checked by `tests/qml/chargeColors.test.qml` (contrast of the charge and of the marker on the night sky is at least 3:1 in the four stock themes) and rendered by `scripts/preview/charge.qml`.

### Fixed

- **A drop on a copy that overlaps its source lands on the copy.** Dropping a device where a copy is drawn over the source used to go to whichever centre was nearer, often the source underneath. The drop now goes to the body drawn on top under the pointer (the copy), and keeps the nearest-centre rule when the pointer is off every disc. It only runs while a device is being dragged, so nothing changes at rest. Covered by `tests/scene.test.js` (red before the fix, green after).
- **A row of the card's thin volume line no longer warns when a group ends.** A row still on screen read a colour the shrunken palette no longer had (`Unable to assign [undefined] to QColor`, `VolumeStrip.qml`); it now falls back to this PC's colour. Removing that fallback makes `tests/qml/views.test.qml` fail.

### Tests

- `tests/qml/gaugePointer.test.qml` drives the real gauge with synthetic mouse events off screen (QtTest): hover writes the level out only on the band, a press lands where the pointer is, a drag follows it both ways and holds at the end it came from across the gap, a release ends the drag, a press in the gap does nothing, and the speaker mutes without dragging to zero. It fails when the grab area stops excluding the gap. The gauge has still not been tried with a physical pointer in the real shell.
- `tests/qml/robustness.test.qml` tests components against hard cases (disconnect, destruction, empty values).
- `tests/qml/robustViews.test.qml` tests the real scene with the detail card and radar open while devices disconnect and go away.

### Decided
- **No salt on the learned groups' hashes**, and the 30-day half-life and one-minute threshold are not re-tuned for now. Nothing changes in what is stored, so the README's Privacy section is unchanged.

## 1.14.0 - 2026-10-08

- **The volume radar opens in the same card as a device's.** It is now a narrow card (at most 360 px, centred, glued to the bottom) with the detail card's own frame, its rise (480 ms) and its fade (300 ms), the name of the big dial and what it is under the picture, and round back and ✕ buttons in the corners. A Bluetooth member's planet flies up to the card and grows on its top edge exactly as it does for a device's detail card; the group and a wired output have no planet to fly, so the card carries their picture there with the same pop. Everything that steps back when a card is up (the other planets, their names and tethers, the hint, the scan chip, the offer card, the backdrop, the host core) now does so for the radar too, through one state. The actions sit in two rows of two so *Disconnect*, *Remove from group*, *Hide* and *Details* all fit. The hidden list shares the rise, so it now moves at the same speed as the other cards (it was a little quicker). The big dial's name is only in the header now, and the small dials sit a little further out around a slightly smaller big one so their names no longer touch its ring.

### Added

- **Orbit's tick only.** When you change a level in Orbit (the card, the pop-up, the radar, the volume keys you gave to Orbit), DMS's own *Volume Changed* sound now waits, so only Orbit's tick plays instead of two sounds at once. It waits only from the moment Orbit writes a level until about 0.4 second after the last one: DMS's own sliders and keys keep their sound. On by default, in **Scanning → Orbit's tick only** (shown while **Volume tick** is on, with the guide's mark). Like the volume OSD it is held in memory only and let go of around each of DMS's saves, so nothing reaches DMS's files; nothing runs when no level moves. `DmsOsdOff` became `DmsQuiet`. [Guide](docs/GUIDE.md#orbits-tick-only)
- **The volume tick plays where you turn a level.** The soft tick of each 5 % step is no longer the detail card's alone: it also plays when you change a level in the volume scope (the Dank Island or the pop-up), with the volume keys, and in the radar. It plays **in the output whose own level you change**, never in the whole group; only the **group's** level (the ring at the center, the group's arc, the radar's group dial) plays it in **every** output at once, four at most. Same *Volume tick* option and sound as before (*Sound* tab); nothing runs between two ticks. [Guide](docs/GUIDE.md#the-two-volumes)
- **The volume radar.** A tap on a group's icons, or a click on one of its members (Bluetooth or wired), opens a radar: the level you clicked is a big dial in the middle (the group's, or the member's own), every other level stays around it as a small dial, one tap from being the big one. Drag the ring to set a level, turn the wheel to step it, press the speaker to mute it. Under the big dial: *Disconnect*, *Remove from group*, *Hide* and *Details* for a Bluetooth member; *Disconnect* (it leaves the group and stays plugged in) and *Hide* for a wired one; *Add a device…* and *Stop group* for the group. Escape or the ✕ closes it. Nothing exists while it is closed.
- **The radar moves, for almost nothing.** It fades and grows in while the big dial's arc sweeps up to its level and the small dials pop in one after the other; tapping a small dial makes the dials glide to their new places; a level glides to its new value, so a drag feels smooth; muting sends a ring out of the speaker. All of it runs on **one clock of about 60 Hz that runs only while something moves**: at rest nothing runs, and while the radar is closed nothing of it exists. With *Reduce motion* everything jumps straight to its place.
- **The volume pop-up shows on the screen you are on.** With two or more screens, a volume change used to pop up on every one of them. Now only the screen with the focus shows it, inside its Dank Island or as a pop-up; one left open on the screen you just left closes. *Settings → Sound → Screens* chooses: *Where I am* (default) or *Every screen*. If the focused screen is not one where Orbit can show the pop-up, it shows everywhere rather than nowhere.
- **More about what plays.** The unfolded audio details now also say the Bluetooth **profile** (A2DP or HSP/HFP), the codec's **bit rate** (LDAC's 990, 660 or 330 kbps, or its range on *Auto*; aptX and aptX HD's fixed rates; nothing for SBC, AAC and others, whose rate is not published), the **latency** PipeWire reports, and the **quantum** (the audio buffer, for an output that is playing). Each has its two switches in *Settings → Sound → Audio details* (on the line, more info). The info button next to the line unfolds the details in place. The bit rate and latency are read with `pw-dump`, the quantum with `pw-top`, only while the details are unfolded (or the fact is on the line), never in the background; the card grows to fit. New files: `Codecs.js`, `AudioGraph.js` (pure, tested) and `AudioGraph.qml` (the two readers).
- **Listen together.** The same sound on two, three or four Bluetooth outputs at once (the headset and the receiver, two speakers...). Drag one connected audio device onto another, then drag more onto any device already in the group. Right-click a member for **Remove from group** (the group is stopped from its radar); a device that disconnects leaves by itself and the group ends when fewer than two remain. Orbit runs one passive `pw-loopback` per output beyond the first, attached to the shell: with no sound playing it holds nothing open, so every output goes idle and sleeps as before, and the copies disappear with the shell, even after a crash. Orbit never changes your default output, never writes DMS's or WirePlumber's settings and never touches a device's Bluetooth link. [Guide](docs/GUIDE.md#listen-together)
- **One arc per output.** While a group listens, the two volumes' outer half circle shows the outputs' own levels: with two, it is cut at the top (left half `primary`, right half `secondary`, each lit from its bottom corner toward the top, meeting at 100 %); with three or four, it splits into equal arcs, each lit from its bottom end toward the top, with its own theme color, moon, icon and name, and its own sector of the cloud of points. Two colors that look alike are turned apart so no two arcs read as one. The inner half circle stays shared: this PC's level. The folded strip of the menus shows one thin bar per output.
- **This PC's level reaches every output.** Moving it moves it for each output that has Orbit's separate PC volume, and a joining output is set to the group's level. Outputs without such a filter keep their own level (Orbit never writes the volume PipeWire remembers for a device).
- **Multipoint headsets keep working.** A member whose output is handed to your phone stays a member (no message, no flapping), plays again when it returns, and is dropped only on a real Bluetooth disconnection or when you take it out. Orbit opens no stream, silence or keep-alive toward any output. [Guide](docs/GUIDE.md#works-with-multipoint-headsets)
- **`dms ipc call orbitBluetooth`**: `together "<address> <address>..."` (one quoted argument, spaces or commas, 2 to 4 connected audio devices), `togetherAdd <address>`, `togetherRemove <address>`, `togetherDelay <address> <ms>` (hold one output back, 0 to 1000 ms, this session only), `togetherStatus` (JSON) and `separate`. Every argument is validated and capped, and a refusal says why.
- A short note, with the GitHub mark linking to the guide, says why a device cannot join (not connected, no sound output yet, on its call profile, the same device twice, a fifth device, nobody listening yet).
- **Taking the headset off does not pause a group.** While the headset listens together with other outputs, the music keeps playing for the others when you take it off, and putting it back resumes nothing.
- **Pause when you take the headset off** (Sony headsets with a wearing sensor, on by default). When the headset says both sides are off, what plays on it pauses; when it is worn again, Orbit resumes only the players it paused itself and that are still paused. It never starts music, ignores a player that plays elsewhere, and treats the first reading after a connection as a reference that pauses nothing. To hear it, Orbit keeps one control connection open to such a headset while it is connected (no polling, no timer; the headset reports by itself). The matching of a player to the headset is strict (names of the MPRIS player against names of the PipeWire streams that reach the headset), so it does nothing rather than pause the wrong player. Orbit never opens an audio stream or changes the output, so multipoint is untouched. Switch: *Settings → Headphones → Pause when you take the headset off*; check it with `dms ipc call orbitBluetooth wearStatus`. Other brands are not supported yet. The packets come from the MIT-licensed SonyHeadphonesClient and have not been confirmed on a headset of Orbit's own, see [the guide](docs/GUIDE.md#pause-when-you-take-the-headset-off).
- **How long a conversation lasts** (Sony): a *Conversation ends* row (*Short*, *Standard*, *Long*, *Never*) in the headset's card, shown once the headset has said what it is set to, and `dms ipc call orbitBluetooth chatEnds standard`. The sensitivity of Speak-to-Chat is kept. Not yet confirmed on a headset of Orbit's own, see [the guide](docs/GUIDE.md#how-long-a-conversation-lasts).
- **The listening source takes the center, and this computer circles it like a sun.** While a group listens, the source (the output you hear) glides to the middle of the view in under a second, as big as this computer's core was, and the other outputs orbit it, one turn in about 25 s, equally spaced. The view follows the group: this computer, with its ring of connected devices and its belt of other devices, revolves around it (one turn in 60 s), smaller and behind on the far side of its path, bigger and in front on the near side, so the whole thing reads as a solar system. The devices that are not in the group keep orbiting this computer, wherever it is. The stars drift a little the way the camera went; the group is said by its members' icons under the center (no name), and the names of the devices around the sun fade while a group has the center (hover or drag one to read it). Soft beams join the source to each output and a small pulse travels along them only while sound plays. The sun slows to a stop while you drag a device and sets off again after. Click this computer to bring it back to the middle (the group steps back), click the group to take the center again. It works in the Control Center, the bar pop-out and the desktop widget, and can be turned off in **Orbit → The listening source takes the center**. [Guide](docs/GUIDE.md#the-source-at-the-center)
- **A general volume gauge around the center planet.** A gauge around the source sets the group's level: an open 270-degree arc whose gap is at the bottom (where the members' icons sit), 5 px thick with round ends over a faint track, a soft gradient along the level, a glow where the level ends, faint marks every 10 % (longer at 0, 50 and 100 %) that light as the level passes them, and a round thumb with a halo. Drag along the band, click the track to jump there, or turn the wheel over it or over the planet; the level is held at both ends and never wraps. With separate PC volume it is this PC's level; otherwise every output's own level is scaled by the same ratio, so the gaps stay (50 % to 80 % takes 40 % to 64 % and 30 % to 48 %), and nobody passes 100 %. Scroll over one output to set its own level; one with none says so in a short note with a link to the guide. [Guide](docs/GUIDE.md#the-volume-at-the-center)
- Dropping a connected audio device on the center planet joins the group, and dropping one that is not connected says to connect it first.
- **An invitation while you carry a device.** Carrying a connected audio device makes a soft halo breathe around each device it could listen together with, and a thread of light run toward the nearest, stronger as they come closer and whole once the pointer is over it; the hint says what dropping does. It is made only while such a device is carried (nothing runs at rest) and stands still with Reduce motion.
- **Pulling a device out of the group makes it leave the group**, not disconnect. The hint reads *Release to leave the group*; the device stays connected and plays alone again.
- **A wired member of a group can be pulled out by hand like a Bluetooth one.** Drag it past 5 px: the hint says *Release to leave the group* and it leaves when you let go; a plain click still opens its menu, so a group made only of wired outputs stays manageable. [Guide](docs/GUIDE.md#pull-a-wired-output-out-of-the-group)
- **A note when two outputs share one Bluetooth radio.** The first time two outputs of the adapter play at once in a session (a Listen together with a LDAC headset and a receiver, say), a short note under the center says they share one radio and that the sound may lose quality or cut, with the GitHub mark linking to *Two outputs, one radio*. Once per pair, only while the orbit is open, nothing stored, no setting changed: Orbit never lowers a device's quality to make two fit.
- **A member of a group cannot be hidden.** Dragging it to the black hole, *Hide* in its menu or the eye of the group chooser would leave it playing out of sight, so a short note, with the GitHub mark linking to the guide, says to pull it out of the group first. Another note says so when the list of hidden devices is full.
- **Hide the outputs you never use, from the group menu.** In *Create a group…* every row has an eye (under the pointer or the keyboard cursor; <kbd>H</kbd> does the same), and a row can be dragged onto the black hole, with a chip that follows the pointer while the hole lights up and shows an eye. Hidden outputs wait in a folded *Hidden* section (Right and Left open and fold it) where an eye brings each one back. Wired outputs can be hidden too: they join the same store as the Bluetooth devices (at most 64), so the hole's *Hidden · N* counter and its card count them, and *Show* brings them back. [Guide](docs/GUIDE.md#hiding-devices-the-black-hole)
- **The center is seen almost edge-on, in two views.** While a group listens, the scene is seen about 15° above the plane of the orbits and every size follows its distance (near is big, far is small and darker). In **this computer's view** the group is one planet of its ring, smaller, passing in front of and behind it; in **the group's view** the group is in front, big and sharp, and this computer sits far behind it, small, dark and blurred. A click on the group or on this computer picks the view, a click in the empty sky steps one view back (a card first), and a window that closes and opens again reopens on the last view. [Guide](docs/GUIDE.md#the-source-at-the-center)
- **Depth of field.** While a group has the center, the sky falls out of focus: what is far is darker and blurrier, the stars and the veil most of all. The blur radius is a twelfth of the scene's short side (37 px in the bar pop-out) and no longer averages the sky to flat black: a soft glow of the accent color lies behind the group (a deep atmosphere), the extra dimming is only 20 %, and the focus dimming over a solid sky is softer while a group has the center. On the desktop widget, where the wallpaper cannot be blurred, a frosted veil of the sky's color lies between this computer's system (its planets, their names, its orbits) and the group, and this computer's orbits fade to half. All of it follows the camera (back to normal on this computer's view), is drawn once and never animated, so it costs nothing between two changes of view. Measured off-screen over 6 s: 366 frames on a solid sky and 186 on the desktop widget, before and after, so no loop was added.
- **Easier to aim at.** The drop zone of a device is twice the disc you see (60 px at least) and a device always has an invisible click zone of 28 px at least, even when it is drawn small by distance.
- **A copy that passes behind the source is a dashed outline, still clickable.** In a Listen together group, a copy on the far half of its turn is drawn over the source as a **dashed outline**: its disc is gone and only its picture stays, a little softer, so the source shows through it and the copy still reads as a device. It fills in as it comes round to the near side (it is half way when level with the source) and answers a click or a wheel turn at once, without waiting for its turn round. The same for wired members, with a rounded outline. The cables and beams stay under every member. The outline is drawn once and only faded: nothing is repainted, and a copy that is whole has none. [Guide](docs/GUIDE.md#the-source-at-the-center)
- **The copies orbit 40 % farther while the group has the center, along a light dashed trajectory.** The copies of a group turn at 1.4 times the distance of a tight ring while it has the center, so there is more room around the source and its volume gauge; when the group steps back onto this computer's ring they come back to that tight ring (a wide orbit would cross the host and its neighbours there), with the group's own half-second move so nothing pops, and the orbit widens again when the group returns. A faint dashed ellipse draws the path they follow, like the rings of this computer's system: its far half passes behind the source, its near half in front of it but under every copy, and it is paler on the far side. It exists only while a group has the center, is laid out once and only carried and scaled with the group (no timer, no animation, nothing repainted; it is laid out again only while the group steps back or returns, as the orbit tightens or widens), and takes its color from the theme (a mid-tone on a light theme, so it reads over the white source). In a small scene the copies shrink a little (12 px at the least) so the wider orbit still fits. [Guide](docs/GUIDE.md#the-source-at-the-center)
- **The gauge says it is the volume.** It starts at a **speaker** (the arc's start, bottom left) that follows the level and is crossed out when muted; pressing it **mutes the whole group** (and a second press brings the level back), and a muted gauge is grey. The percentage (or *Muted*) is written in a small chip beside the thumb while the pointer is on the gauge and for 1.8 s after every change, whoever makes it (drag, wheel, volume key). Nothing runs at rest: one short timer starts with a change and stops itself. [Guide](docs/GUIDE.md#the-volume-at-the-center)
- **A group is said by its members' icons, never by a name.** Under the group (in the group's view and in this computer's view) and under the suggested ghost group, one round disc per member overlaps the next like the bar pill's stack, each wearing the glyph the member has everywhere else (a device's own, the picture of a wired output's connection). The names, and what a click does on the ghost, only appear in a small tip while the pointer is on it. In this computer's view the icons go over the group when it is on the far side of the host's ring, and clear the group's gauge and the host's disc. [Guide](docs/GUIDE.md#group-icons)
- **Wired outputs can listen together.** A USB interface, an HDMI screen or the headphone jack takes part next to Bluetooth outputs. A wired output answers in a few milliseconds and a Bluetooth one later, so Orbit holds the wired output back by what PipeWire says the Bluetooth ones add (a Bluetooth output is never delayed); when the wired output is the one you hear, a small filter of its own does it for as long as the group listens, and it goes away with the group. [Guide](docs/GUIDE.md#wired-outputs)
- **Wired delay.** *Settings → Orbit → Wired delay* nudges that automatic wait from −100 to +100 ms in 5 ms steps (0 by default, never moves by itself, one click to reset, a link to the guide); it is saved once, when you let go of the slider. [Guide](docs/GUIDE.md#wired-delay)
- **`dms ipc call orbitBluetooth`**: `togetherOutputs` (the wired outputs Listen together can take, as JSON, read when asked), `wiredDelay up | down | +N | -N | N | reset | status`, and `togetherStatus` now also says each member's measured latency (`latenciesMs`). Every argument is validated and capped, and an answer never repeats what it was given.
- **Create a group from the menu.** Right-click a connected output and choose **Create a group…** (**Add to the group…** when a group already listens): a checklist opens on the sky with the wired outputs that are plugged in and the Bluetooth ones that are connected, the device you clicked already ticked, four at most. A row that cannot be ticked (*No sound yet*, *Call mode*, *In the group*, *Group is full*) says why when clicked, with the GitHub mark linking to the guide, and the list stays open; the button says *Tick another output* instead of doing nothing. Keys: ↑ / ↓, Space, Enter, Escape; a long list scrolls with a mark where you are; *Reduce motion* is respected. The wired outputs are read once, when the list opens, with `pactl --format=json list sinks`; nothing runs while it is closed. [Guide](docs/GUIDE.md#create-a-group-from-the-menu)
- **Suggested groups.** When the sound goes to a wired output while a Bluetooth device is connected, or the other way round, a dotted ghost planet on this computer's ring proposes a Listen together group, as big as the real one would be, with the icons of the outputs it would put together (hover it for the names and what a click does). It proposes the group you listen to most, else a pair, never every output at once. Click it to start the group; right-click it (or the small ✕) to turn it down: the same set is not suggested again until the shell restarts (kept in memory only), and ending a group yourself counts as turning the same suggestion down. It never shows during a group, with a headset in call mode or with *The listening source takes the center* off, has no timer of its own and reads the plugged outputs only while it can appear. [Guide](docs/GUIDE.md#suggested-groups)
- **The suggested group follows what you listen to.** Orbit remembers each group that stayed the same for a minute of a Listen together session, and when all its members are there it suggests exactly that group; taking a member out right after making a group teaches Orbit the group without it. With nothing learned yet, or when no learned group is complete, it suggests a **pair**: the output in use and its most used partner (else the first one). A bigger group is built in the group chooser. The ghost ignores the outputs you hid in the black hole, Bluetooth or wired. [Guide](docs/GUIDE.md#learn-my-groups)
- **Learn my groups** (Orbit tab, on by default) and **Forget what Orbit learned**. What is kept is only short hashes of the outputs of a group, how many times it was used and the day of its last use (no clock time), at most 8 groups, in Orbit's own settings: no name, no address, nothing leaves the computer. Switching it off erases the memory at once and nothing is recorded while it is off; uninstalling Orbit erases it with the rest. [Guide](docs/GUIDE.md#forget-what-orbit-learned)
- Learning costs nothing at rest: the time is read when a group changes or ends (no timer), and the plugged outputs are looked up (`pactl`) when the sound goes to a wired output only if a learned group holds an output that is not already known.
- **Wired outputs look different in a group.** A wired member is a **rounded square** with the picto of its kind (USB, HDMI, analog jack, other) among the round Bluetooth planets; its name shows under the pointer. A thin straight **cable** joins it to the source and tightens in 0.4 s when it joins (taut at once with *Reduce motion*; a small pulse runs along it only while sound plays). A wired source takes the center as a rounded square the size of this computer's core. Right-click a square for *Disconnect* (it leaves the group, still plugged in) and *Hide* (which only explains); scroll over it for its own level (over a wired source, the group's general level). Nothing runs at rest and no setting was added. [Guide](docs/GUIDE.md#wired-outputs-in-the-group)
- Guided notes for wired outputs, in their own words and with a link to the guide: an output that is not plugged in when it is added, one that is unplugged while it plays (still named, from memory, for as long as it is a member), and the output the sound comes from. In the volume scope a wired output is drawn with the picture of its connection and its own name, never a Bluetooth picture.

### Fixed

- **The *Learn my groups* settings row no longer spills over its neighbours.** Its description wraps onto several lines, and the row was only as tall as the switch beside it, so the text ran over the *Wired delay* slider above and over the *groups remembered* line and the *Forget what Orbit learned* button under it. The row now takes the text's height (tested at the width of a narrow settings page).
- **An open radar on a Bluetooth device no longer keeps the scene stepping at 60 Hz.** The flown planet counted as a detail card for the effects clock, so the scene never settled (offscreen, about 8.6 % of a core against 4.5 % on the previous release, now 4–5 %). Only the device's own detail card keeps that clock running.
- **A wired output's cable follows it when you pull it out of the group.** Dragging a wired member (the rounded square) away used to leave its cable behind, pointing at the place it came from; the cable's end now follows the pointer for the whole drag and goes back on release. It is read from the drag state, so nothing runs at rest.
- **The headset's own volume is found again on BlueZ 5.87.** That version lists the audio link directly under the device (`…/fd0`) instead of under a remote endpoint (`…/sep1/fd0`); Orbit did not see it, took the headset for one without its own volume and started no PC-level filter, so the two volumes collapsed into one. Both forms are read now.
- **The audiophile details no longer open by themselves.** The info line under the volume pop-up stays folded each time the pop-up opens; what you unfolded last time is not kept.
- **No volume pill left behind after a screenshot.** A screenshot makes DMS fold the Dank Island straight away; Orbit's face went with it, but DMS's own compact volume pill (speaker, blue slider and percentage, which looks like DMS's OSD) was left up with no timer to remove it, until the next click. Orbit now sends the island home when DMS folds it behind the face. DMS's own volume OSD was off all along: nothing about it changed.
- Switching *Noise control* off now closes the headset sessions that were open (a handler listened to a property that never changes).
- A helper that cannot start (no Python 3, a crash at once) no longer risks being started again in a loop: a session reopens by itself only after one that reached a ready headset.
- **Back on this computer's view, the sky is sharp again.** While a Listen together has the center, the sky behind the orbit falls out of focus (darker and blurred); stepping back to this computer's view kept that blur and darkness although the camera was no longer on the group. The depth of field now follows how far the camera is on the group, so only a view on the group is out of focus (`tests/qml/skyDepth.test.qml` checks it, and fails with the old rule).
- **A member's menu no longer offers to add it to its own group.** On the menu of a device already in the group the entry read **Add to the group…**, and the list then answered *Tick another output*; a member's menu now has no group entry at all (see the short member menu below), and the page that adds a device is opened from the group itself, with nothing ticked. A device that is not in the group keeps **Add to the group…**.
- **Escape closes the device menu on the desktop widget.** A desktop layer gets no keyboard by default, so Escape never reached the menu, the card or the list of hidden devices. The widget now asks the compositor for the keyboard on demand while the pointer is over it (the compositor hands it over on a click, and only if the mode is already on when the click lands) and while one of them is open, and gives it back when the pointer leaves.
- **The volume gauge is centered on the source disc as it is drawn.** It followed where the group is meant to be (position and scale), which led the disc while the camera travels to the center and while the sun carries the group around the host in this computer's view: the gauge was up to 115 px off the planet during the voyage and 36 px off in this computer's view (measured, 16 ms samples); both are now 0.00 px, size included. A wired source, which has no body, follows the group's rule (the same one that draws it). `tests/qml/ringAnchor.test.qml` measures it and fails with the old anchor.
- **A drag clears its state before its outcome runs.** Leaving, disconnecting or hiding reshapes the scene, and a body used to stay armed if that went wrong; `OrbitDrag.end()` now resets the gesture first (`tests/qml/groupLeave.test.qml`).

### Changed

- **The volume radar is a glass card, like the detail card.** Smoked glass in a dark theme, soft off-white in a light one, in your DMS colors, with a header (the big dial's name, the ✕, and a back arrow when a member is the big dial), tick marks and a soft glow on the big dial's ring, a mute pill in its opening, small dials with their names and a glow under the pointer, and glass pills for the actions. The ✕ and Escape close it.
- **The menu of a member of a group is short and clear.** A Bluetooth member: **Disconnect**, **Remove from group**, **Hide** (its noise-control modes and **Forget** stay where they were). A wired member: **Disconnect** (it leaves the group and stays plugged in) and **Hide**. **Leave together**, **Stop together** and **Add a device…** are gone from a member's menu: they belong to the group, not to one of its members (`dms ipc call orbitBluetooth separate` still stops it; dragging a member out still makes it leave). A device outside the group keeps its menu. Which entries the menu offers is now `MenuEntries.js`, pure and tested; the hints that said *Leave together* say *Remove from group*. [Guide](docs/GUIDE.md#listen-together)
- **The battery arc's color follows the level**: it drifts from your theme's red (15 % and below) through its amber (35 %) to its green (100 %), a point of level moves it a little, instead of one color per band. While charging it has a color of its own (the theme's info blue, or its tertiary when the theme's primary is that same blue), never the primary of the group's volume gauge, which it used to be confused with; the breathing glow while charging follows it. The blend is made on hue, saturation and lightness, so the middle of the way stays as vivid as its ends. [Guide](docs/GUIDE.md#battery-arc-colours)
- **The black hole shrinks with depth, and with your devices while a group has the center.** In a group's view and in this computer's view it is as big as a body at the same height of the belt (size = 1 / distance); and while the group has the center it is also as small as the rest of your devices, which keep away at 45 % of their size (it grows back as they take the center again), instead of staying as big as it was beside them. The scene's own view is unchanged, and its click and drop zones keep a comfortable size.
- **The volume scope paints once per picture, not once more per volume step.** Every step of the volume moves the sizes of the scope's sectors, and each step asked for a new picture on top of the sound's own frames: a held volume key over playing sound painted about 1.8 times as often as needed, and painted empty pictures when nothing played. A step now asks only when nothing else is about to paint (not on a blank picture, and not while frames or the fade run, since the next frame, 33 ms away at most, carries the new sizes). Same picture, same rate. Measured off-screen: 472 paints down to 258 and **−40 % CPU** while a key is held over sound (`tests/qml/polarPaints.test.qml` counts the paints and fails without the guard).
- The short notes under the center (why something did not work, two outputs on one radio) are a rounded rectangle instead of a pill: two lines of text read better as a card.
- **A new source grows into its place instead of popping.** When the output you hear changes (one leaves, or another becomes the source), the new source's disc grows from its own size to the center's over a moment, and the old one shrinks the same way, so the swap no longer jumps. With *Reduce motion* it is instant. `tests/qml/centreLoop.test.qml` samples a swap and checks the size moves one way only.
- **A bigger zone to drop one device on another.** A dragged device now listens together with the one whose center it comes within **twice that device's radius** of (60 px at least), where it used to have to be over the disc itself; the invitation's halo and thread follow the same distance. A small planet far in the ring is as easy to hit as a big one near.
- With *Reduce motion* the group is put in place at once: nothing orbits, nothing pulses, this computer stays at its resting place (up on the left, behind the group) and the scene's loop only runs for the short 0.25 s fade, then stops. While the session is locked, the screen is off or windows cover the widget, nothing runs either (no trip, no beams, no question to PipeWire about sound).
- With *Reduce motion* the recall (this computer coming back to the middle, the group stepping back) takes the short fade, like the other changes, instead of the half-second slide.
- Internal: the sun's path, size and view are pure maths in `components/centre/Sun.js` (tested by `tests/sun.test.js`); `Physics.js` functions take the scene's geometry, so a device slot, a drag and the separation between bodies are computed in the sun's own view.
- The wheel code is shared: `NotchWheel` serves the card's planet, the volume strip, the center's gauge and the devices of the group.
- Internal: the Sony framing moved to `anc/protocols/sony_frame.py`; the extras (wearing, conversation length) live in `sony_extras.py`; the pause logic is `components/wear/` (`Wear.js` pure and tested, `WearPause.qml`, `WearHeadset.qml`, `HeadsetStreams.qml`).
- Names of devices and outputs are shown as one clean line, 40 characters at most (control and invisible characters removed), in the notes, in the answers of the command line and in `hidden`.
- Two guided notes were added at the end of the list of reasons (*Tick another output*, *The group is full*), and the Together session remembers, in memory only, the groups you turned down (and the one you ended yourself).
- The scene's single physics step also gives the ghost group its slot on the ring and its fade: no timer or animation of its own, the loop still stops when nobody looks.
- Internal: the connected bodies' colors now live in the night palette (`NightColors.connected*`) and the pop animation in `PopAnimation.qml`; Bluetooth bodies look and behave as before. `TogetherSession.memberCheck(who)` and `WiredWatch.ready` (which tells "nothing plugged in" from "not read yet") serve the group chooser.

### Known limits

- The center's CPU cost has not been measured yet, only designed to be zero at rest (no timer of its own, the scene's loop stops when nobody sees it).
- The pulse along the beams reads PipeWire's link state, a best effort: it can pulse in silence or stay still while sound plays. Nothing else depends on it.
- In this computer's view the icons under a very far suggested group (14 px discs at least) can come within a few pixels of its ✕, without covering it.
- The source's own level is not on the gauge, and there is no `dms ipc call` for the general volume yet.
- No synchronisation is promised: Bluetooth codecs have different delays and Orbit cannot measure them. `togetherDelay` holds one output back by hand; the output the sound is taken from never waits.
- If the output you hear has no Orbit filter in front of it (a device without absolute volume), the copies take its sound after its volume: nothing is shared and each output plays at its own level.
- Checked with a simulated PipeWire server and simulated devices only; real hardware (a multipoint headset handing over to a phone, an AV receiver) still has to be tried.
- Wired outputs in Listen together are checked with made-up outputs only: not tried on real hardware (a USB interface, an HDMI screen, the jack), nor the group chooser's real click-through, nor the squares and the cable under a real pointer. The filter that holds a wired source back is not confirmed there, and a USB output that reports no latency counts as 0 ms.
- Next to a Bluetooth source that has Orbit's PC filters, the group's general volume gauge and its mute speaker do not move a wired output.
- A wired square jumps into place when the group changes (no glide) and vanishes without a fade; planets of the outer belt are not pushed away from it.
- The group chooser reads the plugged outputs once, when it opens, and offers only the devices on the sky. The ghost group, with *Reduce motion*, rests half behind this computer's core.
- The cost of the group chooser, the ghost group and the wired squares in the real shell has not been measured yet.
- Nothing of the lot that added the gauge, the group icons, hiding from the group menu, the learned groups, the depth of field, the battery arc colors and the copies seen through has been tried in the real shell: it is checked with tests and off-screen renders with made-up devices only (no real pointer, no CPU measure at 240 Hz).
- The gauge's gradient is linear, left to right; a conic one along the arc was not tried. The gauge and the group icons have only been seen in off-screen renders, and the icons' hover tip was checked without a real mouse.
- The depth of field is not a true bokeh (stars as soft bright discs): that needs a small shader. The cost of the sky's glow and veil in the real shell has not been measured.
- A learned group is stored as 32-bit hashes of its outputs: nothing readable, and it never leaves the computer, but it is not a cryptographic secret (someone holding the settings file and a list of device addresses could test which are in it). A session that lasts until the shell restarts is not counted. After you turn a learned group down, the pair of the same output can be suggested at once when no other learned group is complete.
- Hiding from the group chooser is checked off-screen only: the menu with a hidden output and the black hole at two depths were not rendered, and the test calls the end of the swallow animation itself.
- Dropping a device on a copy that overlaps the source can aim at the source: the drop looks for the first body of the scene, not the highest one. The charging beam and the earbuds' lightning bolt keep the theme's primary, and in the stock Blue and Cyan themes no color tells the charging arc apart from it.
- At the center the group is always in front of this computer's devices: one that passes behind it is hidden and cannot be picked up until it comes out again (about half a turn), and with *Reduce motion*, where nothing turns, a place of the ring can stay behind the group for as long as it lasts. Click this computer to see everything.

## 1.13.3 - 2026-10-04

### Changed

- Code only, nothing changes on screen: the hit test that tells which device is under a point moved from `OrbitScene` (404 → 393 lines) to `OrbitWorld`, which owns the devices.
- The daemon's `dms ipc call orbitBluetooth` commands moved into `components/common/OrbitIpc.qml`. No behaviour change.
- Internal: the noise-control service's snapshot merging moved to `AncSnapshot.js` (pure, tested); no behaviour change.
- The pairing steps of the new-device pop-up (pair, key-press check, connect, time-out, demo script) moved out of `NewDeviceWatch.qml` into `PairingFlow.qml`. No behaviour change.

### Fixed

- The DMS journal no longer fills with a QML warning ("depends on non-bindable properties") each time the Dank Island opens its volume face. The island's click-away layer is now looked up once, when the face first holds it, instead of through a binding on a list that cannot be bound. Nothing changes on screen. The lookup lives in `ClickAwayHold` (one role: that layer), and an unused import is gone from `IslandFace`.

## 1.13.2 - 2026-10-04

### Changed

- **The wheel changes the level you point at.** On the two volumes' screen (the card, the pop-up), scrolling over a half circle, the icon at its foot or its percentage changes that level, the device's or this PC's; between the half circles the nearer one takes it, and beside them the left percentage is the device's and the right one this PC's. Before, only the half circle itself counted and everything else changed the device. The level you scroll lights up (its moon grows, its percentage shines). A half notch left over from one level no longer counts toward the other.

## 1.13.1 - 2026-10-04

### Changed

- **The Dank Island keeps its own spring.** Orbit no longer forces the island to follow the volume keys without its motion (1.13.0 did, in memory): it grows out of its pill and folds back with DMS's own spring and fades, as your DMS settings decide (*Settings → Dank Island → Reduce Motion*, or the global *Reduce Motion* and animation speed). Only DMS's full-screen click-away layer is still hidden while the face is up. The motion costs shell time: one volume step up then one down, measured with music playing, went from 54 % of a core at its busiest second (3.4 % of the machine, 2.4 core-seconds over 16 s) to 186–197 % (about 12 %, 8 core-seconds). Turn *Reduce Motion* on in DMS to get the light behaviour back.
- **One volume pop-up, and it is Orbit's.** While the pop-up is on (any choice but *Off*), DMS's own volume OSD, and the volume face its Dank Island opens by itself, are switched off: nothing shows before or under Orbit's pop-up any more. The switch is held in memory only and given back when Orbit stops, when the plugin is turned off or when the pop-up is *Off*. DMS saves all of its settings together, so Orbit lets go of the switch for a quarter of a second around each of DMS's own saves: DMS's file keeps your own *Volume* value, and removing Orbit leaves nothing behind. In *Settings → Sound → Pop-up* the first choice is now called *In the Dank Island* (still the default; a screen without an island gets the pop-up where DMS's OSD would show).

## 1.13.0 - 2026-10-04

### Added

- **What really plays.** Under a device's name on its card, and in the volume pop-up for any output, one short line says what the sound is: how it is connected (Bluetooth, USB, HDMI, S/PDIF, analog), the codec (LDAC, AAC, aptX HD, SBC...), the sample rate and the bit depth, for example *Bluetooth · LDAC · 96 kHz · 24 bit*. A small info button unfolds the rest: channels, and a note when this PC resamples on the way to the device. *Settings → Sound → Audio details* chooses, fact by fact, what shows on the line and what shows when unfolded. It is read from PipeWire (`pactl`) only while the card or the pop-up is on screen; nothing runs otherwise, and nothing leaves the PC.

### Fixed

- A failed pairing no longer writes the error text to the journal (it can carry a device name or address): the journal gets a fixed line with the step that failed; the text still shows on the pairing sheet.

### Changed

- **Lighter volume keys on a Dank Island.** While Orbit's face is up, the island follows the keys at once (no spring, no cross-fade) and DMS's full-screen click-away layer is hidden; both are given back when the keys stop. The visualizer's `cava` only starts 700 ms after the last key, so a burst of steps does not pay its start-up cost. All in memory: no setting of DMS is written.
- *Visualizer motion* now defaults to *Light* (30 images per second); *Smooth* (60) stays one click away in *Settings → Sound*.
- **Each rule lives in one place.** A Bluetooth address and the BlueZ path built from it are checked by one pure, tested `common/Address.js` (the volume code, the keyboard-profile check and the battery bookkeeping each had their own copy), and the four copies of "plugin file → path" are DMS's own `Paths.strip`. The BlueZ adapter number is now capped at three digits everywhere, as it already was for the keyboard-profile check.
- **The pairing sheet is five readable parts instead of one 845-line file.** `PairingSheet.qml` keeps the card, its keys and its settings; the colours of the two skins (`PairingSkin`, `PictureColor`), the clock and entrance (`PairingMotion`), the scene (`PairingSky`, `PairingPlanet`) and the status strip (`PairingHeader`) each have their own file. Renders are identical.
- **The volume scope is four short files instead of one 373-line file.** `PolarScope.qml` keeps the geometry, the easing and the picture; the half circles (`PolarArcs`), the knobs (`PolarMoons`) and the gestures (`PolarGestures`) each have their own. Same pictures (compared with the offscreen previews), same behaviour.
- **The scene is a hub of 404 lines instead of 586.** `OrbitScene.qml` keeps the state the parts share and one-line forwarders; the drag (`OrbitDrag`), hiding (`OrbitHidden`), focus, rename and Escape (`OrbitFocus`), noise control (`OrbitAnc`), the daemon's data and clock (`OrbitDaemonData`), the detail card's measures (`FocusLayout`) and the floating chrome (`OrbitChrome`) each have their own file, and the black hole's body lives with the physics that moves it. Same pictures (compared with the offscreen previews), same behaviour.
- **The remaining big files are cut by role too.** The device body (tether, charge beam, arcs, label, look, connection effects, lock ring, close button, mouse), the detail card (corner buttons, name, volumes, battery wiring, glyph picker, and its wording in a tested `CardStatus.js`), the new-device pop-up (`BackgroundScan`, `OfferQueue`, `DemoDevice`), the offscreen previews (`mock/` data) and the tests (one gjs file per role, a shared loader and a runner). Same pictures (compared with the offscreen previews), same behaviour.

## 1.12.1 - 2026-10-03

### Fixed

- **Changing the volume no longer costs the whole shell.** The levels eased with QML animations, which made every shell window (bars, wallpaper) redraw at the screen's rate while the pop-up showed; they now ease on the scope's own 60 Hz clock, and the sound picture is computed once for every screen, each screen only painting it. Measured while stepping the volume three times a second, sound playing, Dank Island on two screens: the shell used **92 %** of one core with 1.12.0, **≈ 21 %** now; DMS alone, same test, uses ≈ 10 %. The rest is the live sound picture itself, drawn 60 times a second while the pop-up shows (*Light*, 30 images per second, or *None* in *Settings → Sound* make it cheaper); at rest nothing runs, as before.
- The keyboard-profile question of a new device could be skipped silently when its answer was written to an object that did not exist: the connection flow now keeps it on its own object, and a test covers it.
- Saving a level or hiding a device no longer wakes every view that reads a list setting.
- Moving the sound to another output while the scope showed could leave it on the one-band fallback until the next restart.
- The live sound no longer stutters when `cava` sends a frame a little late: the scope used to take it for silence and draw a blank step first (10 frames gave 19 pictures, now 10). Silence over an already blank picture paints nothing.

### Changed

- **The two volumes never share a colour.** When the theme's two accents look alike (a generated pink and salmon, for example), this PC's level takes the opposite hue (pink and mint), in the scope and in the folded line; distinct accents stay as they are.
- The code is split into feature folders (`components/scene`, `device`, `card`, `volume`, `pairing`, `noise`, `common`), the orbit's physics live in a pure, tested `Physics.js`, and one sound feed and picture serve every screen; see [CONTRIBUTING](CONTRIBUTING.md). The biggest files are cut by role: the scene (`Orbit.js`, connections, discovery, backdrop, world), the device body (tether, charge beam, arcs, label), the pairing sheet (stage, identity, button), the scope (grid, readouts) and the settings (one file per tab). Nothing changes on screen (every preview identical to 1.12.0).

## 1.12.0 - 2026-10-03

### Added

- **Two volumes, the device's and this PC's.** Many Bluetooth devices have a volume of their own; Orbit now keeps it apart from what this PC sends, remembers this PC's level per device, and draws both as two half circles, one inside the other, with the live sound inside (a polar vectorscope read by `cava`, only while it shows). *Settings → Sound → Separate PC volume* turns it off. A device without a volume of its own shows one level and says why.
- **Volume pop-up.** When any volume changes, a small dark screen shows both levels: in place of DMS's volume OSD (default), under the bar widget, on the right screen edge, or off. On screens with Dank Island, it shows inside the island instead. Three sizes, and four ways to draw the sound: *Points*, *Rays*, *Waves* or *None*, at 60 or 30 images per second.
- **Smart volume steps.** 1 % per slow notch, bigger steps when you scroll or press fast, and a short hold when you turn back; *Gentle*, *Balanced* or *Fast*, or a fixed step.
- **Command line**: `dms ipc call orbitBluetooth volume up | down` (smart steps), `deviceVolume` and `pcVolume` (`up`, `down`, `0`–`100`, `+N`, `-N`).
- **Volume keys with smart steps, in one click.** The first time Orbit's volume pop-up opens, one line offers it (*Smart volume keys? Enable*, with *Undo* after); also in **Settings → Sound** and `dms ipc call orbitBluetooth volumeKeys on | off | status`. Orbit asks DMS's own `dms keybinds` to bind the two keys, only if they still do DMS's default; they fall back to DMS's step if Orbit is off or gone, and *Undo* or uninstalling writes back DMS's exact line (niri only). They always change the output you hear: with the sound on a wired interface, a connected headset does not move.
- **Uninstalling leaves nothing.** DMS deletes the plugin folder but keeps its settings and widgets; Orbit now erases them itself when it finds its folder gone (settings, bar, Control Center and desktop widgets with their positions, pictures cache). It waits a few seconds and checks again, so an update that re-downloads the folder keeps everything; disabling or restarting erases nothing.

### Changed

- **Sounds moved to the new *Sound* tab** (cues, their volume and the volume tick); *Look & sound* is now *Look*.
- **In the bar pop-out and the Control Center, the card's volumes start folded** into one thin line, so the card fits without scrolling; the wheel over a level changes it, a click unfolds the scope.
- **The device card shows both volumes.** Under the device name, the same dark scope as the volume pop-up: the device's half on one side, *This PC* on the other, live sound in the middle while the card is open. Drag or scroll either half; click the planet to mute, scroll on it to change the main volume. A device whose volume follows the PC shows a short note with the GitHub mark. The aurora ring around the planet and its effects are gone, and the card leaves less empty room above the planet.

## 1.11.2 - 2026-10-03

### Changed

- **Ambient motion pauses behind windows.** When windows fill the screen (fullscreen, maximized, or several side by side), the desktop orbit freezes as if Ambient were off: nobody can see it drift. It wakes as soon as the desktop shows again (workspace change, window closed, overview). niri only; on other compositors Ambient keeps running.
- Ambient's slow drift with nobody around runs at 20 Hz instead of 30 Hz.

### Performance

- Desktop widget with *Ambient motion* on, two screens covered by windows: **3.33 % → 1.43 %** of one core for the whole shell, against 1.38 % with Orbit disabled (counter-tested: back on 1.11.1, 3.33 %; again on 1.11.2, 1.58 %).

## 1.11.1 - 2026-10-03

### Added

- Four more short notes, each with the GitHub mark that opens the matching guide section, so Orbit never fails in silence:
  - **Turn on** had no effect (Bluetooth is still off 3 s later): "Bluetooth stayed off — Airplane mode or a switch may block it".
  - **No adapter**: the "No Bluetooth adapter" line now carries the GitHub mark.
  - Scrolling on a connected device that has no volume: "<name> has no volume — It does not play sound, or its audio is not ready yet".
  - **Disconnect** that does nothing within 8 s: the planet shakes and "<name> is still connected — It may be in use: try again, or turn it off".
- Guide: new sections *If it does not disconnect* and *Bluetooth is off* (rfkill, airplane mode, the Bluetooth service).

### Fixed

- A planet whose disconnection never happened stayed stuck in the "disconnecting" state until Orbit restarted; it now returns to normal after 8 s.

## 1.11.0 - 2026-10-03

### Added

- **Volume ring**: open a connected audio device and a ring floats around its planet. Scroll for 5 % steps, drag along the ring for anything in between, click the planet to mute. The level is a band of aurora that ripples and flares as it moves; moving it leaves a comet tail and fine stardust, each step sends a sound wave off the planet (a corona at 100 %), and mute eclipses the planet. While you change it, the percentage drops into the ring's gap: digits roll on a spring and the level swings past and settles. The effects run on one 60 Hz clock, only while something moves, and are drawn light: a translucent band, dust written into fixed slots (at most 80 grains a second). Offscreen bench, 6 s of continuous drag: effects cost 0.16 s of CPU, down from 0.40 s in the first draft.
- **Volume tick** (Look & sound, on by default): a soft, short tick plays in the device itself at each 5 % step, so you can hear where you are.

### Changed

- Detail card buttons are balanced: back and change icon on the left, connect, hide and forget on the right.
- When the pairing sheet appears, the Orbit popout closes behind it instead of staying under the sheet.
- The sheet's *Connect* button is flatter and calmer: a solid accent rectangle with softly rounded corners, a hairline of light on top and a medium-weight label; the sheen and the progress bar are unchanged.

### Removed

- The volume slider of the detail card, replaced by the ring.

### Fixed

- The pairing sheet no longer redraws the whole shell while it is shown. Its scene clock and its 30 s countdown were long QML animations, which make every shell window (bars, wallpaper, both screens) repaint at the screen rate; they now run on timers (60 Hz while something moves, 30 Hz for the countdown), so only the sheet repaints. Measured with the demo sheet on screen: 67.1 % of a core down to 5.8 %, and 6 busy render threads down to 1.

## 1.10.4 - 2026-10-02

### Fixed

- The sheen on the *Connecting* button no longer shows a square edge: it is a rounded pill that fades at both ends.

### Changed

- Settings are grouped into tabs (Orbit, Scanning, Headphones, Desktop, Look & sound), one shown at a time.

### Fixed

- **Pop-up for new headphones** works on its own: turning off **Offer new devices** (the card inside the Orbit view) no longer hides the pop-up without a word.

## 1.10.3 - 2026-10-02

### Added

- When pairing, connecting or noise control does not work, a short note says why and what to do, with a GitHub mark that opens the matching section of the guide (in your browser, on click only). The `anc` commands print the guide link too.

### Changed

- **Background scan** is now a separate option, **off by default**: the new-headphones pop-up listens to any search you start (free), and Orbit only scans by itself if you turn it on. Its interval and battery settings appear only then.

## 1.10.2 - 2026-10-02

### Security

- **Real device pictures** looks up only devices you have paired: the model name of a stranger's device nearby is never sent.
- A picture that arrives after you turn the option off is dropped, and turning it off erases the cache.
- The picture cache is private (folder 0700, files 0600).
- The pairing log no longer contains the device name.
- **Safe pairing**: a device is offered only when Bluetooth says it is audio, not because of its name. After pairing, Orbit checks its services before trusting it; headphones that can also send key presses (often for their buttons) wait, unable to connect, until you choose **Pair anyway**, and are forgotten otherwise. Same check when dragging a device into the orbit.
- **Real device pictures** follows a redirect only to the listed hosts, over https; its User-Agent now gives the right version.
- The noise-control helper receives the headset's name through its environment rather than its command line, which other programs can read. Both helpers ignore `PYTHON*` variables and user packages (`python3 -E -s`).
- The noise-control helper keeps at most 64 KB of an unfinished message, whatever a device sends.

### Fixed

- The pairing sheet's animation pauses while the session is locked or the screens are off.

## 1.10.1 - 2026-10-02

### Fixed

- The offscreen previews (`scripts/preview/`) render again: they lacked a stand-in for PipeWire, which the volume row needs since 1.10.0.

### Changed

- Shorter files, same behaviour: the scene's chrome (pairing offer, scan chip, "Bluetooth is off") and the middle of the pairing card are now their own components. Every preview renders pixel for pixel as before.

## 1.10.0 - 2026-10-01

### Added

- **New headphones pop-up**: put headphones, earbuds or a speaker in pairing mode and a tall pairing sheet unfolds from the right end of the bar, even with Orbit closed. The device falls out of the bar along a comet trail into an orbit, floats above a planet's horizon and tilts towards the pointer, among twinkling stars and the odd shooting star. Two looks: deep space with a dark DMS theme, stratosphere with a light one; any palette works, its accent is brightened or deepened until it reads well.
- In the sheet: what you get (noise control, rated battery life, earbuds), **Connect** with live *Pair → Connect → Ready* steps, a star burst and a filling battery ring when connected, then the noise-control modes; rename the device before connecting; **Later** snoozes it 10 minutes, **Don't offer again** never offers it again; several devices stack with a "+1". <kbd>Enter</kbd> and <kbd>Escape</kbd> work while the pointer is on it. It folds back into the bar after a connection.
- Only named, unpaired audio devices; never while a window is full screen or the screen is locked.
- The sheet lines up with the bar's right end; a name typed in it is kept when you click away; a failed pairing says why (declined, wrong code, no answer, busy).
- Background scan for it: 8 s every minute (**Background scan**), skipped while Bluetooth audio is connected (scanning makes it stutter), on battery below **No background scan below** (30 %), and while the screen is off. Turn it off with **Pop-up for new headphones**.
- **Forget** in the right-click menu (click again to confirm). Forgetting a device also clears its icon choice and its *Don't offer again* mark.
- **Offer ignored devices again** button in the settings.
- IPC: `newDeviceDemo` shows the sheet with a made-up headset, `newDeviceStatus` tells whether the background scan runs or why not.
- QML scenario tests for the pop-up's logic (`tests/qml/run.sh`), with stubs for Quickshell and the DMS services; `scripts/preview/sheet.qml` renders the sheet with six test palettes, or records it.

### Changed

- New *Portable speaker* icon: a rugged capsule instead of something that looked like a cassette.
- With the pop-up on, the *Connect* card inside the orbit gives way to it.
- Real device pictures: the model name of an audio device offered by the pop-up may be looked up too (only with that option on).

## 1.9.0 - 2026-10-01

### Added

- **Real device pictures** (opt-in, off by default, uses the internet): a photo of the model replaces the icon of paired and connected devices, with its author and license under the detail card. Looked up on `commons.wikimedia.org`, then `api.sketchfab.com`; only the model name is sent, free licenses only, kept in `~/.cache/orbitBluetooth/pictures`. **Delete downloaded pictures** empties the cache. Not tested against the live services yet.

### Changed

- Privacy: the "no network" rule now has this one opt-in exception, documented in the README, the guide and the settings.

## 1.8.0 - 2026-10-01

### Fixed

- A headset disconnected while in conversation mode stayed in it, with no way to turn it off. Orbit now turns conversation awareness off before it disconnects a headset, and again after a reconnection. The noise-control mode is kept as it was. Option **Turn off conversation awareness on disconnect** (on by default).

### Changed

- The *Remember conversation awareness* option and its saved per-headset choice are gone: they did the opposite of this fix.
- Nothing Ear (2) confirmed on hardware.
- Documentation split into `README.md`, `docs/GUIDE.md`, `CHANGELOG.md`, `ROADMAP.md` and `CONTRIBUTING.md`.

## 1.7.1 - 2026-10-01

### Changed

- Control Center tile: named **OrbitBluetooth** instead of "Bluetooth", and the device name under it is cut at 12 characters so it stays inside the tile.

## 1.7.0 - 2026-10-01

### Added

- Offer to connect: when an unpaired, named device shows up while the view scans, a small card says so with a **Connect** button (it goes away after 12 s or with ×). Devices already around when the view opens are not offered. Turn it off with **Scanning → Offer new devices**.
- Connecting: two soft sonar rings leave the device, next to the comet. Not seen on real hardware yet.

## 1.6.0 - 2026-10-01

### Added

- Volume per device: a slider and a mute button in the detail card of a connected audio device, through PipeWire (local only). Not tested on real hardware yet.

## 1.5.0 - 2026-10-01

### Added

- Conversation awareness is remembered per headset and put back after a reconnect (option *Remember conversation awareness*, on by default).
- Silent Apple models (AirPods Max 2): Orbit asks for the state a second time, then offers the modes for *Pro* and *Max* names. Known not functional on the AirPods Max.

### Changed

- Scene chrome (scan chip, *Turn on* button, sky color) takes its sizes from the DMS theme; the night colors live in one place (`NightColors`).
- AirPods 3 and 4 confirmed on hardware.

## 1.4.1 - 2026-09-27

### Changed

- Device names are readable everywhere, even on a pale or busy wallpaper: each name glows softly in your theme's accent, and devices that are not connected fade less. On the desktop they also sit on a smoky disc.
- Desktop widget: devices are a quarter smaller, so the orbit sits lighter on the wallpaper. The panels keep their size.
- Connected devices read stronger than the others. With nothing connected, every name is lifted.

## 1.4.0 - 2026-09-26

### Added

- Rename a device: click its name in the detail card. Enter saves, Escape cancels, an empty name restores the device's own name.

### Changed

- A renamed device keeps its icon, noise control, earbuds look, battery estimate and custom pictures: they follow the name the device reports itself.

## 1.3.2 - 2026-09-26

### Changed

- The Control Center and the bar popout are as light as the desktop: nothing loops as a QML animation anywhere, the drift runs on a 30 Hz timer, and display-synced frames are only used while dragging. An open view at rest costs about 5–6 % of one core for the whole shell.
- Shooting stars are rarer (every 12–32 s), cross from the top left to the bottom right, and bend toward the black hole or get swallowed by it.

### Fixed

- A connection attempt no longer makes the whole shell redraw at the display rate.

## 1.3.1 - 2026-09-26

### Changed

- Everything pauses while the session is locked or the monitors are off; connection timers pause when nobody is looking.

### Fixed

- Desktop widget truly at rest: from about 65 % of a core to about 1 % (about 3.5 % with *Ambient motion*).
- Dragging stays smooth to the very end of the motion.

## 1.3.0 - 2026-09-26

### Added

- Light theme support: the sky stays night, devices turn white, cards use a soft white.

## 1.2.2 - 2026-09-26

### Added

- Pick the screens of the desktop widget from Orbit's settings.

### Changed

- Esc steps back one level (menu, hidden list, card) before closing the view.
- The quick-disconnect × is now an option, off by default.
- Clicking the center only reacts on its inner 70 %, never over a device.
- Settings grouped into short sections, with a note on the options that use more battery.
- The machine in the center is 15 % smaller.

## 1.2.1 - 2026-09-26

### Changed

- Charging beam redrawn as thin magnetic field lines.
- Charging earbuds move closer to the case, with their battery bar.

## 1.2.0 - 2026-09-26

### Added

- Earbuds trio: the case and both buds in their own mini orbit, each with its battery, and a beam to the bud that charges.
- Live charging state while a view is open (headset session instead of a one-off read).

### Changed

- The Control Center tile grows to the exact height of the open card.

### Fixed

- DMS's pairing dialog is shown for devices that ask for a code (fixes endless disconnects).

## 1.1.1 - 2026-09-26

### Fixed

- Detail card polish: symmetric spacing, a mode pill that hugs its content.
- Noise control no longer loses the final state or flashes back to the previous mode.

## 1.1.0 - 2026-09-26

### Added

- Noise control for 13 headphone brands (tested on Sony and Huawei).
- The black hole: drag a device into it to hide it, click it to list and bring devices back; two looks.
- Right-click menu, a comet while a device connects, depth on the ring of connected devices.
- Battery time left from the moment a device connects.

## 1.0.0 - 2026-09-25

### Added

- First release: the planetary scene, drag to connect, the detail card, Control Center + bar + desktop, 28 device icons, sounds, and an option to scan only on demand.
