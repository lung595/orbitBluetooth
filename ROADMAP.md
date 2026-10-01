# Roadmap

Ideas, not promises, and no dates. Anything that would need the network or send data somewhere is out of scope.

## Planned

- **Conversation awareness that ends sooner** (how long the headset waits before going back to noise cancelling): needs the exact Sony / Samsung packet, not guessed.
- **The same offer as a system notification** while no view is open: it needs discovery to run in the background, which costs battery, so it is not planned for now.
- **Real device pictures**: only from your own **Custom images folder**. Downloading them is out of scope (it needs the network).
- **Easier to read code**: split the largest files (`OrbitScene.qml`, `DeviceBody.qml`) by role, without changing behavior.
- **More headphones tested on real hardware**: only Sony, Huawei and Nothing Ear (2) have been tested so far; reports for other brands are welcome.
- **Distance from the signal strength**, once Quickshell exposes it (it does not in 0.3.1).

## Not planned

- **Firmware updates**: they usually need the vendor's app and the network.

## Known limits

- Some Sony headsets do not report charging, or drop Bluetooth while charging; this is a hardware limit.
