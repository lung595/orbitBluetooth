# Roadmap

Ideas, not promises, and no dates. Anything that would need the network or send data somewhere is out of scope.

## Planned

- **Pause when you take your headphones off, play when you put them back**: the headset tells Orbit when it leaves your head or ear (wear detection: Sony, AirPods, Galaxy Buds, Nothing, Huawei... each in its own vendor message, to be read in `anc/protocols/`), and Orbit pauses or resumes the media player through MPRIS, locally on D-Bus. Only for players Orbit paused itself, so it never starts music you stopped.
- **Conversation awareness that ends sooner** (how long the headset waits before going back to noise cancelling): needs the exact Sony / Samsung packet, not guessed.
- **3D models of devices** (to animate them): Sketchfab only lets a signed-in account download a model, which Orbit cannot ask for without an account and a token. Previews (pictures) are what ships today.
- **Easier to read code**: split the largest files (`OrbitScene.qml`, `DeviceBody.qml`) by role, without changing behavior.
- **More headphones tested on real hardware**: only Sony, Huawei and Nothing Ear (2) have been tested so far; reports for other brands are welcome.
- **Distance from the signal strength**, once Quickshell exposes it (it does not in 0.3.1).

## Not planned

- **Firmware updates**: they usually need the vendor's app and the network.

## Known limits

- Some Sony headsets do not report charging, or drop Bluetooth while charging; this is a hardware limit.
