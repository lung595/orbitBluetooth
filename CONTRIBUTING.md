# Contributing

Everything needed to work on Orbit Bluetooth or take over the project.

## Contents

- [Development setup](#development-setup)
- [Architecture](#architecture)
- [Project layout](#project-layout)
- [Tests](#tests)
- [Screenshots, shaders and sounds](#screenshots-shaders-and-sounds)
- [Performance rules](#performance-rules)
- [Conventions](#conventions)
- [Releasing a version](#releasing-a-version)

## Development setup

1. Clone the repository into the DMS plugin folder and enable it in **Settings → Plugins**:

   ```sh
   git clone https://github.com/lung595/orbitBluetooth ~/.config/DankMaterialShell/plugins/orbitBluetooth
   ```

2. Add at least one widget (Control Center, bar or desktop) to see your changes.
3. DMS reloads QML on save, but Qt keeps `components/` and `.js` files cached in the running shell: **run `dms restart`** after changing them.
4. Set `ORBIT_ANC_DEBUG=1` in the shell's environment to see the noise-control packets on stderr.

Tools: `gjs` (JS tests), Python 3 (helper and its tests), `ffmpeg` (GIFs), Qt 6 `qsb` (shaders).

## Architecture

`plugin.json` declares a **composite** plugin with three components and a settings page:

| Component | File | Role |
| --- | --- | --- |
| Daemon | `OrbitBluetoothDaemon.qml` | One instance, shared by every surface. BlueZ exposes no connection time, charging state or discharge rate, so it records them: connection times, battery log, UPower bridge |
| Widget | `OrbitBluetoothWidget.qml` | Bar pill, bar popout and Control Center tile |
| Desktop | `OrbitBluetoothDesktop.qml` | Desktop widget, frozen until the pointer is over it |
| Settings | `OrbitBluetoothSettings.qml` | Settings page |

`components/` has one folder per feature: `scene/`, `device/`, `card/`, `volume/`, `together/`, `radio/`, `pairing/`, `noise/`, `wear/` and `common/`. A file imports its neighbours directly and another feature's folder by path (`import "../card"`).

Every surface shows the same scene, `components/scene/OrbitScene.qml`. It only holds the state the parts share and wires them; each role has its own file, and the parts reach each other through the scene's functions (`scene.hideBody(b)`, `scene.ancSend(...)`), never through one another. The drag (`OrbitDrag`; the invitation to listen together, `OrbitInvite` with its maths in `Invite.js`, is created only while a device that could join is carried), hiding in the black hole (`OrbitHidden`), focus, rename and Escape (`OrbitFocus`), noise control (`OrbitAnc`), the daemon's data and clock (`OrbitDaemonData`) and the detail card's measures (`FocusLayout`) are each a short file; they open the cards (`card/FocusCard.qml`, `card/HiddenCard.qml`, `scene/OrbitMenu.qml`). `scene/OrbitPhysics.qml` moves every device (`device/DeviceBody.qml`) in one step per frame, with the maths in `scene/Physics.js` (pure, tested). What floats above the world (`pairing/OfferCard.qml`, `scene/ScanChip.qml`, `scene/AdapterNotice.qml`, the hint and the note) is grouped by `scene/OrbitChrome.qml`.

Logic that can be tested lives in **pure `.js` files** with no QML: `card/Charge.js` (charge analysis), `card/Endurance.js` (rated battery life), `card/CardStatus.js` (the detail card's wording), `scene/Physics.js` (springs, slots, clearances), `scene/Invite.js` (the invitation's halos, thread and light dots), `noise/Anc.js` (noise-control decisions), `noise/AncSnapshot.js` (merging a headset's reports into one snapshot), `wear/Wear.js` (what a wearing status means, which players to pause and which to resume, what `wearStatus` says), `volume/Polar.js` (the scope's geometry and sound picture), `volume/Route.js`, `volume/Steps.js`, `volume/Keys.js` and `volume/Audiophile.js`, `volume/AudioGraph.js` and `volume/Codecs.js` (volumes and what plays), `radio/Radio.js` (which outputs share the adapter's radio, which pair was told about), `together/Together.js` (who may listen together, where the sound is taken from, the command of each copy and what to start or stop, one keyed `diff`), `common/Address.js` (the shapes of a Bluetooth address and of its BlueZ path, checked before any command), `device/Earbuds.js`, `device/DeviceCatalog.js` and `device/Glyphs.js` (icons).

**The volume scope** (detail card, pop-up, Dank Island) runs one `cava` and computes one picture for every screen that shows it: `volume/TwoLevels.qml` holds an output's two levels, its `ScopeFeed.qml` (cava, only while someone looks) and its `ScopeModel.qml` (points, rays or waves, moved by cava's frames, fading alone, then stopped). `PolarScope.qml` keeps the geometry, eases the levels and holds the picture; `PolarArcs.qml` draws the half circles, `PolarMoons.qml` the knobs, `PolarGestures.qml` takes the drag, wheel and mute click, and `PolarVisual.qml` only paints the shared picture at its own size. While outputs listen together, `Members.js` and `MemberColors.js` (pure, tested by `tests/members.test.js`) give the arcs' levels, the cloud's sectors and the colors (primary, secondary, tertiary in turn, turned apart when two look alike); `MemberPalette.qml` hands them to the scope and to the strip so an output has one color everywhere, and `PolarLegend.qml` writes each arc's name and level (spots from `Polar.legendSpot`) when there are three or more.

**Listen together** (`components/together/`) is the daemon's, reached through `AudioRoute.together`. `Together.js` (pure, tested by `tests/together.test.js`) decides; `TogetherSession.qml` holds the members (2 to 4), the delays and the plan, and keeps a session alive through suspends and hand-overs (a member leaves only on a BlueZ disconnection or when asked); `TogetherLink.qml` runs one `Process` per copy through an `Instantiator`, each `pw-loopback` started by `Route.loopbackArgs` (data only as positional parameters, so it dies with the shell). Both ends of a copy are `node.passive` and `node.dont-fallback` and no stream is ever held toward a member's output (D279). The scene side is `scene/OrbitTogether.qml` (the drop, the notes, Leave and Stop in `OrbitMenu.qml`); the IPC is in `common/OrbitIpc.qml`. A change to the copies must keep: no BlueZ call, no write to DMS or WirePlumber, nothing running at rest, and the level written to **all** members' filters together (`AudioRoute.writeLevel`). `tests/qml/togetherSession.test.qml` runs a session against the mock `Process` (`scripts/preview/imports/Quickshell/Io/ProcessLog.qml` records every start and stop).

**The shared-radio note** (`components/radio/`) tells, once per pair of outputs and per session, that two Bluetooth outputs playing at once share one radio (D293, P170). `Radio.js` (pure, tested by `tests/radio.test.js`) names the outputs fed sound, the pair, and whether to say it now; `RadioWatch.qml` reads PipeWire's link groups and exists only while two outputs of the adapter do; `scene/OrbitRadio.qml` creates it on demand and calls `scene.explain(Guide.radioNote())` while the orbit is open. It stores nothing and changes no codec, quality or setting: lowering a device's quality to make two fit is a rejected design (D293), keep it that way. `tests/qml/radio.test.qml` runs it against the mock PipeWire (`scripts/preview/imports/Quickshell/Services/Pipewire/Pipewire.qml`: `extraSinks`, `links`).

**The listening source at the center** (`components/centre/`) is the scene's. `Centre.js` (pure, tested by `tests/centre.test.js`) holds every size, place and duration: the group's disc sizes (the source as big as the host's core), the tilted orbit of the copies, the parallax, the label text and the pulse along a beam. `Sun.js` (pure, tested by `tests/sun.test.js`) is the solar system: the sun's path, its size and depth, the view that the devices around it are placed in, and the order the host is drawn in; `Physics.js` functions take the scene's geometry, so `OrbitCentre.sunGeometry()` and `geometryOf(body)` hand them the sun's view (the scene itself when no group has the center). `MasterVolume.js` (pure) keeps the gaps when the general level moves. `OrbitCentre.qml` is the state (who is in, the voyage, the stage, the beams' clock) and answers what the bodies ask (`target`, `size`, `holds`); it has **no timer**: `OrbitPhysics.step` calls its `advance(dt, driven)`, so the trip rides the loop that already stops when nobody sees the scene (never start a timer or animation there: the scene settles, and `tests/qml/centreLoop.test.qml` fails if it does not). `CentreVolume.qml` is the levels, `CentreWatch.qml` (loaded only while someone sees the group move) reads PipeWire's links, and `CentreBeams.qml`, `CentreRing.qml`, `CentreLabel.qml`, `LevelArc.qml` and `MemberLevel.qml` are the parts, each loaded only while a group exists. The wheel is `volume/NotchWheel.qml`, shared with the card. `tests/qml/centre.test.qml` runs `OrbitCentre` against a made-up scene (the counter-proofs: the beams' clock, the PipeWire watch, the snap with Reduce motion).

**Noise control** is the only part outside QML: QML cannot open a Bluetooth socket, so `components/noise/AncService.qml` runs `anc/orbit_anc.py`, which speaks each vendor protocol (`anc/protocols/`, one module per brand) through a JSON session on stdin/stdout. `anc/sdp.py` finds the RFCOMM channel. The Sony protocol is split by role: `sony_frame.py` (framing and checksum), `sony.py` (the handshake and noise control), `sony_extras.py` (the wearing sensor and the length of a conversation, from SonyHeadphonesClient, MIT).

**Pause on removal** (`components/wear/`): `AncService` keeps one session open for a Sony headset that reports a wearing sensor (only while the setting is on); `WearPause.qml` follows the headsets whose snapshot says so, and one `WearHeadset.qml` per headset reads the status, asks `HeadsetStreams.qml` which applications play on it (PipeWire) and pauses or resumes the matching MPRIS players. All decisions are in `Wear.js`.

**New headphones pop-up**: `components/pairing/NewDeviceWatch.qml` (in the daemon) drives the pop-up and pairing, with `BackgroundScan.qml` (the opt-in short scan), `OfferQueue.qml` (what to offer next, snoozes; `Offer.js`, pure) and `DemoDevice.qml` (the made-up headset of the demo) and `PairingFlow.qml` (the pairing steps: pair, check, connect, time-out); `NewDeviceWindow.qml` is its layer-shell window and `PairingSheet.qml` the sheet itself (two skins, colours from `Palette.js`), which `scripts/preview/sheet.qml` renders offscreen with six test palettes, or records frame by frame. Before a new device is trusted, `ProfileCheck.qml` reads its Bluetooth profiles with `busctl` and `Guard.js` (pure, tested) decides: a non-input device that can also send key presses stays blocked until the user confirms. Never trust a device from its name alone.

**Guided, never blocked**: `components/common/Guide.js` (pure, tested) builds the guide links and the short notes (`connectNote`); `scene/OrbitNote.qml` shows them at the bottom of the sky and `common/GuideLink.qml` is the GitHub mark (drawn by `common/GitHubMark.qml`) that opens a guide section on click. A new refusal gets a note and an anchor that exists in `docs/GUIDE.md` (the tests check it). Every new Quickshell import or service used by a component needs its mock in `scripts/preview/imports/`, or the previews break; the made-up devices and state of the screenshots live in `scripts/preview/mock/`.

**Uninstalling leaves nothing** (value 12): `components/common/UninstallSweep.qml` (in the daemon) reads `uninstall/orbit_uninstall.py` when Orbit loads; when Orbit is unloaded and its `plugin.json` is gone, it starts that script detached, from memory (`python3 -c`), since the folder no longer exists. The script waits 4 s, checks again (an update may re-clone the folder) and only then edits the shell's JSON files, which DMS watches. Never create QML objects in `Component.onDestruction`: it crashed the shell.

**Real device pictures** (opt-in) is the only network use: `components/common/PictureService.qml` runs `pictures/orbit_pictures.py` (Wikimedia Commons, then Sketchfab; standard library only), and `components/common/Pictures.js` decides which names may be sent. Keep the list of hosts in sync between the helper header, the settings description, the README and the GUIDE.

Settings are read through `components/common/Prefs.qml`, a reactive view shared by every surface.

## Project layout

```
orbitBluetooth/
├── plugin.json                  # manifest: id, version, components, permissions
├── OrbitBluetoothDaemon.qml     # shared bookkeeping (see Architecture)
├── OrbitBluetoothWidget.qml     # Control Center tile, bar pill and popout
├── OrbitBluetoothDesktop.qml    # desktop widget
├── OrbitBluetoothSettings.qml   # settings page: the chip tabs, one file each in components/settings/
├── components/
│   ├── settings/                # one tab per file (Look, Sound, Orbit, Headphones, Desktop, Scanning) and their shared rows
│   ├── scene/                   # the sky every surface shows
│   │   ├── OrbitScene.qml       # the scene: composition and wiring of the files below
│   │   ├── Orbit.js, OrbitDevices.qml  # which devices the orbit shows (Orbit.js pure, tested), one model entry per body
│   │   ├── OrbitConnections.qml, OrbitDiscovery.qml, OrbitOffer.qml  # connection flow, scan only while viewed, offer to connect
│   │   ├── OrbitDrag.qml, OrbitHidden.qml, OrbitFocus.qml  # the drag gestures, hiding in the black hole, focus + rename + Escape
│   │   ├── OrbitAnc.qml, OrbitDaemonData.qml, FocusLayout.qml  # noise control, what the daemon publishes + its clock, the detail card's measures
│   │   ├── OrbitBackdrop.qml, OrbitWorld.qml, OrbitCore.qml, OrbitHint.qml  # sky, orbits and bodies, host core, drag hint
│   │   ├── OrbitPhysics.qml, Physics.js  # one motion step for every body (Physics.js pure, tested)
│   │   ├── Cover.js             # is the desktop hidden behind windows? (pure, tested)
│   │   ├── OrbitChrome.qml, ScanChip.qml, AdapterNotice.qml, OrbitNote.qml  # what floats above the world: scan chip, Bluetooth off, notes
│   │   ├── OrbitMenu.qml        # the right-click menu (with Leave / Stop together)
│   │   ├── OrbitTogether.qml    # Listen together in the scene: the drop, the notes, leave and stop
│   │   ├── BlackHole.qml, RingWave.qml   # the "Hidden" black hole (two shaders), the connected ring's wave
│   │   └── Starfield.qml, Vignette.qml, NightColors.qml
│   ├── device/                  # one orbiting device
│   │   ├── DeviceBody.qml, BodyFace.qml, BodyPointer.qml, QuickDisconnect.qml  # body (state, motion), its look, its mouse, its close button
│   │   ├── ConnectingFx.qml, LockRing.qml, EnergyBeam.qml, LabelGlow.qml  # connection comet and rings, lock ring, charging beam (shaders/beam.frag), label glow
│   │   ├── BodyTether.qml, ChargeBeam.qml, BodyArcs.qml, BodyLabel.qml  # tether to the core, charge beam, rings (noise control, battery), caption
│   │   ├── DeviceGlyph.qml, DeviceCatalog.js, Glyphs.js   # device icons
│   │   └── EarbudsTrio.qml, EarbudArt.qml, Earbuds.js     # case + buds mini orbit
│   ├── card/                    # the detail and hidden-devices cards
│   │   ├── FocusCard.qml, PlanetControl.qml  # detail card (layout of its sections); focused glyph: click to mute, wheel for the volume
│   │   ├── CardActions.qml, CardButton.qml, NameBox.qml  # corner buttons (back, look, connect, hide, forget), their round button, the name and its rename
│   │   ├── VolumeSection.qml, FoldButton.qml, GlyphPicker.qml  # the two volumes (strip or scope) and the button that folds them, the glyph grid
│   │   ├── BatteryCard.qml, CardBattery.qml, StatTiles.qml  # gauge, chart and READY AT / SPEED / HEALTH tiles; the card's own wiring of them
│   │   ├── Charge.js, Endurance.js, CardStatus.js  # battery analysis, rated life, the card's wording (pure, tested)
│   │   └── HiddenCard.qml, PaperColors.qml   # hidden devices; light-theme colors
│   ├── volume/                  # the two volumes and the scope
│   │   ├── TwoLevels.qml        # an output's two volumes, its cava and its picture (base of CardVolume, VolumeOverlay)
│   │   ├── CardVolume.qml, Volume.js         # the detail card's two volumes and tick (Volume.js pure, tested)
│   │   ├── VolumeOverlay.qml, VolumePopup.qml, IslandFace.qml  # volume pop-up per screen, its face inside Dank Island
│   │   ├── DmsOsdOff.qml        # holds DMS's own volume OSD off, in memory, while the pop-up is on (D273)
│   │   ├── ClickAwayHold.qml    # hides the island's click-away layer while the face is up; the island's spring stays DMS's
│   │   ├── AudioFacts.qml, FactsLine.qml, Audiophile.js  # what plays: `pactl` read on demand, the line with its info button, parsing (pure, tested)
│   │   ├── AudioGraph.qml, AudioGraph.js, Codecs.js  # `pw-dump` / `pw-top` read only while looked at and wanted; their parsing and the codec / bit rate tables (pure, tested)
│   │   ├── VolumeStrip.qml      # menus: the two volumes folded into a thin line, unfolds on click
│   │   ├── ScopeScreen.qml      # the dark scope screen shared by card, pop-up and island
│   │   ├── PolarScope.qml, PolarVisual.qml, Polar.js   # geometry and easing, the painted picture (Polar.js pure, tested)
│   │   ├── PolarArcs.qml, PolarMoons.qml, PolarGestures.qml  # half circles, knobs, drag / wheel / mute
│   │   ├── PolarGrid.qml, PolarReadouts.qml, PolarLegend.qml  # the scope's screen (grid), icons and numbers, the names of three or four arcs
│   │   ├── Members.js, MemberColors.js, MemberPalette.qml  # outputs listening together: levels, cloud sectors, theme colors (pure, tested)
│   │   ├── ScopeFeed.qml, ScopeModel.qml     # live stereo bands from cava; the picture they move, once for every screen
│   │   ├── AudioRoute.qml, RouteDevice.qml, Route.js   # the two levels of each output: PC filter, absolute volume, IPC
│   │   └── VolumeKeys.qml, Keys.js, Steps.js # volume keys through `dms keybinds`, smart steps (pure, tested)
│   ├── together/                # Listen together (D254, D277, D279)
│   ├── radio/                   # the shared-radio note (D293)
│   │   ├── Together.js          # who may join, where the sound comes from, the copies' commands (pure, tested)
│   │   ├── TogetherSession.qml  # the members, delays and plan of a session; survives suspend and hand-over
│   │   └── TogetherLink.qml     # one pw-loopback per extra output, started and stopped by key
│   ├── centre/                  # the listening source at the center and the sun around it
│   │   ├── Centre.js, Sun.js, MasterVolume.js   # sizes, places and durations; the sun's path, size and view; the general volume's gaps (pure, tested)
│   │   ├── OrbitCentre.qml      # the state and the answers to the bodies, no timer of its own
│   │   └── CentreVolume.qml, CentreWatch.qml, CentreBeams.qml, CentreRing.qml, CentreLabel.qml, LevelArc.qml, MemberLevel.qml  # levels, PipeWire watch, beams, ring, group name, arcs
│   ├── pairing/                 # new device pop-up and pairing offer
│   │   ├── NewDeviceWatch.qml, PairingFlow.qml, BackgroundScan.qml, OfferQueue.qml, DemoDevice.qml, Offer.js, Guard.js, ProfileCheck.qml  # pop-up, pairing steps, background scan, what to offer, demo, the input-device guard
│   │   ├── NewDeviceWindow.qml, PairingSheet.qml, Palette.js  # the window and the sheet (the card, its keys and its parts)
│   │   ├── PairingSkin.qml, PictureColor.qml, PairingMotion.qml  # the two skins' colours, the picture's colour, the sheet's clock and entrance
│   │   ├── PairingSky.qml, PairingPlanet.qml, PairingHeader.qml  # the scene behind the device, status and close button
│   │   ├── PairingStage.qml, PairingIdentity.qml, PairingMiddle.qml, PairingButton.qml, Light.qml  # device, name and subtitle, tiles/steps/quick actions, actions, round light
│   │   └── OfferCard.qml        # the scene's pairing offer
│   ├── noise/                   # noise control
│   │   └── AncService.qml, AncPanel.qml, ChatEnds.qml, Anc.js, AncSnapshot.js
│   ├── wear/                    # pause on removal (Sony)
│   │   └── WearPause.qml, WearHeadset.qml, HeadsetStreams.qml, Wear.js
│   └── common/                  # shared by every feature
│       ├── Prefs.qml            # settings, shared by every surface
│       ├── OrbitIpc.qml         # the `dms ipc call orbitBluetooth` commands, one call each on the owning service
│       ├── Address.js                                    # address forms and BlueZ device path, one definition (pure, tested)
│       ├── Guide.js, GuideLink.qml, GitHubMark.qml       # guide links and notes (value 10)
│       ├── PictureService.qml, Pictures.js               # real device pictures (opt-in)
│       └── SoundFx.qml, UninstallSweep.qml
├── anc/
│   ├── orbit_anc.py             # noise-control helper (JSON session)
│   ├── sdp.py                   # minimal SDP client (finds RFCOMM channels)
│   ├── protocols/               # one module per brand + shared checksums
│   └── tests/                   # unittest: frames, checksums, each brand
├── pictures/
│   ├── orbit_pictures.py        # picture lookup (Wikimedia Commons, Sketchfab)
│   └── tests/                   # unittest, no network
├── uninstall/
│   ├── orbit_uninstall.py       # erases what DMS keeps once Orbit is removed
│   └── tests/                   # unittest, on fake shell files
├── tests/qml/                   # pop-up scenario, polar scope, audio facts and audio graph, control sessions, pause on removal and Listen together tests, stubs for Quickshell/DMS
├── tests/*.test.js, lib.js, run.sh  # gjs: one file per role (noise, wear, battery, card, device, pairing, common, volume, audiophile, audiograph, together, centre, sun, scene), the shared loader, the runner
├── shaders/                     # .frag sources, compiled .qsb, build.sh
├── scripts/
│   ├── gen_sounds.py            # synthesizes sounds/*.wav
│   └── preview/                 # offscreen renderer: shot.qml (modes), mock/ (devices, state, route, wallpaper), imports/ (mock services)
├── screenshots/                 # images used by the docs
├── sounds/
└── docs/GUIDE.md                # user guide
```

## Tests

```sh
(cd anc && python3 -m unittest discover -s tests -t .)   # noise-control protocols
(cd pictures && python3 -m unittest discover -s tests -t .)   # picture lookup, without network
(cd uninstall && python3 -m unittest discover -s tests -t .)  # uninstall sweep, on fake shell files
sh tests/qml/run.sh                                       # new-device pop-up scenario, polar scope, audio facts, control sessions, pause on removal, Listen together session and center (Qt 6); one test: sh tests/qml/run.sh centreLoop
sh tests/run.sh                                          # every pure .js module, one test file per role (or gjs tests/volume.test.js for one)
```

Run them all before every commit. A new headphone brand needs a module in `anc/protocols/` and tests in `anc/tests/`.

## Screenshots, shaders and sounds

```sh
scripts/preview/render.sh          # PNG screenshots (mock devices, no real data)
scripts/preview/record.sh          # all GIFs (needs ffmpeg)
scripts/preview/record.sh beam     # one of: beam, gauge, focus, connect
shaders/build.sh                   # recompile after editing shaders/*.frag (needs qsb)
python3 scripts/gen_sounds.py      # regenerate sounds/*.wav
```

The compiled `.qsb` files are committed, so users do not need `qsb`. The shader renders need the OpenGL backend, which `render.sh` sets.

## Performance rules

Orbit must cost nothing while nobody looks at it. Keep these rules when changing the code:

- **Never loop a QML animation** (`NumberAnimation` with `loops`, `Animator`, a running `FrameAnimation`). In Qt, any running animation makes *every* shell window (bars, wallpaper) redraw at the display rate. Use a plain `Timer` (30 Hz, 60 Hz while a comet turns or a card is open) and compute effects from one effects clock.
- **Display-synced frames only for gestures**, and only until the motion has calmed down.
- **Paint backgrounds once** (stars, nebulae, veil); effects only move fixed geometry.
- **Hidden means frozen**: the desktop orbit is asleep while windows fill its screen, even with *Ambient motion* on (`Cover.js`, pure, tested, reads niri's layout from DMS's `NiriService`).
- **Run nothing while hidden**: discovery, polling and the noise-control helper only run while a view is open (the exceptions are the new-device pop-up's 8 s background scan, with its battery and audio rules, and the one idle control connection that *Pause when you take the headset off* keeps for a Sony headset with a wearing sensor: no timer, the headset reports by itself); everything pauses while the session is locked or the monitors are off.
- **Load on demand**: the multimedia backend only when sounds are enabled.
- **Listen together holds nothing at rest**: the copies are passive, never fall back to another output and no stream, silence or keep-alive is ever opened toward a member (a multipoint headset must be free to hand over to a phone). Check in an isolated PipeWire server (a scratch `PIPEWIRE_RUNTIME_DIR`, never the live one): with nothing playing every member output, copy and filter must be `idle`; a non-passive copy keeps the outputs `running`. Kill the shell stand-in with `kill -9` and every copy and node must be gone within two seconds.
- **Honor DMS Reduce motion.**

Measure before and after a change: CPU of the whole shell, % of one core, each state for 10 s, same machine (240 Hz screen). DMS alone: 0.7 %.

| State | 1.4.1 | 1.4.0 | 1.3.2 |
| --- | --- | --- | --- |
| Idle (bar icon, view closed) | 0.5 | 0.7 | 0.5 |
| View open, left alone | 3.8 | 3.6 | 3.7 |
| View open while scanning | 5.2 | 10.1 | 8.0 |
| Desktop widget, *Ambient motion* on | 9.2 | 8.8 | 8.5 |

Short runs are noisy (about ±2 points while scanning).

## Conventions

- **Language**: code, comments, UI and docs in English.
- **Comments**: every file starts with a short comment saying what it is and why.
- **Privacy**: no telemetry, ever. No network access except the opt-in, off-by-default **Real device pictures** (model names only). Nothing written to disk except settings through DMS and that feature's pictures cache.
- **Settings**: every option works out of the box; descriptions stay one short line; options that cost battery are marked ⚡.
- **Docs**: user-facing changes go in `docs/GUIDE.md` (and the README if they change installation or the basics), plus an entry in `CHANGELOG.md`.

## Releasing a version

1. Bump `version` in `plugin.json` ([Semantic Versioning](https://semver.org/)).
2. Move the `Unreleased` entries of `CHANGELOG.md` under the new version and date.
3. Refresh screenshots if the look changed (`scripts/preview/`).
4. Run the tests, commit, then tag: `git tag v1.10.1 && git push --tags`.
