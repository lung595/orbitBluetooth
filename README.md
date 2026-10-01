<div align="center">

# Orbit Bluetooth

**A planetary Bluetooth manager for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).**

Your machine sits at the center of a small star system and nearby devices float around it.
Drag a device to the center to connect it, pull it away to disconnect it.

![Orbit view in the Control Center](screenshots/orbit.png)

</div>

| Drag to connect | Energy beam while charging |
| --- | --- |
| ![Dragging earbuds to the inner ring connects them](screenshots/connect.gif) | ![A beam of energy flowing from the host to a charging headset](screenshots/beam.gif) |

> **New in 1.4.1:** device names stay readable everywhere, even on a pale or busy wallpaper. See the [changelog](#changelog).

## Contents

- [Getting started](#getting-started)
- [Features](#features)
- [Usage](#usage)
- [Settings](#settings)
- [Command line and keybindings](#command-line-and-keybindings)
- [Troubleshooting](#troubleshooting)
- [Privacy](#privacy)
- [Performance](#performance)
- [Development](#development)
- [Changelog](#changelog)
- [Roadmap](#roadmap)
- [Credits](#credits)
- [License](#license)

## Getting started

### Requirements

| Dependency | Version | Needed for |
| --- | --- | --- |
| DankMaterialShell | 1.6.0 or newer | Everything |
| Quickshell | 0.3 or newer (ships with DMS) | Everything |
| BlueZ | Any recent version, adapter powered on | Everything |
| UPower | Any | *Optional*: real charging states for devices that report one |
| Python 3 | Standard library only | *Optional*: headphone noise control |

### 1. Install

**From the plugin browser** (recommended): open **Settings → Plugins**, search for **Orbit Bluetooth** and click *Install*.

**From a terminal:**

```sh
dms plugins install orbitBluetooth
```

**Manually:**

```sh
git clone https://github.com/lung595/orbitBluetooth ~/.config/DankMaterialShell/plugins/orbitBluetooth
```

Then click **Settings → Plugins → *Scan for plugins***. No restart is needed.

### 2. Enable

In **Settings → Plugins**, turn **Orbit Bluetooth** on.

### 3. Add a widget

> [!IMPORTANT]
> **Orbit Bluetooth does not replace the built-in DMS Bluetooth widget.** Installing and enabling it is not enough: nothing shows up until you **add at least one of its widgets** yourself. You can add one, two or all three.

| Where | How to add it | What you get |
| --- | --- | --- |
| **Control Center** | Open the Control Center, enter **edit mode** and add the **Bluetooth** tile from *Orbit Bluetooth* | A Bluetooth tile; its arrow expands the orbit inline |
| **Bar** | **Settings → Appearance → DankBar Layout**, add **Orbit Bluetooth** to any section | A pill with connected devices; click it for the orbit popout |
| **Desktop** | **Settings → Desktop Widgets**, add **Orbit Bluetooth**, then move and resize it | A frameless orbit on your wallpaper (default 440 × 380) |

> [!TIP]
> To avoid two Bluetooth tiles in the Control Center, remove the built-in one in edit mode once Orbit's tile is in place.

### 4. First steps

1. **Open the orbit** from the widget you added. Discovery starts on its own.
2. **Drag a device into the inner ring** to pair and connect it; drag it back out to disconnect.
3. **Click a device** for its detail card (battery, charging, noise control), **right-click** it for a menu, **drop it into the black hole** to hide it.

## Features

- Works in the **Control Center**, the **bar** and as a **desktop widget**.
- **Drag to connect** with a magnet snap, elastic tether to disconnect.
- **Live charging view**: magnetic charging beam, time to full, speed, session chart.
- **Earbuds trio**: the case and both buds in their own mini orbit, each with its battery.
- **Noise control** for 13 headphone brands.
- **Battery gauge** colored by level (red → amber → gold → lime → aqua).
- **28 built-in line-art device icons**, matched by name, or your own pictures.
- **Light and dark** DMS themes; the sky always stays night.
- **Lightweight and private**: idle scenes draw no frames at all, nothing leaves your machine.

## Usage

### Widgets

**Control Center**

- Click the tile icon to turn Bluetooth on or off.
- Click the arrow to expand the orbit view inline.
- The view stays compact and grows while a detail card is open, so the whole card fits without scrolling.

**Bar**

- Left click opens the orbit view in a popout, which grows while a detail card is open.
- Right click turns Bluetooth on or off.
- Connected devices appear as tiny glyphs in the pill.

**Desktop**

- It is frameless: a smoky veil tinted with your theme accent fades into the wallpaper. Tune it with **Desktop widget → Backdrop**.
- It stays frozen until the pointer is over it. The scan chip only shows while you use it.
- The detail card closes by itself when the pointer leaves or another window takes focus.

![Frameless orbit on the desktop](screenshots/desktop.png)

### Gestures

| Gesture | Result |
| --- | --- |
| Drag a device inside the inner ring | Magnet snap; release to pair and connect |
| Drag a connected device outward | Elastic tether; release to disconnect |
| Hover a connected device, click × | Disconnect (when *Quick disconnect button* is on) |
| Click a device | It flies onto a detail card |
| Right-click a device | Menu: connect or disconnect, noise-control modes, hide |
| Drag a device into the black hole | It is swallowed and hidden (it stays connected) |
| Click the black hole | List of hidden devices, with **Show** to bring one back |
| Click the center, or the **Scan** chip | Start discovery |
| <kbd>Esc</kbd>, click outside, or <kbd>←</kbd> | Step back: menu, hidden list, then detail card |

Connected devices orbit on the inner ring, drawn 15 % smaller so the ring stays airy; the others float in the outer field. While a connection is being made, a small comet circles the device. Named devices are ranked before devices that only expose a MAC address.

### Example: connecting new headphones

1. Put the headphones in pairing mode.
2. Open the orbit view. Discovery starts on its own (click **Scan** if *Scan automatically* is off) and the chip reads **Scanning**.
3. The headphones appear in the outer field. Drag them toward the center: the ring lights up and pulls them in.
4. Release. They pair, connect and settle on the inner ring with their battery arc.

![Dragging earbuds toward the center: magnet snap, connecting, connected](screenshots/connect.gif)

### The detail card

Click any device to open it: its glyph flies onto the card.

![A device flying onto its detail card](screenshots/focus.gif)

The card shows:

- **Name, type and state** (connected, paired, available). **Click the name to rename** a paired device: <kbd>Enter</kbd> saves, <kbd>Esc</kbd> cancels, and an empty name gives the device its own name back. The new name is the Bluetooth alias, so every app shows it; the icon, noise control and battery estimates still follow the device's own name.
- **Connection time and battery level.**
- **Actions**: change icon, connect or disconnect, hide, forget (asks twice).
- **Battery gauge, session chart and stats** (see [Charging and battery](#charging-and-battery)).
- For earbuds, the **trio**; for supported headphones, **noise control**.

### Earbuds: the trio

Earbuds that report their parts (case, left, right) get a small orbit of their own in the detail card: the case in the middle, one bud at each end, each with its battery bar. A bud charging in the case moves closer to it, and field lines join the case to the bud.

| Earbuds trio | Buds charging in their case |
| --- | --- |
| ![Case between the two earbuds, one battery bar each](screenshots/earbuds.png) | ![Both earbuds docked, beams flowing from the case](screenshots/earbuds-dock.png) |

The drawings are chosen by name (stem or pebble buds; tall, wide or pebble case; white or graphite). To use your own photos, put them in the **Custom images folder** as `<name> case.png`, `<name> left.png` and `<name> right.png` (the left picture is mirrored when there is no right one).

### Hiding devices: the black hole

A small black hole drifts in the outer field. Drag a device you never use into it (or right-click it and pick **Hide**): it spirals in and disappears from the orbit and the bar, but **stays connected**. Click the black hole to see what it holds and **Show** to bring a device back. With nothing hidden, clicking it explains what it is for.

| Hidden devices | Right-click menu |
| --- | --- |
| ![Hidden devices listed by the black hole](screenshots/hidden.png) | ![Right-click menu of a headset](screenshots/menu.png) |

The black hole bends the starfield around it like a gravitational lens. Pick its look in **Look → Black hole**:

- **Black hole** (default): a realistic one in the spirit of *Interstellar*, with a thin accretion disk seen almost edge-on and a photon ring, tinted by your theme.
- **Three-dimensional shadow of a four-dimensional bubble**: a wireframe tesseract turning inside the horizon (a nod to the hypercube in *Adventure Time*).

Both are a single small shader that only moves while the scene is already animating. On the desktop widget the lens is off, because the sky there is see-through.

### Noise control

Supported headphones get a mode selector in their detail card, a halo in the orbit (solid: cancelling, dotted: ambient) and the modes in their right-click menu. Only what the model supports is shown: noise cancelling, adaptive, ambient (transparency) and off, the ambient level, voice focus, conversation detection and the left/right/case batteries.

![Noise control in the detail card](screenshots/noise-control.png)

| Brand | Models | Tested on hardware |
| --- | --- | --- |
| Sony | WH-1000XM3 to XM6, WF-1000XM3 to XM5, LinkBuds, WH-CH720N, ULT WEAR… | Yes (WH-1000XM6) |
| Apple | AirPods Pro, AirPods 4, AirPods Max, Beats with noise control | No |
| Samsung | Galaxy Buds, Buds+, Live, Pro, Buds2 to Buds4 (Pro, FE, Core) | No |
| Bose | QC35 / QC35 II, NC700, QC45, QC Ultra, QC Headphones | No |
| Nothing / CMF | Ear (1), (2), (3), (a), Headphone (1), CMF Buds and Headphone Pro | No |
| Anker Soundcore | Life Q30/Q35, Liberty Air 2 Pro, Space Q45, others with the common layout | No |
| Huawei / Honor | FreeBuds 4i to 6i, Pro to Pro 5, SE 4, Studio, FreeLace Pro, FreeClip, Honor Earbuds 2 | Yes (FreeBuds Pro) |
| Oppo / OnePlus / realme | realme Buds T200 and Air6 Pro; other Enco/realme/OnePlus models are probed | No |
| Xiaomi | Redmi Buds 3 Pro, 4 Active, 5 Pro, 6 (Pro, Lite, Active), 8 Active | No |
| EarFun | Air Pro 4, Air S, Free Pro 3 | No |
| Moondrop | Space Travel 2, Space Travel 2 Ultra | No |
| Haylou | S35 ANC (mode can be set, not read) | No |
| 1MORE | SonoFlow, SonoFlow SE | No |

Untested brands follow their protocol documentation byte for byte and are covered by unit tests, but have not met a real headset yet. If yours does not answer, it simply shows no noise control; reports are welcome. **Not supported** (no reliable public documentation): Jabra, JBL, Sennheiser, Marshall, Google Pixel Buds.

**How it works.** QML cannot open a Bluetooth socket, so a small helper (`anc/orbit_anc.py`, Python standard library only) talks to the headset. The **Engine** setting decides when it runs:

- **On demand** (default): only while an Orbit view is open, or for the second it takes to apply a command. Plugging in or unplugging the charger shows up at once, with no polling. Nothing runs once the view is closed.
- **Always connected**: one session per connected headset, so changes made with the headset's own buttons show up live (a small idle process).

Noise control only talks to **paired** headsets: opening a channel to a device that is connected but not paired would make it drop and reconnect. Some headsets cannot report every mode (the WH-1000XM6 reads "noise cancelling" and "off" the same way); Orbit then keeps the last mode it set or saw.

### Charging and battery

A charging device gets a lightning badge, a breathing battery arc and a beam of energy from your machine: faint field lines that fan out into a spindle and meet again at the device, like iron filings around a magnet. Under its name you read the level and the time to full, for example `54% · 2h08`.

| Charging in orbit | Charging details |
| --- | --- |
| ![An energy beam flowing from the host to a charging headset](screenshots/charging.png) | ![Detail card with gauge, ETA and stats](screenshots/detail-charging.png) |

The detail card adds:

| Field | Example | Meaning |
| --- | --- | --- |
| Readout | `54%  ≈ 2 h 08 to full` | Level (in its color) and time to full |
| **READY AT** | `≈ 15:45` | Clock time when it should be full |
| **SPEED** or **POWER** | `+29 %/h` or `4.5 W` | Charge rate (power when the device reports it) |
| **+16% IN** | `34 min` | Gained during this charge, and for how long |
| **HEALTH** | `92%` | Battery health, when reported |
| Chart | Step line | Level over the current connection |

When not charging, the readout shows the time left and the tiles switch to **EMPTY AT** and **DRAIN**. The gauge is a matte pill colored by level, with streaks that flow while charging and a mark at 80 %.

![Charging gauge: level colored by the aurora ramp, streaks flowing](screenshots/gauge.gif)

**Where the numbers come from.** Bluetooth only reports a percentage, so Orbit combines two sources, and the card's footnote always says which one is in use:

1. **Reported by the device.** Headsets with noise control report their own charging state through the helper (per part for earbuds). Devices with a kernel battery driver (most game controllers, Logitech peripherals…) publish a real state through UPower, matched to their Bluetooth address by reading `HID_UNIQ` from sysfs once per device.
2. **Estimated from level changes.** Otherwise, charging is inferred from a rising level. Time to full accounts for the usual lithium-ion slowdown past 80 %. Estimates are shown with `≈`, appear after a few level changes (usually a few minutes) and refine over time.

### Device icons

Icons are matched by name patterns, for example every `WH-1000XMx`, `AirPods Max`, `MX Master`, `Galaxy Buds`, `G703` or `DualSense`. The BlueZ device class breaks ties, so a `G733` headset is never drawn as a mouse.

- **Change one**: open its detail card and click the palette button. The choice is remembered per device; **Reset device icons** in the settings clears all choices.
- **Use your own artwork**: set **Custom images folder** and add PNGs named after each device's own name (a rename does not change it). Characters not allowed in file names (`/ \ : * ? " < > |`) are replaced by `_`.

```
~/Pictures/bluetooth/
├── WH-1000XM6.png
├── Xbox Wireless Controller.png
└── MX Master 3S.png
```

### Light theme

Orbit keeps its night sky in every theme. With a light DMS theme, the devices and your machine turn into white discs, the cards into a soft off-white with dark ink, and the accents on the sky are lifted to a lighter shade so they stay readable.

| Orbit, light theme | Detail card, light theme |
| --- | --- |
| ![White devices on the night sky](screenshots/light.png) | ![Soft off-white detail card](screenshots/light-detail.png) |

## Settings

Open **Settings → Plugins → Orbit Bluetooth**. Options marked ⚡ use more battery.

| Section | Setting | Default | Description |
| --- | --- | --- | --- |
| Orbit | Devices in orbit | 8 | Connected devices always show; the rest are ranked by pairing and name |
| | Always show names | On | Otherwise names appear on hover |
| | Show unnamed devices | Off | Devices that only expose a MAC address |
| | Quick disconnect button | Off | An × on connected devices, on hover |
| | Center device | Automatic | Icon of this machine (laptop or desktop is detected) |
| Scanning | Scan automatically | On | Start discovery when a view opens; otherwise click the center |
| | Scan duration | 45 s | 20 s, 45 s, 90 s or *While open* ⚡ |
| Headphones | Noise control | On | Supported headphones (needs Python 3) |
| | Engine | On demand | *Always connected* ⚡ shows headset button presses live |
| Desktop widget | Displays | All | Which displays show the desktop widget |
| | Backdrop | 72 % | Depth of the veil behind the orbit |
| | Ambient motion | Off | Keep orbits moving when the pointer is away ⚡ |
| Look | Black hole | Black hole | Realistic, or the three-dimensional shadow of a four-dimensional bubble |
| | Shooting stars | On | A rare meteor (every 12–32 s); one passing the black hole bends toward it, or is swallowed |
| | Stars | Normal | Low, Normal or High |
| | Custom images folder | — | PNG files that replace built-in icons |
| Sounds | Sounds | Off | Short cues on snap, connect and disconnect |
| | Volume | 60 % | |

Two buttons at the end reset custom device icons and bring back every hidden device.

DMS's *Reduce motion* setting is respected.

## Command line and keybindings

```sh
dms ipc call orbitBluetooth anc nc       # nc, ambient, off or adaptive (first supported headset)
dms ipc call orbitBluetooth ancCycle     # next noise-control mode
dms ipc call orbitBluetooth ancStatus    # current noise-control state (JSON)
dms ipc call orbitBluetooth hidden       # list hidden devices
dms ipc call orbitBluetooth unhideAll    # bring every hidden device back
```

Bind them to keys in your compositor, for example:

**niri** (`~/.config/niri/config.kdl`):

```kdl
binds {
    Mod+N { spawn "dms" "ipc" "call" "orbitBluetooth" "ancCycle"; }
}
```

**Hyprland**:

```ini
bind = SUPER, N, exec, dms ipc call orbitBluetooth ancCycle
```

## Troubleshooting

<details>
<summary><b>I installed the plugin but nothing changed.</b></summary>

Orbit Bluetooth does not replace the DMS Bluetooth widget: add one of its widgets yourself (Control Center tile, bar or desktop). See [Add a widget](#3-add-a-widget).
</details>

<details>
<summary><b>Earbuds keep disconnecting after a few seconds.</b></summary>

Some earbuds (FreeBuds among others) ask you to confirm a pairing code. Orbit shows DMS's pairing dialog for them; accept it once and they stay connected.
</details>

<details>
<summary><b>No devices appear while scanning.</b></summary>

Make sure the device is in pairing mode. Devices that only broadcast a MAC address are hidden unless **Show unnamed devices** is on, and the orbit keeps at most **Devices in orbit** entries.
</details>

<details>
<summary><b>A device charges but shows no lightning.</b></summary>

It reports no charging state and its level has not risen yet. The estimate starts after the first level increase.
</details>

<details>
<summary><b>Noise control does not appear.</b></summary>

The headset must be paired, connected and of a supported brand (see [Noise control](#noise-control)), and Python 3 must be installed. Close and reopen the card to retry: after an error the helper stays quiet instead of retrying in a loop.
</details>

<details>
<summary><b>A device vanished.</b></summary>

It may be in the black hole: click it, use **Show all hidden devices** in the settings, or run `dms ipc call orbitBluetooth unhideAll`.
</details>

<details>
<summary><b>The time to full looks off.</b></summary>

Estimates rely on the device's level steps. Some headsets report in 10 % steps, so the first minutes are rough and improve over time.
</details>

**Known limits:** some Sony headsets do not report charging, or drop Bluetooth while charging; this is a hardware limit.

## Privacy

- **No network access, no telemetry.**
- **One helper process**: the noise-control helper (Python, standard library) opens a local Bluetooth socket to your headset and nothing else, only while needed. Set `ORBIT_ANC_DEBUG=1` to see its raw packets on stderr; nothing is ever logged to a file.
- **Nothing written to disk by Orbit**: connection times and battery history live in memory for the current session only.
- **Files read**: only the sysfs `uevent` of kernel batteries, once each, to match them to a Bluetooth address.
- **Settings** (your choices, custom icons, the addresses and names of hidden devices) are stored by DMS with your other plugin settings.
- **Device names** you set are stored by BlueZ, like any Bluetooth alias. On the desktop, the widget only takes the keyboard while a detail card is open, so you can type a name.

## Performance

Orbit costs nothing while you are not looking at it.

- **At rest**: the desktop widget renders zero frames while idle; even the connection timers pause and catch up when the pointer comes back.
- **No looping QML animation anywhere.** In Qt, any running animation makes every shell window (bars, wallpaper) redraw at the display rate. Instead, the drift runs on a 30 Hz timer (60 Hz while a comet turns or a card is open), and every effect is computed from one effects clock. Display-synced frames are kept for gestures only, so dragging stays smooth.
- **Paused when unseen**: everything stops while the session is locked or the monitors are off.
- **Painted once**: backgrounds (stars, nebulae, veil) are static; charging effects only move fixed geometry.
- **On demand**: discovery runs only while a view is open and stops after the configured delay; the device list polls only while someone is looking; sounds load the multimedia backend only when enabled.
- **Reduce motion** is honored.

CPU of the whole shell (% of one core), each state for 10 s, on the same machine (240 Hz screen). DMS alone: **0.7 %**.

| State | 1.4.1 | 1.4.0 | 1.3.2 |
| --- | --- | --- | --- |
| Idle (bar icon, view closed) | 0.5 | 0.7 | 0.5 |
| View open, left alone | 3.8 | 3.6 | 3.7 |
| View open while scanning | 5.2 | 10.1 | 8.0 |
| Desktop widget, *Ambient motion* on | 9.2 | 8.8 | 8.5 |

Short runs are noisy (about ±2 points while scanning), and the desktop figure covers the first seconds after the widget appears.

## Development

### Project layout

```
orbitBluetooth/
├── plugin.json
├── OrbitBluetoothDaemon.qml     # connection times, battery log, UPower bridge
├── OrbitBluetoothWidget.qml     # Control Center tile, bar pill and popout
├── OrbitBluetoothDesktop.qml    # desktop widget
├── OrbitBluetoothSettings.qml   # settings page
├── components/
│   ├── OrbitScene.qml           # the scene: physics, drag, focus, chrome
│   ├── DeviceBody.qml           # one orbiting device, charging beam
│   ├── FocusCard.qml            # detail card
│   ├── BlackHole.qml            # the "Hidden" black hole (picks one of two shaders)
│   ├── HiddenCard.qml           # list of hidden devices
│   ├── OrbitMenu.qml            # right-click menu
│   ├── BatteryCard.qml          # gauge, chart and stat tiles
│   ├── StatTiles.qml            # READY AT / SPEED / HEALTH tiles
│   ├── EarbudsTrio.qml, EarbudArt.qml, Earbuds.js   # case + buds mini orbit
│   ├── EnergyBeam.qml           # magnetic field-line beam (beam.frag)
│   ├── Charge.js                # charge analysis and color ramp (pure)
│   ├── Endurance.js             # rated battery life per model (time-left estimate)
│   ├── AncService.qml, AncPanel.qml, Anc.js   # noise control (runs the helper)
│   ├── NightColors.qml, PaperColors.qml       # light-theme accents and card colors
│   └── Starfield.qml, Vignette.qml, DeviceGlyph.qml, …
├── anc/
│   ├── orbit_anc.py             # noise-control helper (stdin/stdout JSON session)
│   ├── sdp.py                   # minimal SDP client (finds RFCOMM channels)
│   ├── protocols/               # one module per brand + shared checksums
│   └── tests/                   # unittest: frames, checksums, each brand
├── tests/anc.test.js            # gjs: brand detection, modes, time left
├── shaders/                     # beam, gargantua, tesseract (.frag + compiled .qsb), build.sh
├── scripts/
│   ├── gen_sounds.py            # synthesizes sounds/*.wav (stdlib only)
│   └── preview/                 # offscreen renderer with mock services
├── screenshots/
└── sounds/
```

### Tests

```sh
(cd anc && python3 -m unittest discover -s tests -t .)
gjs tests/anc.test.js
```

### Working on the code

DMS reloads QML on save, but Qt keeps `components/` and `.js` files cached in the running shell: run `dms restart` after changing them. Set `ORBIT_ANC_DEBUG=1` in the shell's environment to see the noise-control packets.

```sh
scripts/preview/render.sh          # PNG screenshots (mock devices, no real data)
scripts/preview/record.sh          # all GIFs (needs ffmpeg)
scripts/preview/record.sh beam     # one of: beam, gauge, focus, connect
shaders/build.sh                   # recompile shaders after editing a .frag (needs Qt's qsb)
python3 scripts/gen_sounds.py      # regenerate the sounds
```

## Changelog

### 1.4.1 (2026-09-27)

- Device names are readable everywhere, even on a pale or busy wallpaper: each name glows softly in your theme's accent, and devices that are not connected fade less. On the desktop they also sit on a smoky disc.
- Desktop widget: devices are a quarter smaller, so the orbit sits lighter on the wallpaper. The panels keep their size.
- Connected devices read stronger than the others. With nothing connected, every name is lifted so the orbit stays easy to read.

### 1.4.0 (2026-09-26)

- Rename a device: click its name in the detail card. Enter saves, Escape cancels, an empty name restores the device's own name.
- A renamed device keeps its icon, noise control, earbuds look, battery estimate and custom pictures: they follow the name the device reports itself.

### 1.3.2 (2026-09-26)

- The Control Center and the bar popout are now as light as the desktop: nothing loops as a QML animation anywhere, the drift runs on a 30 Hz timer, and display-synced frames are only used while you drag a device (and until it settles). An open view at rest costs about 5–6 % of one core for the whole shell, which idles at 2–3 % on its own.
- A connection attempt no longer makes the whole shell redraw at the display rate.
- Shooting stars are rarer (every 12–32 s), always cross from the top left to the bottom right on a random path, and bend toward the black hole when they pass near it, or get swallowed and light up its ring.

### 1.3.1 (2026-09-26)

- Desktop widget truly at rest: from about 65 % of a core to about 1 % (about 3.5 % with *Ambient motion*).
- Dragging stays smooth to the very end of the motion.
- Everything pauses while the session is locked or the monitors are off; connection timers pause when nobody is looking.

### 1.3.0 (2026-09-26)

- Light theme support: the sky stays night, devices turn white, cards use a soft white.

### 1.2.2 (2026-09-26)

- Esc steps back one level (menu, hidden list, card) before closing the view.
- The quick-disconnect × is now an option, off by default: pull a device away or right-click it instead.
- Clicking the center only reacts on its inner 70 %, never over a device.
- Settings grouped into short sections, with a note on the options that use more battery.
- Pick the screens of the desktop widget from Orbit's settings.
- The machine in the center is 15 % smaller.

### 1.2.1 (2026-09-26)

- Charging beam redrawn as thin magnetic field lines.
- Charging earbuds move closer to the case, with their battery bar.

### 1.2.0 (2026-09-26)

- Earbuds trio: the case and both buds in their own mini orbit, each with its battery, and a beam to the bud that charges.
- Live charging state while a view is open (headset session instead of a one-off read).
- DMS's pairing dialog is shown for devices that ask for a code (fixes endless disconnects).
- The Control Center tile grows to the exact height of the open card.

### 1.1.1 (2026-09-26)

- Detail card polish: symmetric spacing, a mode pill that hugs its content.
- Noise control no longer loses the final state or flashes back to the previous mode.

### 1.1.0 (2026-09-26)

- Noise control for 13 headphone brands (tested on Sony and Huawei).
- The black hole: drag a device into it to hide it, click it to list and bring devices back; two looks, realistic or the three-dimensional shadow of a four-dimensional bubble (a nod to *Adventure Time*).
- Right-click menu, a comet while a device connects, depth on the ring of connected devices.
- Battery time left from the moment a device connects.

### 1.0.0 (2026-09-25)

- First release: the planetary scene, drag to connect, the detail card, Control Center + bar + desktop, 28 device icons, sounds, and an option to scan only on demand.

## Roadmap

Ideas, not promises, and no dates. Anything that would need the network or send data somewhere is out of scope.

- **Easier to read code**: split the largest files (`OrbitScene.qml`, `DeviceBody.qml`) by role, without changing behavior.
- **More headphones tested on real hardware**: only Sony and Huawei have been tested so far; reports for other brands are welcome.
- **Distance from the signal strength**, once Quickshell exposes it (it does not in 0.3.1).
- **Not planned**: firmware updates, which usually need the vendor's app and the network.

## Credits

- The noise-control protocols were written from the public documentation and reverse-engineering notes of these projects (protocols reimplemented, no code copied): Gadgetbridge, SonyHeadphonesClient (mos9527), XMDeck, LibrePods, MagicPodsCore, GalaxyBudsClient, based-connect, bosectl, OpenSCQ30, OpenFreebuds, EarA-linux, earctl and cmfctl. SAFER+ follows the Bluetooth Core specification.
- Built on [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) and [Quickshell](https://quickshell.org).

## License

[MIT](LICENSE) © lung595
