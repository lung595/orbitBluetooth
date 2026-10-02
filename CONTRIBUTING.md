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

Every surface shows the same scene, `components/OrbitScene.qml`. It integrates the physics of every device (`DeviceBody.qml`) in one pass per frame, handles drag and focus, and opens the cards (`FocusCard.qml`, `HiddenCard.qml`, `OrbitMenu.qml`); its chrome lives in `OfferCard.qml`, `ScanChip.qml` and `AdapterNotice.qml`.

Logic that can be tested lives in **pure `.js` files** with no QML: `Charge.js` (charge analysis), `Endurance.js` (rated battery life), `Anc.js` (noise-control decisions), `Earbuds.js`, `DeviceCatalog.js` and `Glyphs.js` (icons).

**Noise control** is the only part outside QML: QML cannot open a Bluetooth socket, so `components/AncService.qml` runs `anc/orbit_anc.py`, which speaks each vendor protocol (`anc/protocols/`, one module per brand) through a JSON session on stdin/stdout. `anc/sdp.py` finds the RFCOMM channel.

**New headphones pop-up**: `components/NewDeviceWatch.qml` (in the daemon) runs the short background scan, picks what to offer (`Offer.js`, pure) and drives pairing; `NewDeviceWindow.qml` is its layer-shell window and `PairingSheet.qml` the sheet itself (two skins, colours from `Palette.js`), which `scripts/preview/sheet.qml` renders offscreen with six test palettes, or records frame by frame.

**Real device pictures** (opt-in) is the only network use: `components/PictureService.qml` runs `pictures/orbit_pictures.py` (Wikimedia Commons, then Sketchfab; standard library only), and `components/Pictures.js` decides which names may be sent. Keep the list of hosts in sync between the helper header, the settings description, the README and the GUIDE.

Settings are read through `components/Prefs.qml`, a reactive view shared by every surface.

## Project layout

```
orbitBluetooth/
├── plugin.json                  # manifest: id, version, components, permissions
├── OrbitBluetoothDaemon.qml     # shared bookkeeping (see Architecture)
├── OrbitBluetoothWidget.qml     # Control Center tile, bar pill and popout
├── OrbitBluetoothDesktop.qml    # desktop widget
├── OrbitBluetoothSettings.qml   # settings page
├── components/
│   ├── OrbitScene.qml           # the scene: physics, drag, focus
│   ├── OfferCard.qml, ScanChip.qml, AdapterNotice.qml  # the scene's chrome: pairing offer, scan chip, Bluetooth off
│   ├── DeviceBody.qml           # one orbiting device, charging beam
│   ├── FocusCard.qml            # detail card
│   ├── VolumeRow.qml            # output volume slider (PipeWire)
│   ├── BatteryCard.qml          # gauge, chart and stat tiles
│   ├── StatTiles.qml            # READY AT / SPEED / HEALTH tiles
│   ├── EarbudsTrio.qml, EarbudArt.qml, Earbuds.js   # case + buds mini orbit
│   ├── BlackHole.qml            # the "Hidden" black hole (two shaders)
│   ├── HiddenCard.qml           # list of hidden devices
│   ├── OrbitMenu.qml            # right-click menu
│   ├── EnergyBeam.qml           # charging beam (shaders/beam.frag)
│   ├── AncService.qml, AncPanel.qml, Anc.js         # noise control
│   ├── Charge.js, Endurance.js  # battery analysis (pure)
│   ├── DeviceCatalog.js, Glyphs.js, DeviceGlyph.qml # device icons
│   ├── NightColors.qml, PaperColors.qml             # light-theme colors
│   ├── PictureService.qml, Pictures.js              # real device pictures (opt-in)
│   ├── NewDeviceWatch.qml, NewDeviceWindow.qml, PairingSheet.qml, PairingMiddle.qml, Offer.js, Palette.js  # new device pop-up (PairingMiddle: the card's tiles, steps and quick actions)
│   ├── Prefs.qml                # settings, shared by every surface
│   └── Starfield.qml, Vignette.qml, LabelGlow.qml, SoundFx.qml
├── anc/
│   ├── orbit_anc.py             # noise-control helper (JSON session)
│   ├── sdp.py                   # minimal SDP client (finds RFCOMM channels)
│   ├── protocols/               # one module per brand + shared checksums
│   └── tests/                   # unittest: frames, checksums, each brand
├── pictures/
│   ├── orbit_pictures.py        # picture lookup (Wikimedia Commons, Sketchfab)
│   └── tests/                   # unittest, no network
├── tests/qml/                   # pop-up scenario test, stubs for Quickshell/DMS
├── tests/anc.test.js            # gjs: brand detection, modes, time left
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
sh tests/qml/run.sh                                       # new-device pop-up scenario (Qt 6)
gjs tests/anc.test.js                                     # brand detection, modes, time left
```

Run both before every commit. A new headphone brand needs a module in `anc/protocols/` and tests in `anc/tests/`.

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
4. Run the tests, commit, then tag: `git tag v1.4.2 && git push --tags`.
