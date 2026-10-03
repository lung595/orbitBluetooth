# Roadmap

Ideas, not promises, and no dates. Anything that would need the network or send data somewhere is out of scope, except an opt-in option that is off by default and sends the bare minimum (like *Real device pictures*).

## Planned

- **Two volumes you can tell apart at a glance: the device's and this PC's.** Today the ring sets the device's sound output in PipeWire. On a device with absolute volume (AVRCP), that is the device's own level; on one without it, it only lowers what the PC sends. And when the device is your default output, the DMS volume slider moves that same level. The plan is to show and set both, drawn rather than written:
  - **Look**: two half circles, one inside the other, like a polar vectorscope. The outer one is **the device** (the level inside the headset or amplifier), the inner one is **this PC** (what it sends). Each outline lights up from L to R up to its level, ending in a moon you can drag, with the device's icon or a computer icon beside it. The number only shows while the level moves. Inside, a cloud of points shows **where the sound goes**, left to right and how loud, read live from that device's output by `cava` in stereo, only while it is visible. Colors come from the theme: `primary` for the device, `tertiary` for this PC.
  - **Smooth and light**: the cloud is redrawn by a 60 Hz timer (a *Smooth / Light* setting picks 30 Hz), and only Orbit's window redraws. Nothing runs when it is hidden or silent. *Reduce motion* is respected.
  - **Where**: around the open device (it replaces the aurora ring), and in a **volume popup** that appears without opening anything when the volume changes (keys or `dms ipc`, the device's own buttons or knob, or any other app). The popup unfolds under Orbit's bar widget, or stands vertically on the right edge (a setting picks which). The device's level follows its own buttons live, without polling.
  - **Mute** (click the planet): with **one** audio device connected, it mutes this PC; with **several**, it mutes that device only.
  - **A device without absolute volume** only gets the PC half circle, and a short note says why, with a link to the guide.
  - **An option to swap roles**: the DMS volume slider sets this PC, and the device's level is set only in Orbit.
  - **Keyboard**: `dms ipc call orbitBluetooth deviceVolume up|down|set <0-100>` and `pcVolume up|down|set <0-100>`, with checked and capped values.
  - The guide explains how to turn off DMS's own volume popup if both appear.
  - To check before any code: whether PipeWire can keep the PC's level apart while absolute volume is on, how Orbit can tell that a device has absolute volume, and what the swap option needs from WirePlumber.
- **Listen together**: two headsets on one film. Bring a second headset next to the first and Orbit makes a shared PipeWire output for both. It comes apart by itself when one disconnects. This comes after the two volumes.
  - **Look**: the outer half circle splits at its top. The left quarter is the first headset and the right quarter the second. Each one lights up from its bottom corner toward the top, and both meet at the top at 100 %. Each quarter has its own cloud of points and its own theme color (`primary` and `secondary`). The inner half circle stays below, shared by both: the level this PC sends (`tertiary`).
- **Pause when you take your headphones off, play when you put them back**: the headset tells Orbit when it leaves your head or ear (wear detection: Sony, AirPods, Galaxy Buds, Nothing, Huawei... each in its own vendor message, to be read in `anc/protocols/`), and Orbit pauses or resumes the media player through MPRIS, locally on D-Bus. Only for players Orbit paused itself, so it never starts music you stopped.
- **Conversation awareness that ends sooner** (how long the headset waits before going back to noise cancelling): needs the exact Sony / Samsung packet, not guessed.
- **3D models of devices** (to animate them): Sketchfab only lets a signed-in account download a model, which Orbit cannot ask for without an account and a token. Previews (pictures) are what ships today.
- **Easier to read code**: split the largest files (`OrbitScene.qml`, `DeviceBody.qml`) by role, without changing behavior.
- **More headphones tested on real hardware**: only Sony, Huawei and Nothing Ear (2) have been tested so far; reports for other brands are welcome.
- **Distance from the signal strength**, once Quickshell exposes it (it does not in 0.3.1).

## Not planned

- **Firmware updates**: they usually need the vendor's app and the network.

## Known limits

- *Ambient motion* only pauses when windows fill the whole screen: a single floating or narrow window placed over the widget does not pause it, because niri does not tell where tiled windows sit on screen. On compositors other than niri it never pauses.
- Some Sony headsets do not report charging, or drop Bluetooth while charging; this is a hardware limit.
