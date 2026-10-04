# Roadmap

Ideas, not promises, and no dates. Anything that would need the network or send data somewhere is out of scope, except an opt-in option that is off by default and sends the bare minimum (like *Real device pictures*).

## Planned

- **An option to swap the two volumes' roles**: DMS's volume slider would set this PC's level, and the device's own level would be set in Orbit only.
- **Listen together, further**: the first version ships in the next release (two to four outputs, one arc each). Still open: measuring each output's real latency so the delay is found by itself (today `togetherDelay` is set by ear), sharing the level when the output you hear has no filter of Orbit's, and taking a member out by dragging it without disconnecting it.
- **Listen together with wired outputs**: a session takes Bluetooth outputs only today. The idea is to let it take a wired output too, for example a USB audio interface next to a Bluetooth headset. A wired output answers within a few milliseconds and a Bluetooth one needs 100 ms or more, so the wired output is the one to delay. Nothing is decided on how a wired output shows in the scene.
- **The center, further**: an IPC command for the general volume (`dms ipc call orbitBluetooth togetherVolume <percent>`), the source's own level reachable from the ring, a measured CPU cost per action, and a clearer way to tell whether sound really plays than PipeWire's link state.
- **Volume with four fingers on a touchpad**: on a laptop, swipe four fingers up or down to raise or lower the volume, with the same smart steps as the keys (a slow swipe moves by 1 %, a quick one further) and the volume scope in the island. To check first: whether niri lets a four-finger swipe reach a plugin (today its touchpad gestures are its own), or whether reading the touchpad would need access Orbit should not ask for.
- **Two PCs with Orbit side by side**: two computers running Orbit near each other could recognize each other, for example to send one's sound to the other. Nothing is decided. It would be opt-in, off by default, found on the local link only (no Internet, no telemetry), with a safe pairing, and could share ground with *Listen together*.
- **Pause when you take your headphones off, for other brands**: it ships for Sony headsets with a wearing sensor. AirPods, Galaxy Buds, Nothing, Huawei and the others each report wearing in their own vendor message, which needs a verified, freely licensed description (or a capture from a real headset) before Orbit sends anything: no packet is guessed.
- **Conversation length for Samsung**: Sony ships. The Galaxy Buds message is only described in a GPL-3.0 project, and Orbit is MIT and copies no code, so it waits for a description it can rely on.
- **Confirm the Sony wearing and conversation messages on a real headset**: they follow the MIT-licensed SonyHeadphonesClient (the wearing sequence was confirmed on a WH-1000XM6 there), but Orbit has not yet seen them answer on a headset of its own.
- **3D models of devices** (to animate them): Sketchfab only lets a signed-in account download a model, which Orbit cannot ask for without an account and a token. Previews (pictures) are what ships today.
- **Easier to read code**: split the largest files (`OrbitScene.qml`, `DeviceBody.qml`) by role, without changing behavior.
- **More headphones tested on real hardware**: only Sony, Huawei and Nothing Ear (2) have been tested so far; reports for other brands are welcome.
- **Distance from the signal strength**, once Quickshell exposes it (it does not in 0.3.1).

## Not planned

- **Firmware updates**: they usually need the vendor's app and the network.

## Known limits

- *What really plays*: the bit rate is only shown where the codec makes it known (LDAC, aptX, aptX HD; never SBC or AAC), the latency is the PC's part only (the headset's own delay cannot be read), and the quantum only appears while the output is playing.
- *Pause when you take the headset off* keeps one control connection open, and a Sony headset accepts only one at a time: the Sony app on a phone may not reach it meanwhile. After an error Orbit does not retry until the headset reconnects, and a player is paused only when its names equal those of the stream that reaches the headset.
- *Ambient motion* only pauses when windows fill the whole screen: a single floating or narrow window placed over the widget does not pause it, because niri does not tell where tiled windows sit on screen. On compositors other than niri it never pauses.
- Some Sony headsets do not report charging, or drop Bluetooth while charging; this is a hardware limit.
- *Listen together* is built from how PipeWire and Bluetooth headsets are meant to work and tested on a simulated sound server; with a real multipoint headset it is the headset that decides which device it listens to when the PC and the phone both play. See [Works with multipoint headsets](docs/GUIDE.md#works-with-multipoint-headsets).
