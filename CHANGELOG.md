# Changelog

All notable changes to Orbit Bluetooth are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## 1.10.0 - 2026-10-01

### Added

- **New headphones pop-up**: put headphones, earbuds or a speaker in pairing mode and a tall pairing sheet unfolds from the right end of the bar, even with Orbit closed. The device falls out of the bar along a comet trail into an orbit, floats above a planet's horizon and tilts towards the pointer, among twinkling stars and the odd shooting star. Two looks: deep space with a dark DMS theme, stratosphere with a light one; any palette works, its accent is brightened or deepened until it reads well.
- In the sheet: what you get (noise control, rated battery life, earbuds), **Connect** with live *Pair → Connect → Ready* steps, a star burst and a filling battery ring when connected, then the noise-control modes; rename the device before connecting; **Later** snoozes it 10 minutes, **Don't offer again** never offers it again; several devices stack with a "+1". <kbd>Enter</kbd> and <kbd>Escape</kbd> work while the pointer is on it. It folds back into the bar after a connection.
- Only named, unpaired audio devices; never while a window is full screen or the screen is locked.
- Background scan for it: 8 s every minute (**Background scan**), skipped while Bluetooth audio is connected (scanning makes it stutter), on battery below **No background scan below** (30 %), and while the screen is off. Turn it off with **Pop-up for new headphones**.
- **Forget** in the right-click menu (click again to confirm). Forgetting a device also clears its icon choice and its *Don't offer again* mark.
- **Offer ignored devices again** button in the settings.
- IPC: `newDeviceDemo` shows the sheet with a made-up headset, `newDeviceStatus` tells whether the background scan runs or why not.
- QML scenario tests for the pop-up's logic (`tests/qml/run.sh`), with stubs for Quickshell and the DMS services; `scripts/preview/sheet.qml` renders the sheet with six test palettes, or records it.

### Changed

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
