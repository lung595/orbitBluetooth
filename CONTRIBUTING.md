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

`components/` has one folder per feature: `scene/`, `device/`, `card/`, `volume/`, `pairing/`, `noise/` and `common/`. A file imports its neighbours directly and another feature's folder by path (`import "../card"`).

Every surface shows the same scene, `components/scene/OrbitScene.qml`. It handles drag and focus and opens the cards (`card/FocusCard.qml`, `card/HiddenCard.qml`, `scene/OrbitMenu.qml`); `scene/OrbitPhysics.qml` moves every device (`device/DeviceBody.qml`) in one step per frame, with the maths in `scene/Physics.js` (pure, tested). Its chrome lives in `pairing/OfferCard.qml`, `scene/ScanChip.qml` and `scene/AdapterNotice.qml`.

Logic that can be tested lives in **pure `.js` files** with no QML: `card/Charge.js` (charge analysis), `card/Endurance.js` (rated battery life), `scene/Physics.js` (springs, slots, clearances), `noise/Anc.js` (noise-control decisions), `volume/Polar.js` (the scope's geometry and sound picture), `volume/Route.js`, `volume/Steps.js` and `volume/Keys.js` (volumes), `common/Address.js` (the shapes of a Bluetooth address and of its BlueZ path, checked before any command), `device/Earbuds.js`, `device/DeviceCatalog.js` and `device/Glyphs.js` (icons).

**The volume scope** (detail card, pop-up, Dank Island) runs one `cava` and computes one picture for every screen that shows it: `volume/TwoLevels.qml` holds an output's two levels, its `ScopeFeed.qml` (cava, only while someone looks) and its `ScopeModel.qml` (points, rays or waves, moved by cava's frames, fading alone, then stopped). `PolarScope.qml` draws the half circles and `PolarVisual.qml` only paints the shared picture at its own size.

**Noise control** is the only part outside QML: QML cannot open a Bluetooth socket, so `components/noise/AncService.qml` runs `anc/orbit_anc.py`, which speaks each vendor protocol (`anc/protocols/`, one module per brand) through a JSON session on stdin/stdout. `anc/sdp.py` finds the RFCOMM channel.

**New headphones pop-up**: `components/pairing/NewDeviceWatch.qml` (in the daemon) runs the short background scan, picks what to offer (`Offer.js`, pure) and drives pairing; `NewDeviceWindow.qml` is its layer-shell window and `PairingSheet.qml` the sheet itself (two skins, colours from `Palette.js`), which `scripts/preview/sheet.qml` renders offscreen with six test palettes, or records frame by frame. Before a new device is trusted, `ProfileCheck.qml` reads its Bluetooth profiles with `busctl` and `Guard.js` (pure, tested) decides: a non-input device that can also send key presses stays blocked until the user confirms. Never trust a device from its name alone.

**Guided, never blocked**: `components/common/Guide.js` (pure, tested) builds the guide links and the short notes (`connectNote`); `scene/OrbitNote.qml` shows them at the bottom of the sky and `common/GuideLink.qml` is the GitHub mark (drawn by `common/GitHubMark.qml`) that opens a guide section on click. A new refusal gets a note and an anchor that exists in `docs/GUIDE.md` (the tests check it). Every new Quickshell import or service used by a component needs its mock in `scripts/preview/imports/`, or the previews break.

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
│   │   ├── OrbitBackdrop.qml, OrbitWorld.qml, OrbitCore.qml, OrbitHint.qml  # sky, orbits and bodies, host core, drag hint
│   │   ├── OrbitPhysics.qml, Physics.js  # one motion step for every body (Physics.js pure, tested)
│   │   ├── Cover.js             # is the desktop hidden behind windows? (pure, tested)
│   │   ├── ScanChip.qml, AdapterNotice.qml, OrbitNote.qml, OrbitMenu.qml  # chrome: scan chip, Bluetooth off, notes, right-click menu
│   │   ├── BlackHole.qml, RingWave.qml   # the "Hidden" black hole (two shaders), the connected ring's wave
│   │   └── Starfield.qml, Vignette.qml, NightColors.qml
│   ├── device/                  # one orbiting device
│   │   ├── DeviceBody.qml, BodyFace.qml, BodyPointer.qml, QuickDisconnect.qml  # body (state, motion), its look, its mouse, its close button
│   │   ├── ConnectingFx.qml, LockRing.qml, EnergyBeam.qml, LabelGlow.qml  # connection comet and rings, lock ring, charging beam (shaders/beam.frag), label glow
│   │   ├── BodyTether.qml, ChargeBeam.qml, BodyArcs.qml, BodyLabel.qml  # tether to the core, charge beam, rings (noise control, battery), caption
│   │   ├── DeviceGlyph.qml, DeviceCatalog.js, Glyphs.js   # device icons
│   │   └── EarbudsTrio.qml, EarbudArt.qml, Earbuds.js     # case + buds mini orbit
│   ├── card/                    # the detail and hidden-devices cards
│   │   ├── FocusCard.qml, PlanetControl.qml  # detail card; focused glyph: click to mute, wheel for the volume
│   │   ├── BatteryCard.qml, StatTiles.qml    # gauge, chart and READY AT / SPEED / HEALTH tiles
│   │   ├── Charge.js, Endurance.js           # battery analysis (pure, tested)
│   │   └── HiddenCard.qml, PaperColors.qml   # hidden devices; light-theme colors
│   ├── volume/                  # the two volumes and the scope
│   │   ├── TwoLevels.qml        # an output's two volumes, its cava and its picture (base of CardVolume, VolumeOverlay)
│   │   ├── CardVolume.qml, Volume.js         # the detail card's two volumes and tick (Volume.js pure, tested)
│   │   ├── VolumeOverlay.qml, VolumePopup.qml, IslandFace.qml  # volume pop-up per screen, its face inside Dank Island
│   │   ├── VolumeStrip.qml      # menus: the two volumes folded into a thin line, unfolds on click
│   │   ├── ScopeScreen.qml      # the dark scope screen shared by card, pop-up and island
│   │   ├── PolarScope.qml, PolarVisual.qml, Polar.js   # half circles, moons, the painted picture (Polar.js pure, tested)
│   │   ├── PolarGrid.qml, PolarReadouts.qml  # the scope's screen (grid), icons and numbers
│   │   ├── ScopeFeed.qml, ScopeModel.qml     # live stereo bands from cava; the picture they move, once for every screen
│   │   ├── AudioRoute.qml, RouteDevice.qml, Route.js   # the two levels of each output: PC filter, absolute volume, IPC
│   │   └── VolumeKeys.qml, Keys.js, Steps.js # volume keys through `dms keybinds`, smart steps (pure, tested)
│   ├── pairing/                 # new device pop-up and pairing offer
│   │   ├── NewDeviceWatch.qml, Offer.js, Guard.js, ProfileCheck.qml  # background scan, what to offer, the input-device guard
│   │   ├── NewDeviceWindow.qml, PairingSheet.qml, Palette.js  # the window and the sheet (the card, its keys and its parts)
│   │   ├── PairingSkin.qml, PictureColor.qml, PairingMotion.qml  # the two skins' colours, the picture's colour, the sheet's clock and entrance
│   │   ├── PairingSky.qml, PairingPlanet.qml, PairingHeader.qml  # the scene behind the device, status and close button
│   │   ├── PairingStage.qml, PairingIdentity.qml, PairingMiddle.qml, PairingButton.qml, Light.qml  # device, name and subtitle, tiles/steps/quick actions, actions, round light
│   │   └── OfferCard.qml        # the scene's pairing offer
│   ├── noise/                   # noise control
│   │   └── AncService.qml, AncPanel.qml, Anc.js
│   └── common/                  # shared by every feature
│       ├── Prefs.qml            # settings, shared by every surface
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
├── tests/qml/                   # pop-up scenario and polar scope tests, stubs for Quickshell/DMS
├── tests/anc.test.js            # gjs: every pure .js module (noise control, battery, volumes, notes…)
├── shaders/                     # .frag sources, compiled .qsb, build.sh
├── scripts/
│   ├── gen_sounds.py            # synthesizes sounds/*.wav
│   └── preview/                 # offscreen renderer with mock services
├── screenshots/                 # images used by the docs
├── sounds/
└── docs/GUIDE.md                # user guide
```

## Tests

```sh
(cd anc && python3 -m unittest discover -s tests -t .)   # noise-control protocols
(cd pictures && python3 -m unittest discover -s tests -t .)   # picture lookup, without network
(cd uninstall && python3 -m unittest discover -s tests -t .)  # uninstall sweep, on fake shell files
sh tests/qml/run.sh                                       # new-device pop-up scenario and polar scope (Qt 6)
gjs tests/anc.test.js                                     # every pure .js module: noise control, battery, physics, volumes, scope
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
- **Run nothing while hidden**: discovery, polling and the noise-control helper only run while a view is open (the one exception is the new-device pop-up's 8 s background scan, with its battery and audio rules); everything pauses while the session is locked or the monitors are off.
- **Load on demand**: the multimedia backend only when sounds are enabled.
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
