# Roadmap

Ideas, not promises, and no dates. Anything that would need the network or send data somewhere is out of scope, except an opt-in option that is off by default and sends the bare minimum (like *Real device pictures*).

## Planned

- **More about what plays**: the Bluetooth codec's bit rate, the profile, the latency and the quantum in the unfolded details (the line, the sample rate, depth and resampling note ship in 1.13.0).
- **An option to swap the two volumes' roles**: DMS's volume slider would set this PC's level, and the device's own level would be set in Orbit only.
- **Listen together**: two headsets on one film. Bring a second headset next to the first and Orbit makes a shared PipeWire output for both. It comes apart by itself when one disconnects.
  - **Look**: the outer half circle splits at its top. The left quarter is the first headset and the right quarter the second. Each one lights up from its bottom corner toward the top, and both meet at the top at 100 %. Each quarter has its own cloud of points and its own theme color (`primary` and `secondary`). The inner half circle stays below, shared by both: the level this PC sends (`tertiary`).
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

- *Pause when you take the headset off* keeps one control connection open, and a Sony headset accepts only one at a time: the Sony app on a phone may not reach it meanwhile. After an error Orbit does not retry until the headset reconnects, and a player is paused only when its names equal those of the stream that reaches the headset.
- *Ambient motion* only pauses when windows fill the whole screen: a single floating or narrow window placed over the widget does not pause it, because niri does not tell where tiled windows sit on screen. On compositors other than niri it never pauses.
- Some Sony headsets do not report charging, or drop Bluetooth while charging; this is a hardware limit.
