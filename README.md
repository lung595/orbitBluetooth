<div align="center">

# Orbit Bluetooth

**A planetary Bluetooth manager for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).**

Your machine sits at the center of a small star system and nearby devices float around it.
Drag a device to the center to connect it, pull it away to disconnect it.

![Orbit view in the Control Center](screenshots/orbit.png)

[Getting started](#getting-started) · [Usage](#usage) · [Settings](#settings) · [Troubleshooting](#troubleshooting) · [User guide](docs/GUIDE.md) · [Changelog](CHANGELOG.md)

</div>

## Getting started

### Requirements

| Dependency | Version | Needed for |
| --- | --- | --- |
| DankMaterialShell | 1.6.0 or newer | Everything |
| BlueZ | Any recent version, adapter powered on | Everything |
| UPower | Any | *Optional*: real charging states |
| PipeWire | Any | *Optional*: volume slider of audio devices |
| Python 3 | Standard library only | *Optional*: headphone noise control |

### 1. Install

From the plugin browser: **Settings → Plugins**, search for **Orbit Bluetooth**, click *Install*. Or from a terminal:

```sh
dms plugins install orbitBluetooth
```

<details>
<summary>Manual install</summary>

```sh
git clone https://github.com/lung595/orbitBluetooth ~/.config/DankMaterialShell/plugins/orbitBluetooth
```

Then click **Settings → Plugins → *Scan for plugins***.
</details>

### 2. Enable

In **Settings → Plugins**, turn **Orbit Bluetooth** on.

### 3. Add a widget

> [!IMPORTANT]
> **Orbit Bluetooth does not replace the built-in DMS Bluetooth widget.** Nothing shows up until you **add at least one of its widgets** yourself.

| Where | How to add it |
| --- | --- |
| **Control Center** | Open the Control Center, enter **edit mode**, add the **Bluetooth** tile from *Orbit Bluetooth* |
| **Bar** | **Settings → Appearance → DankBar Layout**, add **Orbit Bluetooth** to a section |
| **Desktop** | **Settings → Desktop Widgets**, add **Orbit Bluetooth**, then move and resize it |

> [!TIP]
> To avoid two Bluetooth tiles in the Control Center, remove the built-in one in edit mode.

### 4. First steps

1. **Open the orbit** from the widget you added. Discovery starts on its own.
2. **Drag a device into the inner ring** to pair and connect it; drag it back out to disconnect.
3. **Click a device** for its detail card: battery, charging, volume, noise control.
4. **New headphones?** Put them in pairing mode: within a minute a pairing sheet unfolds from the bar and offers to connect them, even with Orbit closed.

## Features

| Drag to connect | Energy beam while charging |
| --- | --- |
| ![Dragging earbuds to the inner ring connects them](screenshots/connect.gif) | ![A beam of energy flowing to a charging headset](screenshots/beam.gif) |

| New headphones pop-up | Dark and light themes |
| --- | --- |
| ![The pairing sheet unfolds from the bar, the headset falls into orbit and connects](screenshots/newdevice.gif) | ![The pairing sheet offering, then connected, in a dark and a light theme](screenshots/newdevice.png) |

- **New headphones? Orbit notices.** Put them in pairing mode and a pairing sheet unfolds from the bar: the headset falls into orbit and floats above a planet, *Connect* pairs it on the spot, shows its battery and its noise-control modes. Deep space in a dark theme, stratosphere in a light one, with any DMS palette. Works with Orbit closed.
- **Drag to connect** with a magnet snap, elastic tether to disconnect.
- **Live charging**: energy beam, time to full, charge speed, session chart.
- **Earbuds trio**: the case and both buds in their own mini orbit, each with its battery.
- **Noise control** for 13 headphone brands (Sony, Apple, Samsung, Bose, Huawei…).
- **Real device pictures** (opt-in, uses the internet): a photo of your headphones, phone or TV instead of an icon.
- **Black hole**: drop a device you never use into it to hide it.
- **28 device icons** matched by name, or your own pictures.
- **Light and dark themes**; the sky always stays night.
- **Lightweight and private**: no frames drawn at rest, no telemetry, nothing leaves your machine unless you turn on real device pictures.

## Usage

| Gesture | Result |
| --- | --- |
| Put new headphones in pairing mode | A pairing sheet under the bar offers to connect them (<kbd>Enter</kbd> connects, <kbd>Esc</kbd> later) |
| Drag a device inside the inner ring | Pair and connect |
| Drag a connected device outward | Disconnect |
| Click a device | Open its detail card |
| Right-click a device | Menu: connect, noise-control modes, hide, forget |
| Forget a device (unpair) | Right-click → **Forget**, click again to confirm; or the 🗑 button of its detail card |
| Drag a device into the black hole | Hide it (it stays connected) |
| Click the black hole | List hidden devices, **Show** brings one back |
| Click the center, or the **Scan** chip | Start discovery |
| <kbd>Esc</kbd> | Step back: menu, hidden list, detail card |

In the **Control Center**, the tile icon turns Bluetooth on or off and the arrow expands the orbit. In the **bar**, left click opens the orbit, right click turns Bluetooth on or off.

📖 Everything else (detail card, renaming, earbuds, noise control and supported models, charging data, custom icons) is in the **[user guide](docs/GUIDE.md)**.

## Settings

**Settings → Plugins → Orbit Bluetooth.** Options marked ⚡ use more battery.

| Section | Setting | Default |
| --- | --- | --- |
| Orbit | Devices in orbit | 8 |
| | Always show names | On |
| | Show unnamed devices (MAC address only) | Off |
| | Quick disconnect button (× on hover) | Off |
| | Center device | Automatic |
| Scanning | Scan automatically | On |
| | Offer new devices (a *Connect* card) | On |
| | Pop-up for new headphones (background scan) ⚡ | On |
| | Background scan | Every minute |
| | No background scan below (battery, unplugged) | 30 % |
| | Scan duration: 20 s, 45 s, 90 s or *While open* ⚡ | 45 s |
| Headphones | Noise control | On |
| | Turn off conversation awareness on disconnect | On |
| | Engine: *On demand* or *Always connected* ⚡ | On demand |
| Desktop widget | Displays | All |
| | Backdrop | 72 % |
| | Ambient motion ⚡ | Off |
| Device pictures | Real device pictures (uses the internet) | Off |
| Look | Black hole: realistic or tesseract | Black hole |
| | Shooting stars | On |
| | Stars: Low, Normal or High | Normal |
| | Custom images folder | — |
| Sounds | Sounds | Off |
| | Volume | 60 % |

## Command line and keybindings

```sh
dms ipc call orbitBluetooth anc nc       # nc, ambient, off or adaptive (first supported headset)
dms ipc call orbitBluetooth ancCycle     # next noise-control mode
dms ipc call orbitBluetooth ancStatus    # current noise-control state (JSON)
dms ipc call orbitBluetooth newDeviceDemo    # show the new-headphones pop-up with a made-up headset
dms ipc call orbitBluetooth newDeviceStatus  # is the background scan running, or why not
dms ipc call orbitBluetooth hidden       # list hidden devices
dms ipc call orbitBluetooth unhideAll    # bring every hidden device back
```

Bind them in your compositor, for example in niri: `Mod+N { spawn "dms" "ipc" "call" "orbitBluetooth" "ancCycle"; }`, or in Hyprland: `bind = SUPER, N, exec, dms ipc call orbitBluetooth ancCycle`.

## Troubleshooting

| Problem | Solution |
| --- | --- |
| Nothing changed after installing | Add one of its widgets, see [Add a widget](#3-add-a-widget) |
| Earbuds disconnect after a few seconds | Accept the pairing code dialog once |
| No pop-up for new headphones | Turn off Bluetooth audio you are using (scanning would make it stutter, so it waits); check the battery threshold; the pop-up waits for full-screen windows |
| No devices appear while scanning | Put the device in pairing mode; turn on **Show unnamed devices** |
| A device charges but shows no lightning | Wait for its first level increase: the estimate starts then |
| Noise control does not appear | Headset must be paired and supported, Python 3 installed; reopen the card |
| A device vanished | It is in the black hole: click it, or `dms ipc call orbitBluetooth unhideAll` |
| Time to full looks off | Some headsets report in 10 % steps; it improves over time |

Some Sony headsets do not report charging, or drop Bluetooth while charging: this is a hardware limit.

## Privacy

- **No telemetry.** Connection times and battery history stay in memory; settings, hidden and ignored devices are stored by DMS.
- **Noise control**: a small helper talks to your headset over a local Bluetooth socket, only while needed.
- **New headphones pop-up**: a local Bluetooth scan of 8 s about once a minute, only while the screen is on, no Bluetooth audio is connected and the battery is above the threshold (30 % by default, unplugged). Turn it off in **Scanning**.
- **Network: only one opt-in feature, off by default.** **Real device pictures** sends only the *model name* of devices you have paired, never a stranger's device nearby, never the Bluetooth address. It contacts `commons.wikimedia.org`, then `api.sketchfab.com`, and downloads the picture from `upload.wikimedia.org` or `media.sketchfab.com`. Pictures are credited in the card, kept in `~/.cache/orbitBluetooth/pictures` (readable by you only) and erased when you turn the option off or from the settings.

Details in the [user guide](docs/GUIDE.md#privacy).

## Documentation

| File | Content |
| --- | --- |
| [docs/GUIDE.md](docs/GUIDE.md) | Full user guide |
| [CHANGELOG.md](CHANGELOG.md) | What changed in each version |
| [ROADMAP.md](ROADMAP.md) | Ideas for the future |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Architecture, tests and release process, for anyone working on the code |

## Credits

Noise-control protocols were reimplemented from the public notes of Gadgetbridge, SonyHeadphonesClient, XMDeck, LibrePods, MagicPodsCore, GalaxyBudsClient, based-connect, bosectl, OpenSCQ30, OpenFreebuds, EarA-linux, earctl and cmfctl (no code copied). The new-device pop-up is inspired by the nearby-device cards of Google Fast Pair and Apple's AirPods setup (the idea only: Orbit uses plain BlueZ discovery, no vendor protocol). Device pictures come from [Wikimedia Commons](https://commons.wikimedia.org) and [Sketchfab](https://sketchfab.com) (free licenses only, each author is credited in the card): thank you to the photographers and 3D artists who share their work. Built on [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) and [Quickshell](https://quickshell.org).

## License

[MIT](LICENSE) © lung595
