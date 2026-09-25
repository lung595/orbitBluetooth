# Orbit Bluetooth

A planetary Bluetooth manager for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).
Your machine sits at the center of a small star system and nearby devices float
around it. Drag a device toward the center to connect it, pull it away to
disconnect it. Charging devices receive a beam of energy from the core.

![Orbit view in the Control Center](screenshots/orbit.png)

| Drag to connect | Energy beam while charging |
| --- | --- |
| ![Dragging earbuds to the inner ring connects them](screenshots/connect.gif) | ![A beam of energy flowing from the host to a charging headset](screenshots/beam.gif) |

- Works in the **Control Center**, the **bar** and as a **desktop widget**
- Drag-to-connect with magnet snap, elastic tether to disconnect
- Live **charging** view: energy beam, time to full, speed, session chart
- Battery gauge colored by level (red → amber → gold → lime → aqua)
- 28 built-in line-art device icons, matched by name
- Idle scenes use no frames at all; nothing leaves your machine

## Gallery

| Charging in orbit | Charging details |
| --- | --- |
| ![An energy beam flowing from the host to a charging headset](screenshots/charging.png) | ![Detail card with gauge, ETA and stats](screenshots/detail-charging.png) |

| Desktop widget | Desktop widget, detail card |
| --- | --- |
| ![Frameless orbit dissolving into the wallpaper](screenshots/desktop.png) | ![Detail card on the desktop](screenshots/desktop-detail.png) |

*Screenshots and animations are rendered from mock data with
`scripts/preview/render.sh` and `scripts/preview/record.sh`.*

## Requirements

| | |
| --- | --- |
| DankMaterialShell | 1.6.0 or newer |
| Quickshell | 0.3 or newer (ships with DMS) |
| BlueZ | any recent version, adapter powered on |
| UPower | optional, gives real charging states for devices that report one |

## Installation

1. Put this folder in your DMS plugin directory, named `orbitBluetooth`:

   ```sh
   cd ~/.config/DankMaterialShell/plugins
   git clone <repository-url> orbitBluetooth
   ```

2. Open **Settings → Plugins**, enable **Orbit Bluetooth**.
3. Add the surfaces you want (next section). No restart is needed.

## Surfaces

### Control Center

Enter the Control Center edit mode and add the **Bluetooth** tile from Orbit
Bluetooth.

- Click the tile icon to turn Bluetooth on or off.
- Click the arrow to expand the orbit view inline.

### Bar

Add **Orbit Bluetooth** to any bar section.

- Left click opens the orbit view in a popout.
- Right click turns Bluetooth on or off.
- Connected devices appear as tiny glyphs in the pill.

### Desktop

Add **Orbit Bluetooth** from **Settings → Desktop widgets**, then move and
resize it like any other widget (default 440 × 380).

- It is frameless: a smoky veil tinted with your theme accent fades out into
  the wallpaper. Tune it with **Desktop backdrop**.
- It stays frozen until the pointer is over it. The scan chip only shows while
  you use it.
- The detail card closes by itself when the pointer leaves or another window
  takes focus.

## Using the orbit

| Gesture | Result |
| --- | --- |
| Drag a device inside the inner ring | Magnet snap; release to pair and connect |
| Drag a connected device outward | Elastic tether; release to disconnect |
| Hover a connected device, click × | Disconnect |
| Click a device | It flies onto a detail card |
| Click the center, or the **Scan** chip | Start discovery |
| Esc, click outside, or ← | Leave the detail card |

Connected devices orbit on the inner ring, the others float in the outer
field. Named devices are ranked before devices that only expose a MAC address.

### Example: connecting new headphones

1. Put the headphones in pairing mode.
2. Open the orbit view. Discovery starts on its own, and the chip reads
   **Scanning**.
3. The headphones appear in the outer field. Drag them toward the center;
   the ring lights up and pulls them in.
4. Release. They pair, connect, and settle on the inner ring with their
   battery arc.

![Dragging earbuds toward the center: magnet snap, connecting, connected](screenshots/connect.gif)

### The detail card

Click any device to open it: its glyph flies onto the card.

![A device flying onto its detail card](screenshots/focus.gif)

The card shows:

- name, type and state (connected, paired, available)
- connection time and battery level
- actions: change icon, connect or disconnect, forget (asks twice)
- battery gauge, session chart and stats (next section)

## Charging and battery data

A charging device gets a lightning badge, a breathing battery arc and a beam
of energy (white-hot core, iridescent shimmer, sparkles) from your machine to
it. Under its name you read the level and the time to full, for example
`54% · 2h08`.

![The charging beam, close up](screenshots/beam.gif)

The detail card adds:

| Field | Example | Meaning |
| --- | --- | --- |
| Readout | `54%  ≈ 2 h 08 to full` | Level (in its color) and time to full |
| **READY AT** | `≈ 15:45` | Clock time when it should be full |
| **SPEED** or **POWER** | `+29 %/h` or `4.5 W` | Charge rate (power when the device reports it) |
| **+16% IN** | `34 min` | Gained during this charge, and for how long |
| **HEALTH** | `92%` | Battery health, when reported |
| Chart | step line | Level over the current connection |

![Charging gauge: level colored by the aurora ramp, streaks flowing](screenshots/gauge.gif)

When not charging, the readout shows the time left and the tiles switch to
**EMPTY AT** and **DRAIN**. The gauge is a matte pill colored by level, with
light-speed streaks that flow while charging and a mark at 80%.

### Where the numbers come from

Bluetooth itself only reports a percentage, so the plugin combines two
sources:

1. **Reported by the device.** Devices with a kernel battery driver (most game
   controllers, Logitech peripherals, …) publish a real state through UPower.
   The plugin maps them to their Bluetooth address by reading `HID_UNIQ` from
   sysfs once per device.
2. **Estimated from level changes.** Otherwise, charging is inferred from a
   rising level. Time to full accounts for the usual lithium-ion slowdown
   past 80%. Estimates are shown with `≈` and refine as more steps arrive.
   It takes a few level changes (usually a few minutes) before the first
   estimate appears.

The card's footnote always says which source is in use.

## Settings

| Setting | Default | Description |
| --- | --- | --- |
| Devices in orbit | 8 | Connected devices are always shown; the rest are ranked by pairing and name |
| Show unnamed devices | off | Devices that only expose a MAC address |
| Always show names | on | Otherwise names appear on hover |
| Scan duration | 45 s | Discovery starts when a view opens and stops after this delay (or *While open*) |
| Center device | Automatic | Icon of this machine (laptop or desktop is detected) |
| Custom images folder | — | PNG files that replace built-in icons |
| Shooting stars | on | Occasional meteor in the background |
| Star density | Normal | Low, Normal or High |
| Desktop backdrop | 72% | Depth of the veil behind the desktop widget |
| Ambient motion on desktop | off | Keep orbits moving when the pointer is away |
| Sounds | off | Short cues on snap, connect and disconnect |
| Sound volume | 60% | |

## Device icons

Icons are matched by name patterns, for example every `WH-1000XMx`,
`AirPods Max`, `MX Master`, `Galaxy Buds`, `G703` or `DualSense`. The BlueZ
device class breaks ties, so a `G733` headset is never drawn as a mouse.

To change one, open its detail card and click the palette button. Your
choice is remembered per device. **Reset custom device icons** in the
settings clears all choices.

To use your own artwork, set **Custom images folder** and add PNGs named
exactly like the devices:

```
~/Pictures/bluetooth/
├── WH-1000XM6.png
├── Xbox Wireless Controller.png
└── MX Master 3S.png
```

Characters that are not allowed in file names (`/ \ : * ? " < > |`) are
replaced by `_`.

## Privacy

- No network access, no telemetry, no external processes.
- Connection times and battery history live in memory for the current
  session only. They are never written to disk.
- The only files read are the sysfs `uevent` of kernel batteries, once each,
  to match them to a Bluetooth address.
- Settings (your choices, custom icon picks) are stored by DMS with your other
  plugin settings.

## Performance

- One `FrameAnimation` drives physics, orbits and twinkles. It stops as soon as
  the scene settles or is hidden.
- The desktop widget renders zero frames while idle.
- Backgrounds (stars, nebulae, veil) are painted once. Charging effects only
  move fixed geometry, mostly with render-thread animators.
- Discovery runs only while a view is open and stops after the configured delay.
- The device list polls only while someone is looking or discovery runs.
- Sounds load the multimedia backend only when enabled.
- Honors DMS **Reduce motion**.

## Troubleshooting

**No devices appear while scanning.** Make sure the device is in pairing mode.
Devices that only broadcast a MAC address are hidden unless **Show unnamed
devices** is on, and the orbit keeps at most **Devices in orbit** entries.

**A device charges but shows no lightning.** It reports no charging state and
its level has not risen yet. The estimate starts after the first level
increase.

**The time to full looks off.** Estimates rely on the device's level steps.
Some headsets report in 10% steps, so the first minutes are rough and improve
over time.

## Development

```
orbitBluetooth/
├── plugin.json
├── OrbitBluetoothDaemon.qml     # connection times, battery log, UPower bridge
├── OrbitBluetoothWidget.qml     # Control Center tile, bar pill and popout
├── OrbitBluetoothDesktop.qml    # desktop widget
├── OrbitBluetoothSettings.qml
├── components/
│   ├── OrbitScene.qml           # the scene: physics, drag, focus, chrome
│   ├── DeviceBody.qml           # one orbiting device, charging beam
│   ├── FocusCard.qml            # detail card
│   ├── BatteryCard.qml          # gauge, chart and stat tiles
│   ├── Charge.js                # charge analysis and color ramp (pure)
│   ├── Starfield.qml, Vignette.qml, DeviceGlyph.qml, …
├── scripts/
│   ├── gen_sounds.py            # synthesizes sounds/*.wav (stdlib only)
│   └── preview/                 # offscreen renderer with mock services
├── screenshots/
└── sounds/
```

Regenerate the screenshots and GIFs (mock devices, no real data; the GIFs
need `ffmpeg`):

```sh
scripts/preview/render.sh          # PNG screenshots
scripts/preview/record.sh          # all GIFs
scripts/preview/record.sh beam     # one of: beam, gauge, focus, connect
```

Regenerate the sounds:

```sh
python3 scripts/gen_sounds.py
```

## License

MIT © lung595
