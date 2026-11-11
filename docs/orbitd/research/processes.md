# External processes and system access in Orbit today, and what each becomes in orbitd

> **Corrected 2026-11-11 (PLAN.md step 1, branch `fix/no-pipewire-utils`).** This pass assumed the `pw-*` tools were installed. They come with **pipewire-utils**, which a default install (Fedora) does not have, so the PC filter, the copies, the tick and the latency read were broken there. Step 1 moved every site to what the stock packages ship: the loopbacks to the `pipewire` binary, the tick to `pacat`, the graph dump to `wpexec`. Only `pw-top` is left, for the optional quantum. The sites below say what runs now; the original reasoning is kept where it still holds, and each correction is marked.

Read-only pass over `components/`, `diagnostics/`, the root `*.qml` files and the three Python helpers that the QML launches. `tests/` and `scripts/preview/` are left out. I count **19 distinct process sites, 6 FileView sites, 4 kernel socket uses (all inside the ANC helper), 0 direct D-Bus calls from QML (D-Bus is reached through `busctl` or Quickshell services) and 0 network.**

## 0. The finding that shapes everything: static musl and PipeWire

Two of the owner's decisions collide here: "static musl binary" and "PipeWire events replacing pw-dump/pactl/pw-top".

- `pipewire-rs` (and `libspa`) are bindgen wrappers over **libpipewire-0.3.so**.
- libpipewire loads its SPA plugins and modules with `dlopen`.
- A statically linked musl binary cannot `dlopen` the system's glibc-built `.so` files. In practice `pipewire-rs` cannot ship as a static musl binary.
- `libpulse-binding` has the same problem: it is C libpulse.
- `bluer` pulls in the `dbus` crate (C libdbus). That one can be worked around with its `vendored` feature, but it is simpler to use **zbus** (pure Rust) and raw `libc` Bluetooth sockets.

What remains for audio:

| Option | What it is | What it gives | Limits |
|---|---|---|---|
| (a) Pure-Rust PulseAudio native protocol (e.g. the `pulseaudio` crate) | Talks to pipewire-pulse over `$XDG_RUNTIME_DIR/pulse/native` | Sinks with props (replaces `pactl list sinks`), subscribe events (replaces polling), set volume/mute, record stream from `.monitor` (could replace cava's input) | Cannot see PipeWire-only data: Latency/Props params, quantum, profiler, explicit port links |
| (b) Daemon keeps spawning the pw CLI tools, but resident | `pw-dump --monitor` is one long-lived process streaming JSON diffs | Replaces every one-shot `pw-dump`, and is event-driven | Needs pipewire-utils, which is not on a default install (correction below). The stock equivalents are `pipewire -c` (loopbacks), `pacat` (tick) and `wpexec` with a Lua script (graph reads, and events through an ObjectManager) |
| (c) Write a native PipeWire protocol client in Rust | — | — | No mature crate; large and risky |

**Recommendation to confirm with the owner: (b), optionally with (a) added for volume writes and events.**

*Correction:* the original line here said the `pw-*` tools were already a dependency of the plugin. They are not on a default install: pipewire-utils is a separate package that Fedora does not install, and on this machine `pw-loopback`, `pw-cat`, `pw-link`, `pw-dump`, `pw-top` and `pw-cli` are all missing. Since step 1 Orbit needs none of them; `pw-top` is optional (the quantum line). Spawning children from orbitd stays possible with the stock binaries named in (b).

## 1. Every process, FileView, socket and D-Bus access

Columns: **When** = trigger · **Rate** = how often in practice · **Parse** = which JS function reads the output · **Rust** = proposed replacement.

### Audio and PipeWire

**A1. `pactl --format=json list sinks`** · `components/volume/AudioFacts.qml:40`
- When: `active` becomes true (`TwoLevels.qml:124-129`: card or pop-up on screen and at least one "facts" pref on), `sink`/`pcSink` changes, or the user taps the facts line (`FactsLine.qml:107` → `TwoLevels.refreshFacts()` at `:149`).
- Rate: once per card opening plus one per output change.
- Parse: `Audiophile.parse` (`Audiophile.js:73`), reading `api.bluez5.codec`, `api.bluez5.profile`, sample spec.
- Rust: the sink list from (b) `pw-dump -m`, or from (a) the pulse protocol. Both carry the same props. Then push a `facts` message on every change, which ends the "refresh" concept.

**A2. `pactl --format=json list sinks`** (`Wired.command()`, `together/Wired.js:26`) · `components/together/WiredWatch.qml:36`
- When: `active` becomes true, or `refresh()`. Two instances:
  - `scene/GroupChooser.qml:230` (always active while the chooser menu is open, so one read per opening);
  - `centre/OrbitGhost.qml:58`, re-read on every change of `Ghost.signature(...)` over `Pipewire.nodes` (`:64-66`).
- Rate: once per menu open, plus each node add/remove while the ghost is open.
- Parse: `Wired.parse` (`Wired.js:104`) and `Wired.sameSet`.
- Rust: same as A1. The daemon owns the sink list and emits `wiredOutputs`.

**A3. `wpexec graph/orbit_graph.lua`** (was `pw-dump`) · `components/volume/AudioGraph.qml:54`
- When: `wantDump` becomes true (`Audiophile.needs`: latency or LDAC quality shown, card on screen), `sink` changes, or `refresh()`.
- Rate: once per opening. `pw-dump` printed about 1 MB of JSON per run; the script prints only the sinks' name, Latency and quality (under 1 KB for three sinks), in pw-dump's shape. About 10 ms and 12 MB peak, and it quits by itself after 3 s at most.
- Parse: `AudioGraph.parseDump` (`AudioGraph.js:12`): the `Latency` param `maxNs` of direction Input, and `Props.quality`.
- Rust: (b) a resident graph reader carries the params (`pw-dump -m` needs pipewire-utils; a resident `wpexec` script with an ObjectManager is the stock way). **(a) cannot give these PipeWire params**, which is why (b) is needed.

**A4. `pw-top -b -n 2`** · `components/volume/AudioGraph.qml:63` (optional: pipewire-utils; without it the quantum is left out)
- When: `wantTop` (quantum fact shown, or details unfolded), `sink` change, or `refresh()`.
- Rate: once per opening, about 1 s per run.
- Parse: `AudioGraph.parseTop` (`:46`).
- Rust: **no clean replacement.** Quantum and rate come from PipeWire's Profiler interface, which only libpipewire speaks. The daemon keeps spawning `pw-top` (risk flagged).

**A5. `wpexec graph/orbit_graph.lua`** (was `pw-dump`) · `components/together/MemberLatency.qml:67`
- When: a `settle` timer (400 ms) on session start and on each `signature` change (members, codec, profile: `TogetherSession.qml:265-272`). Only exists inside a Listen together session.
- Rate: a few times per session.
- Parse: `AudioGraph.parseDump`, then `Delay.latenciesOf`.
- Since step 1: a reader that never starts (no wpexec) tells the group like a failed read, where `pw-dump` missing failed silently.
- Rust: the same resident reader as A3. Latencies are recomputed in the daemon and pushed out.

**A6. `bash -c LOOPBACK_SCRIPT … pipewire -c`** (was `pw-loopback`), **the PC-level smart filter**
- Built by `Route.filterArgs` (`Route.js:176`, script at `:133`, `loopbackArgs` `:154`); run at `components/volume/RouteDevice.qml:116-117`.
- Since step 1: the stock `pipewire` binary runs as a client with a config that loads `libpipewire-module-loopback`, as `pw-loopback` does. The config is in an unlinked file on fd 3, reached through the data-free link `$XDG_RUNTIME_DIR/orbit-loopback.conf`. Unlike `pw-loopback`, it does not exit when its loopback is destroyed, so RouteDevice and TogetherLink stop it when its node is missing for 2 s. Both ends carry the filter's `node.link-group`.
- When: declarative, `running: dev.wanted` (Separate PC volume on, device has absolute volume, sink present).
- Rate: one resident process per connected absolute-volume Bluetooth device.
- Parse: output not read; exit is logged as ORB-E003.
- Rust: `std::process` spawn of the same `pipewire -c` from orbitd (the original note said `pw-loopback`, which a default install lacks). The config can be handed over the same way (an unlinked file on a file descriptor), or through a memfd. The bash watchdog (`cat` on stdin, then `kill`) becomes `prctl(PR_SET_PDEATHSIG)` plus killing children when the daemon's stdin closes. Loading `module-loopback` in orbitd's own process needs libpipewire, so it is not an option; `pipewire -c` is the default-install way to run module-loopback.

**A7. `bash -c … pipewire -c`** (was `pw-loopback`), **Listen together copies and the wired-source filter**
- Built by `Together.args` (`Together.js:241`), `Route.wiredFilterArgs` (`Route.js:217`), `Together.commands` (`:269`) and `Together.diff`; run at `components/together/TogetherLink.qml:62-66` (Instantiator over a ListModel).
- The wired filter's wait (`target.delay.sec`) was measured to have no effect on a smart filter, with or without pipewire-utils; it is on the roadmap to verify on PipeWire 1.6.
- When: a Listen together session's plan changes.
- Rate: 1 to N resident processes (one per member, plus the filter) for the session's lifetime.
- Rust: same as A6. The daemon keeps a `HashMap<key, Child>` and diffs it itself.

**A8. `python3 -I tick/orbit_tick.py <sink> volume.wav <link group>`** · `components/volume/VolumeTick.qml:71`
- When: the first tick after idle on a given output. A stdin line `t <gain>` is written per tick. It stays resident until `Volume.IDLE_MS` = 2000 ms with no tick.
- Limits: at most `MAX_TICKS` = 4 players, at most 20 ticks/s (`MIN_GAP_MS` = 50).
- Inside the helper, since step 1: one `pacat --playback --raw … -d <sink>` (`orbit_tick.py:132` `player_args`, run at `:163`) whose stream carries `node.link-group=<the filter's group>` (`Route.tickGroup`), `state.restore-props=false`, `state.restore-target=false`, `node.dont-reconnect=true` and `node.dont-fallback=true`. It was `pw-cat` with autoconnect off and `pw-link` polled up to 40 times, both from pipewire-utils.
- Rust: mixing moves into orbitd (it is already pure arithmetic). It needs one playback stream aimed at the sink that carries the filter's link group: WirePlumber's smart-filter rules send such a stream where the filter goes, the sink itself, so it never passes through the filter the copies read (NAK-251).
  - simplest: keep `pacat` as a child;
  - *Correction:* the original note said (a), the pulse protocol, **cannot** keep the tick out of the smart filter. It can: a pulse stream with the filter's `node.link-group` is routed to the sink itself. Measured on PipeWire 1.6.11 and WirePlumber 0.5.19 with a null sink and a filter-shaped loopback: a plain `pacat -d sink` landed in the filter, the same with the group landed on the sink. The rule is WirePlumber's (not a documented API), so orbitd step 2 measures it again.

**A9. `bash -c 'exec cava -p /dev/fd/3 3<<<"$1"'`** · `components/volume/ScopeFeed.qml:68`
- When: `running: _go && _conf` (vectorscope on screen, motion allowed, no volume-key burst).
- Rate: one resident process, about 60 lines/s.
- Parse: `Polar.parseFrame` (`Polar.js:162`); config from `Polar.cavaConfig` (`:215`).
- Rust: **unclear, decision needed.**
  - Option 1: orbitd spawns cava and forwards frames. That adds a hop at 60 Hz, a per-frame cost in the daemon, and JSON overhead.
  - Option 2: orbitd records `.monitor` via pulse (a) and runs `rustfft` itself. That is new DSP to own.
  - Option 3: leave cava spawned from QML, since it is a per-frame UI feed like `Polar.js`, which stays.
  - I would propose Option 3, but it contradicts "no Process in QML".

### Bluetooth and BlueZ (D-Bus through busctl)

**B1. `busctl tree --list org.bluez`** · `components/volume/RouteDevice.qml:62`
- When: `probe()` when a device's sink appears with `absolute < 0` (`:41-43`); retried once after 4 s (`:94-98`).
- Rate: 1–2 per connection per device.
- Parse: `Route.transportPath` (`Route.js:239`).
- Rust: **zbus** `org.freedesktop.DBus.ObjectManager.GetManagedObjects` on `org.bluez`, plus the `InterfacesAdded` signal. This drops the 4 s retry, since the transport's `Volume` appearing is an event.

**B2. `busctl --json=short get-property -- org.bluez <transport> org.bluez.MediaTransport1 Volume`** · `RouteDevice.qml:72` (chained after B1)
- Parse: `Route.transportVolume` (`Route.js:251`).
- Rust: zbus `MediaTransport1` proxy property, plus `PropertiesChanged`.

**B3. `busctl --json=short get-property -- org.bluez <dev> org.bluez.Device1 UUIDs`** · `components/pairing/ProfileCheck.qml:33`
- When: user action, after each pairing (called from `scene/OrbitConnections.qml:181`).
- Rate: one per pairing.
- Parse: `Guard.parseUuids` (`Guard.js:30`), then `Guard.refused`.
- Rust: a zbus `Device1.UUIDs` read.
- Note: the follow-up writes (`trusted`, `blocked`, `forget()`) are done in QML today through Quickshell.Bluetooth (`ProfileCheck.qml:40-49,76-77`). Either keep them in QML, or have the daemon do `Device1.Trusted`/`Blocked` and `Adapter1.RemoveDevice` through zbus. Having both writing would race.

**B4. `python3 -E -s anc/orbit_anc.py <addr> <family>`**, with env `ORBIT_ANC_NAME` · `components/noise/AncService.qml:98` (Component at `:306-321`)
- When:
  - engine "demand": while a detail card is open, or a command is in flight;
  - engine "live": per connected supported headset;
  - wear pause: kept open for Sony headsets;
  - `reconnectTimer` 2.5 s after a reconnect (chat off);
  - `leaveTimer` 4 s.
- Rate: one resident process per controlled headset.
- Protocol: JSON line per message; stdin `set <key> <value>`.
- Parse: `AncSnapshot.merge` (`AncSnapshot.js`).
- Inside the helper: `AF_BLUETOOTH` / `SOCK_SEQPACKET` / `BTPROTO_L2CAP` (`orbit_anc.py:69`), `SOCK_STREAM` / `BTPROTO_RFCOMM` (`:91`), SDP over L2CAP PSM 1 (`sdp.py:96`). `CONNECT_TIMEOUT` = 8 s, blocking connect.
- Rust: `libc::socket(AF_BLUETOOTH=31, …)` with a hand-written `sockaddr_l2` / `sockaddr_rc` (musl has no `bluetooth.h`, and the libc crate does not define them), driven by tokio `AsyncFd`. The SDP client is a reimplementation of `sdp.py` (110 lines). The 16 protocol modules (`anc/protocols/*.py`, about 2.1k lines) are ported one to one.
- Risk: blocking connect with an 8 s timeout must not stall the other sessions. Use a non-blocking connect plus a timeout per task.

### Files

**F1. History write: `sh -c 'umask 077; mkdir -p "$1" && cat > "$2.tmp" && mv -f …'`** · `Sessions.writeCommand` (`battery/BatterySessions.js:236`), run at `components/battery/BatteryHistoryStore.qml:101`
- When: on session end or disconnect (`recordSession`, `markSeen`). Note the component comment says it is "not loaded by any view yet".
- Rust: `std::fs`: `create_dir_all` with mode 0700, `OpenOptions` with mode 0600 to a tmp file, then `rename`.

**F2. `rm -f -- file file.tmp`** · `Sessions.eraseCommand` (`:240`), run at `BatteryHistoryStore.qml:118`
- When: user action (erase).
- Rust: `fs::remove_file`.

**F3. FileView of `history.json`, blocking** · `BatteryHistoryStore.qml:95`
- When: lazy, first use.
- Parse: `Sessions.parse`.
- Rust: `fs::read` plus serde.

**F4. FileView of `/sys/class/power_supply/<n>/device/uevent`** · `components/common/DeviceLog.qml:98`
- When: once per non-BlueZ UPower device (HID batteries).
- Parse: inline regex `HID_UNIQ`, then `Address.find`.
- Rust: `fs::read_to_string` in the daemon, or leave it in QML. It belongs to battery/wear, which moves.

### Clean-up and uninstall

**F5. `rm -rf -- <xdgCache>/<id>/pictures`** via `Quickshell.execDetached` · `OrbitBluetoothDaemon.qml:74`
- When: once, if `prefs.oldRealPictures`.
- Rust: `fs::remove_dir_all`. Or keep it in QML, since it is one line and runs once.

**F6. Uninstall sweep: `python3 -E -s -c <script> …`** via `execDetached` · `components/common/UninstallSweep.qml:63`
- Setup: the script text is read by FileView at load (`:35-40`). On unload, the code checks whether `plugin.json` is gone (FileView `:42-46`, `:55-61`).
- Inside the script: `dms keybinds show/set` (`orbit_uninstall.py:147`), then it rewrites `settings.json`, `plugin_settings.json` and `session.json`.
- **Risk, needs a design decision:** when this runs, the plugin folder, and so the orbitd binary, has already been deleted. "No Python" means this script must become Rust too. Options:
  - **(i)** the still-running orbitd does the sweep itself. A running process keeps its unlinked executable inode. On stdin EOF it checks for `plugin.json`, waits, re-checks, `setsid`/double-forks so it outlives the shell, then sweeps.
  - **(ii)** at startup orbitd copies itself to `$XDG_RUNTIME_DIR`, or re-execs itself through `/proc/self/exe` or a memfd.
  - **(i) looks simplest**, but it requires the daemon to survive the shell exit long enough. That conflicts with the "dies with the shell" rule (value 12) and has to be designed explicitly.

### Volume keys and clipboard

**K1. `dms keybinds show niri`** (`Keys.SHOW_ARGS`, `volume/Keys.js:49`) · `components/volume/VolumeKeys.qml:102`
- When: at start (`claim()`, `OrbitBluetoothDaemon.qml:99`), but only if `keysOrbit` is set or `keysReturned` is false, so normally 0. Also on enable/disable, the IPC `volumeKeys` command (`OrbitIpc.qml:180`), and after each set.
- Parse: `Keys.classify` (`Keys.js:96`).
- Rust: spawn `dms` (there is no other API). Trivial.

**K2. `dms keybinds set <provider> <key> <action> --allow-when-locked --json`** (`Keys.setArgs` `:35`, `Keys.backArgs` `:45`) · `VolumeKeys.qml:119`
- When: user action; two calls per change, chained.
- Parse: `Keys.succeeded` (`:117`).
- Rust: spawn `dms`.
- Note: the action that gets bound (`Keys.js:32`) makes **niri** spawn `sh -c "dms ipc call orbitBluetooth volume …"` on every key press, falling back to a second `dms ipc call audio`. That is 1–2 processes per key press, outside the plugin. It stays as is. If the volume logic is in orbitd, each press goes niri → `dms ipc` → QML `IpcHandler` → orbitd → QML/PipeWire. **Latency risk on held keys.**

**C1. Clipboard: `wl-copy --sensitive`, then the fallback `dms clipboard copy`** (`Gather.COPY_TOOLS`, `diagnostics/Gather.js:42`) · `components/common/ReportCopy.qml:55` (ToolProcess)
- When: user action; text goes on stdin.
- Rust: spawn the same tools. Or keep it in QML, since it is the UI copy button.

### Diagnostics report

**R1. The 7 probes of `Gather.PROBES`** (`diagnostics/Gather.js:12-25`), run in sequence through ToolProcess · `components/common/ReportService.qml:162`
- The probes: `dms version`, `quickshell --version`, `niri --version`, `rpm -q --qf %{VERSION} qt6-qtbase`, `cat -- /etc/os-release`, `cat -- /etc/hostname`, `env LC_ALL=C journalctl --user -u dms -n 300 --no-pager -o cat`.
- When: user action (report button, or IPC `diagnostics`, `OrbitIpc.qml:284`).
- Parse: `Gather.parse`, then `Report.build` / `Redact`.
- Rust: `fs::read` for the two `cat`s. Spawn the rest. The journal needs libsystemd for `sd-journal` (C, not static), so keep spawning `journalctl`.

**R2. FileView of `/proc/self/stat`, read twice 1 s apart** · `ReportService.qml:140`, Timer `:153`
- Parse: `Cpu.ticksOf` / `Cpu.percent`.
- Rust: **meaning changes.** `self` is the quickshell process today. In orbitd it must be `/proc/<ppid>/stat` (quickshell), plus `/proc/self/stat` for the daemon's own cost. The report should show both.

**R3. FileView of `plugin.json`, blocking** · `ReportService.qml:147`
- Parse: `Gather.pluginVersion`.
- Rust: `fs::read` (`env!("CARGO_PKG_VERSION")` does not work here: the binary is built by CI, not tied to `plugin.json`).

**F7. FileView of `uninstall/orbit_uninstall.py` and the `plugin.json` probe** · `UninstallSweep.qml:35,42`
- Gone if the sweep moves into orbitd.

### Other

`GuideLink.qml:27` `Qt.openUrlExternally(Guide.url(...))` opens a local docs URL in the browser on click. Not network done by the plugin. Stays in QML.

## 2. Quickshell and DMS services read directly from QML

These stay in QML unless the daemon must own the data.

### Quickshell.Bluetooth
Read through `Bluetooth.devices` or `BluetoothService.adapter`:
- readers: `DeviceLog.qml:110`, `AncService.qml:58,125,212,325`, `AudioRoute.qml:55`, `DisconnectDelays.qml:42,64,76`, `ReportService.qml:108`;
- writes: `disconnect()` in `AncService.qml:168-188`, `DisconnectDelays.qml:96` and `OrbitConnections.qml:96,113,151`; `forget()` in `OrbitConnections.qml:144` and `ProfileCheck.qml:48`; `trusted`/`blocked` in `ProfileCheck.qml`; `adapter.discovering` in `OrbitDiscovery.qml:18,27`.

**Conflict:** ANC, rules, delays, together and battery move to orbitd, but they all need connect/disconnect events and device names. Two ways:
- (1) QML forwards the `Bluetooth.devices` state to the daemon as JSON. That needs no D-Bus in the daemon, but adds one more hop.
- (2) orbitd subscribes to BlueZ itself through zbus `ObjectManager` and `PropertiesChanged`. That gives two sources of truth that may disagree for a few milliseconds.

(2) is the cleaner choice if the daemon does the disconnects itself (ANC chat-off then disconnect, delays). The UI then shows the same data through Quickshell.

### Quickshell.Services.Pipewire
- `Pipewire.nodes.values`: `RouteDevice.qml:30,32`, `AudioRoute.qml:43,46,51,172`, `HeadsetStreams.qml:17-18`, `OrbitGhost.qml:64`, `OrbitRadio.qml:26`.
- `Pipewire.defaultAudioSink`: `AudioRoute.qml:29,114,122,152`, `OrbitGhost.qml:48`, `TogetherSession.qml:246`.
- `Pipewire.linkGroups`: `RadioWatch.qml:16`.
- Trackers: `PwNodeLinkTracker` in `CentreWatch.qml:17` and `HeadsetStreams.qml:20,24`; `PwObjectTracker` in many places; `PwNodePeakMonitor` in `ScopeFeed.qml:92`.
- **Volume and mute writes:** `Route.js:200-201,207`, `AudioRoute.qml:197-198`, `RouteDevice.qml:133`, `TogetherSession.qml:376-377`.
- Watching changes made elsewhere: `HeadsetLevelWatch.qml:44-53` (`onVolumeChanged` plus the `Target.fromHeadset` echo book).

**Biggest ownership question:** `Route.js` / `Volume.js` / `Keys.js` move to the daemon, but the volume writes and the echo detection use Quickshell's PipeWire objects. Either:
- the daemon decides and returns `{node, level}` for QML to write. That keeps Quickshell as the only writer and keeps the echo book (`AudioRoute`) coherent, but costs a round trip per step;
- or the daemon writes through the pulse protocol (a). Then the echo book must move to the daemon, and Quickshell's view arrives later, so a race is possible.

### Quickshell.Services.UPower
`UPower.devices` (`DeviceLog.qml:73`). If battery/charge/wear move: zbus `org.freedesktop.UPower` (`EnumerateDevices`, `DeviceAdded`, `PropertiesChanged`), or QML forwards it.

### Quickshell.Services.Mpris
`Mpris.players` with `pause()`/`play()` (`WearHeadset.qml:49-50,75-77`). If wear moves: zbus on `org.mpris.MediaPlayer2.*`, or the daemon emits "pause apps X" and QML calls Mpris. Keeping it in QML is simpler; it is UI-adjacent.

### Quickshell.Io
- `IpcHandler` in `OrbitIpc.qml:68` (24 commands, `:73-294`). It stays in QML and relays to orbitd.
- `Quickshell.env` in `ReportService.qml:131`.

### Quickshell.Wayland
`ToplevelManager` (`OrbitBluetoothDesktop.qml:73`). Stays.

### Qt Multimedia
`SoundEffect` ×4 (`SoundFx.qml:34-52`). Stays in QML.

### DMS `qs.Services` / `qs.Common`
All stay in QML:
- `BluetoothService` (`.adapter`, `.enabled`, `.available`, `.discovering`, `pairDevice`, `connectDeviceWithTrust`, `setBluetoothEnabled`, `toggleBluetooth`): `OrbitState.qml:93-95`, `OrbitConnections.qml:30,33,57`, `AdapterNotice.qml`, `OrbitBluetoothWidget.qml`.
- `DMSService.onBluetoothPairingRequest` and `PopoutService.ensureBluetoothPairingModal` (`OrbitBluetoothDaemon.qml:136-145`).
- `PluginService.setGlobalVar` (`:175`, every publish to the surfaces), `.globalVars` (`OrbitDaemonData.qml:13`), `.savePluginData` (`Prefs.qml:145`), `.getPluginPath` (`UninstallSweep.qml:49`).
- `SettingsData` (`getPluginSettingsForPlugin` in `Prefs.qml:18,30`; `reduceMotion`; `_selfWrite` and `soundVolumeChanged` in `DmsQuiet.qml:31,36`; `desktopWidgetInstances`).
- `SessionService.locked`, `IdleService.isShellLocked` / `.monitorsOff` (`OrbitState.qml:98`), `BatteryService.batteryAvailable` (`OrbitCore.qml:93`), `CompositorService.isNiri` with `NiriService.workspaces`/`.windows` (`OrbitBluetoothDesktop.qml:45`, `VolumeKeys.qml:20`), `ToastService.showWarning`.
- **Constraint:** settings persistence is DMS's (`plugin_settings.json`, written by `PluginService`). orbitd must not write that file. QML sends the prefs to the daemon at start and on each change, and the daemon asks QML to persist things like `togetherHabits` (`HabitLog.qml:51`) and `pcLevels`.

## 3. Risk list, most serious first

1. **Static musl versus PipeWire** (section 0). It rules out `pipewire-rs` and `libpulse`. Choose between spawning stock tools (`pipewire -c`, `pacat`, `wpexec`; not the `pw-*` tools, which a default install lacks), a pure-Rust pulse client, or both.
2. **Uninstall sweep after the binary is deleted** (F6). Needs a self-preserving daemon design, which goes against "dies with the shell".
3. **Ownership of volume writes and echo detection** between Quickshell PipeWire and orbitd (section 2). Plus the key-press path niri → `dms ipc` → QML → orbitd.
4. **Volume tick** must stay out of the smart filter the copies read (NAK-251). *Corrected:* the original line said this was not possible through the pulse protocol. It is, through a `node.link-group` shared with the filter, measured on PipeWire 1.6.11 (A8); it relies on WirePlumber's smart-filter rule.
5. **cava, 60 lines/s**: through the daemon, in-daemon FFT, or stays in QML. That decision contradicts "no Process in QML".
6. **`pw-top` quantum** has no library route without libpipewire, and `pw-top` itself needs pipewire-utils: today the quantum is simply left out without it.
7. **Bluetooth sockets on musl**: no `bluetooth.h`. Hand-written sockaddr structs, plus a non-blocking connect with 8 s timeouts.
8. **Two sources of BlueZ truth** (Quickshell.Bluetooth in QML, zbus in orbitd) for disconnect, forget and trust decisions.
9. **CPU figure in the report** changes meaning (R2).
10. **CI and tests** (CLAUDE.md workflow): the Python test suites (`anc/tests`, `tick/tests`, `uninstall/tests`) become `cargo test`. `tests/qml/run.sh:51` itself runs `python3` (a stub generator), so it is a dev-only Python dependency to decide on.

## 4. Process count, before and after

**Today, at rest:** 0 processes unless the PC filter (A6) or the ANC live/wear sessions (B4) are on.

**Today, in use:**
- one-shots per opening: A1–A5, B1–B3;
- residents: A6–A9 and B4, up to about 4 tick players (each python3 + one pacat) + N loopbacks (`pipewire -c`) + 1 cava + N ANC helpers.

**With orbitd and choice (b):**
- 1 orbitd;
- 1 resident graph reader (a `wpexec` script, or `pw-dump -m` where pipewire-utils is installed), only while something needs graph data;
- the same `pipewire -c` loopbacks, `pacat`, `cava`, optional `pw-top`, `dms` and `journalctl` children;
- every `pactl`, `busctl` and Python process disappears.