# Daemon architecture and data flow: how it works now, and how it would split into a thin QML side and orbitd

I only read files and edited nothing. Paths are relative to the plugin root. DMS's PluginService is at `/usr/share/quickshell/dms/Services/PluginService.qml`.

## 1. The daemon today (`OrbitBluetoothDaemon.qml`, 182 lines)

What it creates, in order:

| Line | Object | Role | Processes it runs |
|---|---|---|---|
| 38 | `UninstallSweep` | Erases traces on uninstall | `python3 -c <script>` detached, on destruction (`UninstallSweep.qml:287`) |
| 43 | `Prefs` | View over the plugin settings | none |
| 49 | `AncService` → `_publish("anc")` | ANC sessions, one per headset | `python3 -E -s anc/orbit_anc.py <addr> <family>`, name passed in env `ORBIT_ANC_NAME` (`AncService.qml:98`) |
| 59 | `WearPause` → `WearHeadset` → `HeadsetStreams` | Pause/resume through Quickshell MPRIS | none |
| 69-76 | `_eraseOldPictures` | One-time cleanup | `rm -rf ~/.cache/orbitBluetooth/pictures` (line 74), then sets `realPictures=false` |
| 80 | `AudioRoute` → `_publish("route")` | Two volumes, key target, tick | see the rows below |
| | ↳ `RouteDevice` (one per BT device) | Absolute-volume probe, PC-level filter | `busctl tree --list org.bluez`, `busctl --json=short get-property … MediaTransport1 Volume`, one `pw-loopback` per filter (`RouteDevice.qml:60-117`) |
| | ↳ `VolumeTick` | Tick sound | up to `Volume.MAX_TICKS` × `python3 -I tick/orbit_tick.py <sink> <wav>`, fed `t <gain>\n` |
| | ↳ `TogetherSession` → `TogetherLink`, `MemberLatency`, `HeadsetLevelWatch` | Listen together | one `pw-loopback` per copy (through bash watching stdin); `pw-dump` per latency read |
| 89 | `HabitLog` | Learns groups | writes `togetherHabits` |
| 96 | `VolumeKeys` (`claim()` at start) | Volume keys | `dms keybinds show niri`, `dms keybinds set …` (`Keys.js:35,45,49`) |
| 105 | `DmsQuiet` | Silences DMS's volume sound around Orbit's writes | Binding on `SettingsData` |
| 136 | Connections on `DMSService.onBluetoothPairingRequest` | Pairing prompt | `PopoutService.ensureBluetoothPairingModal().show()` |
| 148 | `ReportService` | Anonymous report | `Gather.PROBES`: `dms version`, `quickshell --version`, `niri --version`, `rpm -q qt6-qtbase`, `cat /etc/os-release`, `cat /etc/hostname`, `journalctl --user -u dms -n 300 -o cat`; plus `/proc/self/stat` twice |
| 157 | `DisconnectDelays` → `_publish("disconnectDelays")` | Delayed disconnect | one Timer per pending delay |
| 163 | `OrbitIpc` | `dms ipc call` commands | none |
| 179 | `DeviceLog` → `_publish("since"/"batteryLog"/"power")` | Connection times, battery, UPower | FileView on `/sys/class/power_supply/*/device/uevent` |

The daemon also hands surfaces live objects:
- `readonly property alias anc` (line 47), read in `OrbitAnc.qml:18`.
- `route` (line 86), read in `OrbitState.qml:101`.

Two pieces exist but the daemon does not create them: `BatteryHistoryStore.qml` ("not loaded by any view yet", line 8) and `ConnectRulesRunner.qml` (same).

The settings page makes its own copies of two services:
- `ReportService` at `components/settings/ReportRow.qml:22`.
- `VolumeKeys` at `components/settings/VolumeKeysRow.qml:19`.

That gives two `VolumeKeys` state machines that can run `dms keybinds set` at the same time.

## 2. What the daemon publishes

`_publish(name, v)` calls `PluginService.setGlobalVar("orbitBluetooth", name, v)` (`Daemon.qml:174`). Every call copies the whole `globalVars` object (`PluginService.qml:1284-1292`), so every binding on `PluginService.globalVars`, for every plugin, re-evaluates.

| Name | Payload | Producer | Readers |
|---|---|---|---|
| `anc` | `{addr: {status:"connecting"\|"ready"\|"error", error, model, features:{modes,chat,chatEnds,…}, state:{mode,ambient,voice,chat,chatEnds,wearing,battery…}, live:bool, at:ms}}` | `AncService._setState` (line 77), merged by `AncSnapshot.merge` | `OrbitAnc.infoFor` (line 22) |
| `route` | `{addr: {sink:nodeName, pc:virtualNodeName\|"", absolute:-1\|0\|1}}` | `AudioRoute._refresh` (line 90) | No reader. Surfaces use the live `route` object instead |
| `disconnectDelays` | `{ends:{addr: endEpochMs}, sands:bool}` | `DisconnectDelays._push` (line 220) | No reader found in the repo: a dead publish |
| `since` | `{addr: epochMs}` | `DeviceLog.onConnection` | `OrbitDaemonData.sinceFor` (line 19); also drives the 1 s ticker (line 37) |
| `batteryLog` | `{addr: [[epochMs, percent], …]}`, at most 64 samples | `DeviceLog.onBattery` | `OrbitDaemonData.batteryLogFor` |
| `power` | `{addr: {state, percentage, timeToFull, timeToEmpty, changeRate, health}}` | `DeviceLog.setPower` | `OrbitDaemonData.powerFor` |
| `beamStyle` | `""` or a style string | `OrbitIpc.beamStyle` (line 121) | `OrbitDaemonData.beamStyle` (line 17) |

**The data flow does not go mainly through `globalVars`.** Surfaces call live JS/QML objects on `pluginDaemonInstances.orbitBluetooth.route` and `.anc` directly, and those calls return answers synchronously:

- **Route** (counted with grep):
  - lookups: `known()` ×10, `wiredSink()` ×6, `pcNode()`, `deviceNode()`, `ownNode()`, `find()`, `current`, `target`, `marked` (`DeviceBody.qml:219`), `audioDevices()`, `mainPart()`;
  - level writes: `touch()` ×7, `stepNode()` ×4, `writeLevel()`, `writeLevels()`, `writeMuted()`, `setLevel()`, `toggleMute()`, `stepFor()`, `touchLevel()`, `wiredSinks()`, `wiredFilter()`.
- **The Listen together session** (`route.together`):
  - state: `members`, `active`, `source`, `sharedNode`, `sharedNodes`, `memberNode()`, `nameOf()`, `isMember()`;
  - actions: `start()`, `add()`, `remove()`, `end()`, `join()`, `setDelay()`, `decline()`;
  - checks: `check()`, `relevant()`, `memberCheck()`, `dropCheck()`, `isDeclined()`, `declined`;
  - signals: `latencyUnknown`, `ended`, `memberLeft`;
  - internals read from outside: `_sinks`, `_signature`, `_copies`.
- **ANC**: `service.send()` and `service.watch()` (`OrbitAnc.qml:28-33`).

Many surfaces hold live **`PwNode` objects** and bind to `node.audio.volume` and `node.audio.muted`, or write them:
- `TwoLevels.qml:32,42,43,120`
- `OrbitCentre.qml:132`
- `GroupVolume.qml:28,94`
- `WiredBody.qml:36`
- `RadarView.qml:165`
- `OrbitRadar.qml:98-129`
- `CentreVolume.qml:20`

The bar widget, the Control Center tile (`OrbitBluetoothWidget.qml:38-56`) and the desktop widget read only DMS's `BluetoothService`, never daemon state.

## 3. IPC commands (`dms ipc call orbitBluetooth …`, `OrbitIpc.qml`)

Every handler returns a string synchronously.

| Command | Line | Where the answer comes from |
|---|---|---|
| `beamStyle <pulse\|filament\|chain\|horizon\|reset>` | 117 | Publishes `beamStyle` |
| `disconnectIn <device> <1..1440>` | 126 | `delays.start` |
| `cancelDisconnect <device>` | 131 | `delays.stop` |
| `anc <nc\|ambient\|off\|adaptive>` | 136 | `ancService.primary()`, then `send` |
| `ancCycle` | 147 | `cycle` |
| `chatEnds <short\|standard\|long\|never>` | 156 | Needs `snapshots[addr].features.chatEnds` |
| `wearStatus` | 170 | JSON of `Wear.report` |
| `deviceVolume <lvl>` | 190 | `route.setLevel` |
| `pcVolume <lvl>` | 196 | `route.setLevel` |
| `togetherVolume <lvl>` | 203 | `GroupVolume.setLevel` |
| `volumeKeys on\|off\|status` | 212 | "unknown (ask again)" on the first status |
| `volume up\|down` | 230 | `route.stepHeard` |
| `hidden` | 240 | Reads prefs |
| `unhideAll` | 247 | Writes prefs |
| `together <2-4 devices>` | 256 | Refusal note from `Together.refusal` |
| `togetherAdd`, `togetherRemove`, `separate` | 263-277 | Same kind of refusal note |
| `togetherStatus` | 280 | JSON |
| `togetherOutputs` | 288 | JSON from `Pipewire.nodes` |
| `wiredDelay up\|down\|±N\|N\|reset\|status` | 295 | Writes `togetherFineDelay` |
| `togetherDelay <device> <0..1000>` | 308 | Session only |
| `diagnostics` | 328 | Two calls: the first starts the report, the next one takes it |
| `ancStatus` | 338 | JSON of `snapshots[addr].state` |

## 4. Where state lives

**In memory only:**
- `DeviceLog`: `since`, `batteryLog`, `power`.
- ANC: `snapshots`, `_viewers`, `_queue`, `_leaving`, `_reconnected`.
- `DisconnectDelays._pending` (says "never written to disk").
- Together: `members`, `delays`, `declined`, `_wiredNames`.
- Route: `touched`, `lastMember`, `_written` (the echo book, `Target.expect`), `_stepState`.
- `beamStyle` set through IPC.
- `VolumeKeys`: `keys`, `_mine`, `_back`.
- `ReportService.report`.
- The `Log.js` ring of 200 entries (shared through `.pragma library`). Only E/W lines go to `console.error`/`warn`, and so to the journal.
- `HabitLog._members` and `_since`.

**Plugin settings** (`PluginService.savePluginData` → `SettingsData.setPluginSetting`, i.e. DMS's `plugin_settings.json`):
- About 50 keys are read in `Prefs.qml:39-140`.
- Writes from daemon code:
  - `pcLevels` (`AudioRoute.qml:87`, 800 ms debounce in `RouteDevice.qml:140-149`)
  - `togetherHabits` (`HabitLog.qml:324,345`)
  - `keysOrbit` and `keysReturned` (`VolumeKeys.qml:60,67,73`)
  - `hiddenDevices` (`unhideAll`)
  - `togetherFineDelay` (`wiredDelay`)
  - `realPictures=false` (`Daemon.qml:75`)
  - the 11 `retiredKeys` set to null (`Daemon.qml:127`)
- Writes from surfaces: `hiddenDevices`, `hiddenSectionOpen`, `glyphOverrides`, plus everything the settings page writes.

**Cache folder** (`~/.cache/orbitBluetooth`):
- `pictures/` is erased once.
- `battery/history.json` (mode 0600 in a 0700 folder, through a `Process` writer in `BatteryHistoryStore.qml:84-120`) exists but is not wired in.
- The uninstall sweep erases the whole folder.

## 5. Every place QML writes to DMS or system state

1. **`DmsQuiet`**: `Binding { target: SettingsData; property: "soundVolumeChanged"; value: false; restoreMode: RestoreBindingOrValue }` (`DmsQuiet.qml:217-223`). It also writes `SettingsData._selfWrite = false` directly (line 212) to re-arm DMS's save flag. It only works in-process, so it must stay in QML.
2. **`SessionData.suppressOSDTemporarily()`** in `CentreVolume.qml:22`, `PlanetControl.qml:43,55`, `GroupVolume.qml:44,59,70`, `TwoLevels.qml:180,190,198` and `OrbitRadar.qml:106,120,134`. Stays in QML.
3. **`dms keybinds set niri …`** through `VolumeKeys`, at every start (`claim()`) and from the button or IPC. It edits niri's `binds.kdl` through DMS.
4. **`PopoutService.ensureBluetoothPairingModal().show(data)`** (`Daemon.qml:140`). Stays in QML.
5. **`BluetoothService.pairDevice` and `connectDeviceWithTrust`** (`OrbitConnections.qml:30,33,57`). These are UI actions.
6. **`device.disconnect()`** on Quickshell Bluetooth: `AncService.qml:168,178,188` and `DisconnectDelays.qml:286`.
7. **PipeWire writes**:
   - `node.audio.volume` and `node.audio.muted` (`AudioRoute.writeLevels:197-198`, `Route.writeLevel`, `RouteDevice.qml:132`);
   - `pw-loopback` virtual sinks `orbit_pc_*` and `orbit_wired_*` (smart filters);
   - the loopback copies.
8. **MPRIS pause/play** (`WearHeadset`).
9. **The uninstall script** edits DMS's `settings.json`, `plugin_settings.json` and `session.json` (bar, Control Center and desktop widgets, positions) and gives the keys back with `dms keybinds set`.

## 6. Proposed split

### Thin QML daemon (about 150 to 250 lines)

- **Starting orbitd**: one `Process` running `bin/orbitd` with `stdinEnabled: true`, `SplitParser` on stdout, and stderr dropped or parsed (see logging). Arch selection: either a tiny POSIX `sh` launcher (`exec "$dir/orbitd-$(uname -m)"`) or a `uname -m` Process once. sh is not Python, but please confirm the launcher is acceptable.
- **A small `OrbitdClient` object** exposed as `pluginDaemonInstances.orbitBluetooth.orbitd`:
  - `send(cmd, args)` as fire-and-forget;
  - `request(cmd, args, cb)` with an `id`, the callback runs on the matching `reply`.
- **Publishing state**:
  - Low-rate state goes to `globalVars` under the current names, so `OrbitDaemonData` and `OrbitAnc` keep working: `anc`, `since`, `batteryLog`, `power`, `disconnectDelays`, `route`, `beamStyle`, plus new names `together`, `keys`, `orbitd` (status).
  - High-rate state (levels, key target) goes on plain properties of the daemon instance, not `globalVars`, because of the whole-object copy (section 2).
- **`IpcHandler`**: it forwards to orbitd and answers from the state mirror. It cannot wait for a reply (the problem is spelled out in the questions below).
- **What stays in QML** because it touches the shell process:
  - `DmsQuiet`: orbitd sends `levelWriting`, or better QML calls `hold()` itself before sending a level command;
  - `suppressOSDTemporarily`;
  - the pairing modal;
  - `Prefs` (DMS owns the storage): QML pushes a `prefs` snapshot to orbitd at start and on every `onPluginDataChanged`, and orbitd asks QML to save with `{"t":"save","key","value"}`;
  - `PluginService.availablePlugins` (the Sands flag) is sent to orbitd as a fact.
- **Settings page**: the `VolumeKeysRow` and `ReportRow` copies go away and talk to the daemon's orbitd.

### orbitd owns

- **ANC**: all vendor protocols, the RFCOMM/L2CAP sockets, the engines (`demand`/`live`/wear), `_viewers` refcounts, the chat-off-on-disconnect sequence, the 2.5 s reconnect wait and the 4 s leave timeout.
- **Wear pause**, including the MPRIS calls over zbus.
- **BlueZ and UPower over D-Bus**: devices, connected, battery, `MediaTransport1.Volume` (replacing busctl), `Device1.Disconnect`, HID_UNIQ from sysfs. This is the `DeviceLog` state.
- **PipeWire**:
  - the graph (replacing `pw-dump`, `pactl list sinks` and `pw-top`), latencies;
  - the virtual sinks (PC level), Listen together copies and wired filters;
  - level and mute writes and the echo book (`Target`);
  - smart steps and the key target (`Route.js`, `Target.js`, `Steps.js`, `Volume.js`, `Audiophile.js`, `Codecs.js`);
  - the tick stream (replacing `orbit_tick.py`).
- **Together**: `Together.js`, `Choice.js`, `Wired.js`, `Delay.js`, `Habits.js`, `Member.js`.
- **Other logic**: `ConnectRules.js`, `DeviceCatalog.js`, `DisconnectPhrase.js` and the delay timers, battery/charge/wear estimates (`Charge.js`, `Endurance.js`, `BatterySessions.js` and the history file).
- **Diagnostics**: Gather/Redact/Report and the CPU reading of the shell (`/proc/<ppid>/stat`) and of itself.
- **`dms keybinds`** run as a subprocess (Keys.js).
- **The uninstall sweep** (replacing `orbit_uninstall.py`) and the one-time cleanups (pictures `rm`, retired keys).

### JSON lines vocabulary (draft)

Envelope: `{"t":<type>, …}`, compact.

**Commands, QML → orbitd:**
- `hello {proto, plugin, pid, xdg:{cache,config,state,runtime}, pluginDir, settingsPath, pluginSettingsPath, sessionPath}`
- `prefs {…full map…}`, and `prefs.delta {key, value}`
- `facts {sands:bool, niri:bool, reduceMotion}`
- `anc.watch {addr, on}`, `anc.set {addr, key, value}`, `anc.cycle {addr}`, `bt.disconnect {addr}` (the chat-off sequence happens in orbitd)
- `level.set {target:"device"|"pc"|"group"|"member", addr?, value:0..1|"up"|"down"|"+5"}`, `level.step {dir, group?}`, `mute.toggle {addr}`, `touch {addr|"pc"|""}`
- `together.start|add|remove|join {members}`, `together.end`, `together.delay {member, ms}`, `together.decline {key}`, `wired.watch {on}`
- `delay.start {device, minutes}`, `delay.stop {device}`
- `keys.enable|disable|refresh`
- `report.request {via}`, `report.take`
- `log {code, fields}`, so QML events reach orbitd's ring for the report
- `scope.*` only if the vectorscope ever moves (`ScopeFeed`/cava is a UI process, out of this scope)
- Every command can carry `id`, and the answer is `{"t":"reply","id","ok","why"?,"data"?}`.

**Events, orbitd → QML:**
- `hello {proto, version, sha, arch}`
- `state.anc {addr: snapshot}` (full map, or per address with null to drop)
- `state.devices {since, batteryLog, power}`, as three separate events to keep today's names
- `state.route {addr:{sink, pc, absolute}, current, target, marked}`
- `state.levels {nodeName:{volume, muted}}`, coalesced to about 30 Hz at most
- `state.together {active, members, source, delays, names, latencies, declined, sharedNode, memberNodes}`
- `event.together {kind:"ended"|"memberLeft"|"latencyUnknown", why, addr}`
- `state.wired {outputs:[{sink,label,bus,formFactor,plugged}], ready}`
- `state.delays {ends, sands}`
- `state.keys {keys:"unsupported"|"unknown"|"dms"|"orbit"|"custom", busy, failed}`
- `state.wear {addr:{state, held}}`
- `level.writing {}`: QML calls `DmsQuiet.hold()` on it. It arrives a few ms late; a fix for that is under the questions.
- `save {key, value}`: QML runs `PluginService.savePluginData`. Covers pcLevels, togetherHabits, keysOrbit, keysReturned, togetherFineDelay, hiddenDevices, realPictures, retired keys.
- `report {text}`
- `log {code, fields}`: QML runs `Log.event`, which keeps the allowlist and journal rules in one place
- `reply`, and `bye {reason}`

## 7. Lifecycle points

- **Start**: orbitd starts when the QML daemon is created. DMS creates daemons through `_daemonSpawnQueue` and a timer (`PluginService.qml:575,628-641`).
- **Stop**: on daemon destruction, close stdin and orbitd exits on EOF.
  - On `reloadPlugin`, `prevDaemon.destroy()` runs before the new one spawns, so two orbitd can overlap for a moment.
  - `globalVars` is **not cleared** on unload, so stale `anc`/`since` values stay after a disable.
  - Today's PW children rely on "bash watching stdin". orbitd needs EOF-on-stdin and `PR_SET_PDEATHSIG` for its own children (pw-loopback, if those stay processes). Virtual sinks must vanish if the shell crashes.
- **Crash and restart**: `onExited` restarts with backoff (for example 0.5, 1, 2, 4 … 30 s; give up after N crashes in 60 s and publish `orbitd:{state:"failed"}` with a note in the UI). All memory state is lost on restart (since, batteryLog, ANC sessions, delays, together session, echo book):
  - Option A: QML keeps the last `state.*` and sends it back in `hello.restore`. The Listen together session cannot be restored if its loopbacks died.
  - Option B: accept the loss.
  - After a restart, ANC must not loop on an error. Today a session that errors stays closed until the user asks again (`AncService.qml:278`), and orbitd needs the same rule.
- **Version mismatch**: `git pull` while the shell runs leaves old QML in memory and a new binary on disk.
  - `hello.proto` (an integer) is compared on both sides. On mismatch QML stops orbitd and shows "restart the shell".
  - Also compare `plugin.json` version against the version built into the binary.
  - SHA-256: QML cannot hash (Qt has no SHA-256 in QML), so the check is either orbitd checking itself (pointless) or CI only.
- **Uninstall**: the binary is deleted with the folder. A running orbitd survives the unlink, so it can do the sweep itself after stdin EOF: it checks whether `plugin.json` is gone, waits 4 s (`GRACE_SECONDS`), checks again, sweeps and exits. orbitd must then outlive the shell: `setsid` or a double fork on that path only, against the "dies with the shell" rule.
- **Multiple shells** (two `quickshell -c dms`, a nested test shell, `scripts/preview`):
  - two orbitd would both create `orbit_pc_<addr>` sinks and both open the single RFCOMM channel of a headset;
  - two orbitd would run `dms keybinds set` twice.
  - Proposal: `flock` on `$XDG_RUNTIME_DIR/orbitBluetooth/orbitd.lock` (tmpfs, not a log). A second instance answers `hello {busy:true}` and stays passive.
- **Logging (no log files)**:
  - orbitd never writes files except the battery history and its own sweep.
  - Errors are `log` events on stdout with Codes.js-style codes, and QML forwards them through `Log.event`.
  - stderr is read and dropped. A debug mode (env `ORBITD_DEBUG=1`, like `ORBIT_ANC_DEBUG`) prints raw packets to stderr only when run by hand.
  - Reason: anything on stderr can reach DMS's journal through Quickshell's Process logging, and the diagnostics report reads that journal.
- **Exec bit**: git keeps 100755. A plugin installed from a zip (DMS plugin browser?) may lose it.

## 8. Open questions for the owner

1. **IPC answers are synchronous.** Should `together`, `togetherAdd`, `chatEnds`, `deviceVolume` and the like answer from a QML mirror of state that orbitd pushed (so checks like "is it connected, does it have absolute volume" must be pre-published as facts), or answer "OK" at once and report a refusal later as a toast? Or should every command use the two-call pattern `diagnostics` already uses?
2. **Live `PwNode` objects in surfaces.** Should the UI keep reading levels through Quickshell's native `Pipewire` binding (display only, for zero lag on sliders and the polar view) and send writes to orbitd? Or should orbitd stream every level, which raises latency and the echo-book problem? And who writes `node.audio.volume` while a slider is dragged?
3. **PipeWire from a static musl binary.** libpipewire cannot be linked statically (it loads modules with `dlopen`). The choices:
   - (a) keep `pw-loopback`, `pw-cat` and `pw-dump --monitor` as child processes;
   - (b) implement the native PipeWire protocol in pure Rust;
   - (c) drop "static" for PipeWire.
   
   This decides how the tick, the virtual sinks and the event stream work.
4. **Coarse or fine routing?** Should surfaces call fine-grained routing (`touch`, `stepNode` per gesture) over JSON, or should gestures be sent as coarse intents?
5. **`DmsQuiet` timing.** The DMS sound must be held *before* the level moves. Is it acceptable that QML calls `hold()` itself before sending any level command, with the keys case triggered by the IPC handler?
6. **What survives an orbitd restart?** `since`, `batteryLog`, pending delays, a Listen together session: restore them from QML, or lose them?
7. **Where is the single-instance lock, and what does a second shell do** (passive, refuse, or take over)?
8. **Uninstall.** May orbitd outlive the shell (`setsid`) for the 4 s grace and the sweep, now that `python3 -c` is gone?
9. **Arch selection.** Is a POSIX `sh` launcher acceptable, or must QML pick the binary with `uname`? What happens on an arch with no binary (riscv64)? A clear "unsupported" note, with no fallback?
10. **`hello.proto` mismatch.** Hard stop with "restart the shell", or best effort?
11. **Settings.** Does orbitd get the full `prefs` map, or only the keys it needs? Should all writes stay in QML (orbitd sends `save`)?
12. **Settings page instances.** Should the settings page's own `VolumeKeys` and `ReportService` go away and talk to the daemon? That fixes the duplicate state machines.
13. **`globalVars` rate.** Publish only low-rate state through it, and put levels and the target on daemon instance properties?
14. **Dead pieces.** Delete the dead `disconnectDelays` and `route` publishes, or are surfaces planned for them? Should `BatteryHistoryStore` and `ConnectRulesRunner` (not wired yet) be wired at the port, or ported as-is and stay dormant?
15. **Wear pause.** Move wear pause and its MPRIS control into orbitd over zbus (it is not in the owner's list explicitly)?
16. **Diagnostics.** Should orbitd read the shell's CPU (`/proc/<ppid>/stat`) as well as its own? Should the report merge two rings (QML events forwarded to orbitd), or one ring in orbitd?
17. **Timers that need a running orbitd.** Pending delays and the 4 s leave timeout: is orbitd always running while the plugin is loaded, even with no device? That is about 1-3 MB resident, compared with today's "nothing runs at rest" promise in comments such as `UninstallSweep.qml:242` and `ReportService.qml:12`.
18. **The `cava` process.** `ScopeFeed.qml:68` runs `bash -c 'exec cava …'`. Does it stay UI-side, or move into orbitd? It is outside the owner's list, but it is a process.
