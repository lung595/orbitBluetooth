# orbitd: synthesis, open decisions, risks, migration order

Read-only pass. I edited no files. One fact I checked myself, on top of the five reports: on this machine `pw-loopback`, `pw-cat`, `pw-link`, `pw-dump`, `pw-top` and `wl-copy` are **all missing**. `pactl`, `busctl`, `cava` and `python3` are present, with wireplumber 0.5.19 and pipewire-pulseaudio 1.6.11. So today the PC filter (`RouteDevice.qml:107`), the Listen together copies (`TogetherLink.qml:59`), the tick, latency and the graph facts already fail silently on the owner's own machine. This weighs on decision P1.

---

## 1. What orbitd must do (one screen)

**Shape:** one resident process per shell. JSON lines on stdin/stdout, an `{"t":…}` envelope, optional `id` → `reply`. A single-instance lock. It exits on stdin EOF. It never writes `plugin_settings.json`: it asks QML with `save {key,value}`.

| Module | Replaces | Size | Crates |
|---|---|---|---|
| core: loop, envelope, hello/proto, lock, child supervisor (PDEATHSIG, kill on EOF) | — | M | `serde`, `serde_json`, `tokio` (rt current-thread, io, time, process, signal) **or** `polling`/`mio`; `libc` |
| bt-sock: hand-written `sockaddr_rc`/`sockaddr_l2`, non-blocking connect + timeouts, `AsyncFd` | `orbit_anc.py:65-105` | S | `libc` |
| sdp client | `anc/sdp.py` (110 l, no tests) | S | — |
| anc runner: one task per address, linger 1.5 s / grace 6 s / early exit 0.2 s / handshake 10 s / connect 8 s / settle 0.5 s, pending/deferred queues, 64 KiB cap, `anc.ended` event | `orbit_anc.py` (225 l) + `AncService.qml` engine logic | M | — |
| anc protocols: 13 families, sans-IO `trait Protocol` | `anc/protocols/*` (2,160 l) | **L** (~3–3.5k Rust) | `getrandom` (Xiaomi), hand-written CRC16/sum8/SAFER+ |
| bluez + upower + mpris over D-Bus | `busctl` ×3 sites, `DeviceLog` sources, Wear MPRIS | M | `zbus` (pure Rust) |
| pipewire access (graph, props, Latency, quantum, volume, links) | `pw-dump`, `pactl list sinks`, `pw-top` | **M–L**, depends on P1 | depends on P1: spawn tools / pure-Rust pulse client / native-protocol client |
| loopbacks: PC filter, Together copies, wired filter, diff over `HashMap<key,Child>` | `Route.filterArgs`, `Together.commands/diff`, `TogetherLink.qml` | M | — |
| tick: mixer (HEADROOM 0.5, CHUNK 480, FADE 240, 2 voices, 4 sinks, 20/s) + playback with autoconnect off | `tick/orbit_tick.py` (214 l) | S (DSP) + S…L (output, P2) | `hound` optional |
| volume/route logic: Volume, Keys, the A part of Route, echo book if moved | `Volume.js`, `Keys.js`, part of `Route.js` | M | — |
| together logic: plan/args/commands/diff, latencies, wired list | A parts of Together/Wired/Delay | M | — |
| battery/charge/wear/device: `Charge.analyze`, Endurance, BatterySessions + history file, Wear state machine, HID_UNIQ sysfs | `card/Charge.js`, `Endurance.js`, `BatterySessions.js`, `Wear.js`, `DeviceLog.qml` | M | `sha2` |
| rules/delays: ConnectRules, DisconnectPhrase timers, BlueZ `Disconnect` | `ConnectRules.js`, `DisconnectPhrase.js` | S | — |
| diagnostics: Gather/Redact/RedactRules/Report/Cpu, probes spawn, ring | `diagnostics/*` (~825 l) | M | `regex` |
| keys: spawn `dms keybinds show/set` | `VolumeKeys.qml` processes | S | — |
| uninstall sweep (self-detach, 4 s grace, atomic JSON edits, give keys back) | `uninstall/orbit_uninstall.py` (215 l) | S/M | `serde_json` with `preserve_order`; hand-rolled tmp + rename |
| golden twins: `Member.key/hash`, `Habits.tag`, `ConnectRules.keyOf`, `BatterySessions.sha256` | — (JS keeps its copies) | S | — |
| CI: musl x86_64 + aarch64, SHA256SUMS, commit-back, tests | nothing exists (`.github/` only has `ISSUE_TEMPLATE`) | M | `rust-toolchain.toml`, `Cargo.lock` |

**Totals:** about 8–11k lines of Rust. Estimated binary size 1.5–3 MB per arch. About 1,950 JS lines move cleanly, plus about 400 lines of the A parts of Route/Together/Wired/Delay. 95 Python tests and about 970 JS checks are the golden reference.

---

## 2. Open decisions

Format for each: **Q**, the options, then **Default**.

### A. Architecture and lifecycle

**A1. Async model.**
- **Q:** tokio or a hand-rolled poll loop?
- **Options:**
  - (a) tokio current-thread: zbus has a `tokio` feature, `AsyncFd` for the BT sockets, `process` for children. About +300–500 KB.
  - (b) `polling`/`mio` plus threads: smaller, but zbus then needs `async-io` alongside, and the 13 timers per session are written by hand.
  - (c) a thread per ANC session plus blocking I/O: simple, but the timers (linger, settle, Sony retry 1.25 s ×3) need channels.
- **Default:** (a). The many timers and the D-Bus plus child-process plumbing are what tokio is for.

**A2. When orbitd runs.**
- **Q:** always while the plugin is loaded, or only on demand?
- **Options:**
  - (a) always on: about 1–3 MB RSS. It breaks the "nothing runs at rest" promise (`UninstallSweep.qml:242`, `ReportService.qml:12`), but the delay timers, the 4 s leave timeout, `DeviceLog` and the uninstall sweep all need it.
  - (b) started lazily by QML on first need: complex, and DeviceLog's `since` would be lost.
- **Default:** (a). Update the comments and the README privacy/resources section.

**A3. Who is the source of truth for BlueZ state.**
- **Options:**
  - (a) orbitd subscribes through zbus `ObjectManager` + `PropertiesChanged` and does disconnect/trust/forget itself. QML only displays from Quickshell.Bluetooth.
  - (b) QML forwards `Bluetooth.devices` as JSON. No D-Bus in the daemon, one more hop.
  - (c) a split: orbitd reads, QML writes. This risks the race noted at `ProfileCheck.qml:40-49`.
- **Default:** (a). ANC chat-off-then-disconnect (`AncService.qml:168-188`) and the delays (`DisconnectDelays.qml:96`) both need to act. Write rule: **only orbitd** writes `Disconnect/Trusted/Blocked/RemoveDevice` for the moved features. UI buttons (`OrbitConnections.qml`) keep DMS `BluetoothService`.

**A4. Wear pause and MPRIS.**
- **Q:** move to orbitd over zbus, or stay in QML?
- **Options:**
  - (a) orbitd: `Wear.js` is class A (168 l, 68 checks).
  - (b) orbitd decides and emits `pause {players}`, QML calls `Mpris.pause()` (`WearHeadset.qml:49-77`).
  - (c) keep all of Wear in QML. This contradicts "wear moves".
- **Default:** (a). It is pure logic plus D-Bus calls that zbus does natively.

**A5. UPower source for battery/power.**
- **Options:** (a) zbus `org.freedesktop.UPower`; (b) QML forwards `UPower.devices` (`DeviceLog.qml:73`).
- **Default:** (a), for the same reason as A3.

**A6. Crash and restart policy.**
- **Options:**
  - (a) QML restarts with backoff 0.5→30 s, gives up after N crashes in 60 s, and publishes `orbitd:{state:"failed"}` with a UI note.
  - (b) no restart.
- **Default:** (a), N=5. An ANC session that errors must **not** auto-reopen after the restart, the same rule as `AncService.qml:278`.

**A7. What survives an orbitd restart.**
- **Options:**
  - (a) QML caches the last `state.*` and sends `hello.restore` (since, batteryLog, pending delays). The Listen together session cannot be restored because its loopbacks died.
  - (b) accept the loss of everything.
- **Default:** (a) for `since` and the pending delays only (cheap, user-visible). (b) for together and ANC.

**A8. Fault isolation inside the daemon.**
- **Q:** should a protocol panic kill one session or the whole daemon?
- **Options:**
  - (a) `panic=unwind`, with `catch_unwind` / a task boundary per ANC session.
  - (b) `panic=abort` with a QML restart: smaller binary, but one bad headset frame drops every feature.
- **Default:** (a). Keep `unwind` and isolate per session. Today there is one process per headset, and this keeps that blast radius.

**A9. Single instance.**
- **Q:** two shells (nested test shell, `scripts/preview`, a `reloadPlugin` overlap, `PluginService.qml:575,628-641`) would both create `orbit_pc_*` sinks and open the same RFCOMM channel. What should the second one do?
- **Options:**
  - (a) `flock` on `$XDG_RUNTIME_DIR/orbitBluetooth/orbitd.lock`; the second instance answers `hello{busy:true}` and stays passive.
  - (b) the second one takes over.
  - (c) the second one refuses and exits.
- **Default:** (a), plus a short wait-and-retry (about 2 s) to absorb the `reloadPlugin` overlap, where the old daemon is destroyed before the new one spawns.

**A10. Arch selection and launcher.**
- **Options:**
  - (a) a POSIX `sh` launcher: `exec "$dir/bin/orbitd-$(uname -m)"`.
  - (b) QML runs `uname -m` once, then starts the right binary.
  - (c) QML reads `/proc/sys/kernel/arch` with FileView: no process.
- **Default:** (c), with (b) as fallback. No extra shell layer, and signals and EOF reach orbitd directly.

**A11. Unsupported arch (armv7, riscv64).**
- **Options:**
  - (a) the UI loads in reduced mode (bar, scene, pairing through DMS) with an "orbitd unavailable on <arch>" note.
  - (b) the plugin refuses to load.
- **Default:** (a). Every feature that needs orbitd shows a disabled state.

**A12. Settings flow.**
- **Options:**
  - (a) QML pushes the full prefs map at `hello` and on each `onPluginDataChanged`.
  - (b) QML pushes only an allowlist of keys orbitd needs.
- Either way orbitd writes back through `save {key,value}` (pcLevels, togetherHabits, keysOrbit/keysReturned, togetherFineDelay, hiddenDevices, retired keys).
- **Default:** (b). Less data crosses, and it doubles as documentation of the dependencies.

**A13. The `globalVars` publish channel.**
- **Q:** `setGlobalVar` copies the whole object and re-evaluates every plugin's bindings (`PluginService.qml:1284-1292`). What goes through it?
- **Options:** (a) low-rate state only (anc, since, batteryLog, power, together, keys, orbitd status), with levels and target as plain properties on the daemon instance; (b) everything.
- **Default:** (a).

**A14. Dead publishes and duplicate state machines.**
- **Q:** what to do about the dead `disconnectDelays` and `route` publishes, and the settings page's own `VolumeKeys` (`VolumeKeysRow.qml:19`) and `ReportService` (`ReportRow.qml:22`)?
- **Default:** delete the dead publishes. The settings page talks to the daemon's single orbitd client. This also fixes two `dms keybinds set` state machines running at once.

**A15. Coarse or fine routing commands.**
- **Options:**
  - (a) coarse intents: `level.step {dir}`, `level.set {target,value}`.
  - (b) mirror today's fine API (`touch`, `stepNode`, `writeLevel`…) one call per method.
- **Default:** (a). Fewer messages, and the daemon owns the decision.

### B. PipeWire, Bluetooth and system access

**P1. How a static musl binary reaches PipeWire.** This blocks everything else.
- libpipewire and libpulse cannot be used from static musl, because libpipewire loads its modules with `dlopen`.
- **Options:**
  - (a) Spawn the CLI tools from orbitd: a resident `pw-dump --monitor` for events, plus `pw-loopback`, `pw-cat`, `pw-link`, `pw-top`. Cheap (S), and the Python tests' fake-PATH approach ports. **But `pipewire-utils` is absent here**, so the plugin keeps a hard runtime dependency that Fedora does not install by default.
  - (b) A pure-Rust PulseAudio-protocol client to pipewire-pulse. Gives sinks with proplists (`api.bluez5.codec`), subscribe events, volume/mute, a playback stream, and monitor capture. It works on this machine. It **cannot** give the Latency/Props params (`AudioGraph.parseDump`), the quantum (`pw-top`), or "autoconnect off + explicit links" (NAK-251). Whether a crate exists (colinmarc `pulseaudio`) and how mature it is: unverified.
  - (c) A pure-Rust PipeWire native-protocol client (SPA POD over `pipewire-0`, fd passing). Registry, props, params, `SetParam` volume, links and metadata are feasible at 1.5–3k lines. Loopback modules need a `pipewire-0-manager` / `load-module` equivalent or a client-node. The tick needs a client-node with shm buffers, which is hard. No mature crate.
  - (d) Drop "static" for one component: a glibc dynamic build linking libpipewire. This contradicts the settled "static musl" decision, so it is listed only for completeness.
  - (e) A hybrid: (b) for events, sink facts and volume; (c) for the read-only registry and params (latency, quality, quantum via Profiler); spawning kept only where unavoidable.
- **Default:** decide after spike S1. The provisional default is (e) without spawned tools if S1 passes. Otherwise (b) for everything pulse can do, plus spawning (a) for loopbacks and the tick, with a clear "install pipewire-utils" notice in the UI and README.

**P2. Tick output path.**
- **Options:**
  - (a) `pw-cat` + `pw-link` children (S; needs pipewire-utils).
  - (b) a pulse playback stream targeted at the sink by name, with `node.dont-reconnect` / `target.object` props. Must be verified not to go through the WirePlumber smart filter (NAK-251).
  - (c) a native-protocol client node (L).
- **Default:** (b) if spike S2 proves no leak into the Together copies; else (a).

**P3. Loopbacks: PC filter, Together copies, wired filter.**
- **Options:**
  - (a) `pw-loopback` children with `PR_SET_PDEATHSIG` + kill on EOF. This replaces the bash `cat` watchdog (`Route.js:101`).
  - (b) pulse `load-module module-loopback` / `module-null-sink` through pipewire-pulse. These modules live in the server, so they **survive an orbitd crash** unless orbitd unloads them, and an orphan-sweep is needed at startup.
  - (c) native-protocol link/adapter objects (L).
- **Default:** (a) if pipewire-utils is accepted as a dependency. Otherwise (b) with an `orbit_*` name-prefix sweep at startup and on EOF.

**P4. Who writes PipeWire volume and owns the echo book.**
- **Options:**
  - (a) QML stays the only writer through Quickshell `node.audio.volume`: zero slider lag, the echo book (`Target.expect`, `HeadsetLevelWatch.qml:44-53`) stays coherent. orbitd only decides targets and steps, and returns `{node, level}`.
  - (b) orbitd writes over pulse/native: the echo book moves, and Quickshell's view arrives later, so races are possible.
  - (c) split: drags and sliders are written by QML; keys, steps and IPC are written by orbitd.
- **Default:** (a). `Route.writeLevel` / `levelNodes` / `deviceSink` take live `PwNode`s and run in gestures (`AudioRoute.qml:182-188`), so they stay JS (class C).
  - Consequence: the "volume tick"'s level math (`Volume.stepsCrossed`, `tickGain`) can still move, because `VolumeTick.play` is fire-and-forget.

**P5. The volume-key path.**
- **Q:** niri → `dms ipc` → QML `IpcHandler` → (orbitd?) → write. Should a key press go through orbitd?
- **Options:**
  - (a) the handler computes the step from cached state and writes in QML (with P4a), then notifies orbitd for the tick.
  - (b) a round trip through orbitd for every press.
- **Default:** (a). Held keys repeat at about 25–30 Hz. Measure with spike S6 before committing to (b).

**P6. cava / vectorscope (`ScopeFeed.qml:68`, about 60 lines/s).**
- It is on neither list.
- **Options:**
  - (a) stays a QML-spawned process, as a per-frame UI feed like `Polar.js`.
  - (b) orbitd spawns cava and forwards frames: a 60 Hz JSON hop.
  - (c) orbitd records `.monitor` via pulse and runs its own FFT (`rustfft`): new DSP to own, but cava goes away.
  - (d) replace it with `PwNodePeakMonitor`, already used at `ScopeFeed.qml:92`.
- **Default:** (a). It is per-frame UI, the stated JS-boundary rule, and it costs zero frames of latency.

**P7. `pw-top` quantum fact.**
- **Options:**
  - (a) keep spawning `pw-top -b -n 2` on demand;
  - (b) read `clock.quantum` / `clock.rate` from the native-protocol `settings` metadata (an approximation of the effective quantum);
  - (c) drop the fact.
- **Default:** (b) if P1 includes native read access; else (a).

**P8. D-Bus library.**
- `zbus` (pure Rust) versus `bluer` / `dbus-rs` (libdbus, C). Every report agrees on zbus.
- **Default:** zbus, no further discussion needed beyond confirmation.

**P9. BT socket layer.**
- **Options:** (a) raw `libc` with hand-written `sockaddr_rc`/`sockaddr_l2` (reversed bdaddr, little-endian PSM); (b) `nix` (lacks them too); (c) `bluer` (no).
- **Default:** (a), in one small `unsafe` module with tests on struct layout and byte order.

**P10. ANC engine semantics.**
- **Options:**
  - (a) keep "demand" vs "live" exactly (open and close per viewer refcount, `AncService.qml:84-88`);
  - (b) orbitd holds connections for all supported connected headsets, and QML only subscribes.
- **Default:** (a) for the first port, so behaviour is identical and verifiable. Revisit later.

**P11. ANC error vocabulary.**
- `Anc.errorText` regex-matches strings (`Anc.js:91-103`).
- **Options:**
  - (a) emit the same fixed strings, byte-identical to Python;
  - (b) switch to error codes (`{"error":"refused"}`) and update `Anc.js`.
- **Default:** (b) in the same step as the port. One table, and no dependence on `io::Error` Display text.

**P12. Who reads `/sys/class/power_supply/*/device/uevent` (HID_UNIQ).**
- **Default:** orbitd (`fs::read_to_string`), together with UPower.

**P13. Device kind and family in the daemon.**
- Endurance and the ANC family need the kind; the user's `glyphOverrides` live in QML.
- **Options:**
  - (a) QML pushes `{addr: kind, family}` it already resolved;
  - (b) a Rust twin of `DeviceCatalog.resolve` (thin coverage: only 5 checks).
- **Default:** (a). `DeviceCatalog.js` runs in about 15 synchronous bindings (`BodyState.qml:20-23`, `Widget.qml:53,99`…), so it **stays JS**, and the decision text needs amending. The ANC family regexes (`Anc.js:9-24`) follow the same rule.

**P14. `Device1.UUIDs` profile check after pairing (`ProfileCheck.qml:33`).**
- **Options:**
  - (a) orbitd reads the UUIDs and also does the trust/block/forget follow-up;
  - (b) orbitd only reads, and QML writes.
- **Default:** (a), consistent with A3.

### C. Distribution and CI

**D1. When binaries are built and committed.**
- **Options:**
  - (a) on release tags only; CI commits the binaries, then moves the tag onto that commit.
  - (b) on every push to `main`: history grows fast, but `main` HEAD always matches.
  - (c) the release commit is made by CI itself from a `release/*` branch: source and binary in one commit, then tagged.
- **Default:** (c). Users get `main` HEAD or a locked SHA (`plugins.lock.json`). **Every reachable commit must carry a matching binary**, so binaries and the QML that needs them land in the same commit.

**D2. What users follow.**
- **Options:**
  - (a) `main` HEAD: go-git fetches every branch, and users land on HEAD.
  - (b) development happens on other branches, and `main` only receives release merges that include binaries.
- **Default:** (b). Development branches are invisible to users, so `main` never holds a source-only commit.

**D3. Binary file naming.**
- **Options:**
  - (a) fixed `bin/orbitd-<arch>`: risks `ETXTBSY` if go-git writes in place while it runs (unverified);
  - (b) versioned `bin/orbitd-<ver>-<arch>`, old one removed in the same commit;
  - (c) QML copies the binary to `$XDG_RUNTIME_DIR` before running it (writes to tmpfs).
- **Default:** (b). Rename-on-update is sidestepped entirely. QML derives the name from `plugin.json` version plus arch.

**D4. Repo growth.**
- About 3–6 MB per release, kept forever in full clones (27 MB today).
- **Options:**
  - (a) accept it;
  - (b) set a hard size budget per binary (for example ≤2 MB, enforced in CI);
  - (c) a history rewrite later: breaks lock SHAs, so never.
- **Default:** (a) + (b). Build with `opt-level="s"`, LTO, `codegen-units=1`, `strip`, and a CI size check.

**D5. Reproducibility proof.**
- **Options:**
  - (a) committed `bin/SHA256SUMS` only;
  - (b) plus a second CI job that rebuilds from the tag and fails on hash mismatch;
  - (c) plus `cargo-auditable`.
- **Default:** (a) + (b). It fits the open-source value, costs a few CI minutes and adds no binary size. (c) optional.

**D6. Toolchain pin.**
- Exact `rust-toolchain.toml` version plus both musl targets, a committed `Cargo.lock`, `--locked`, `--remap-path-prefix`, `SOURCE_DATE_EPOCH`.
- **Q:** which Rust version, and how often is it bumped?
- **Default:** the current stable at the start, bumped only on purpose.

**D7. aarch64 build route.**
- **Options:**
  - (a) the native `ubuntu-24.04-arm` runner;
  - (b) `cross` / `cargo-zigbuild` from x86_64;
  - (c) plain rustup target with the `rust-lld` linker (pure Rust, no C).
- **Default:** (a). Tests run natively on that arch too.

**D8. CI push-back mechanics.**
- Needs `contents: write`, must not re-trigger itself (path filter on `bin/**` or `[skip ci]`), and needs either a bot identity or the default `GITHUB_TOKEN`.
- **Q:** is a bot commit on `main` acceptable?
- **Default:** a `GITHUB_TOKEN` commit with the attribution trailer, triggered only by the release workflow.

**D9. Local development build.**
- Rust is not installed here (no cargo, rustup or musl targets).
- **Options:**
  - (a) install rustup and the targets once on the dev machine (a one-time download for the developer, not users);
  - (b) build only in CI.
  - Also: is a dev override such as `ORBITD_BIN` env or `target/debug/orbitd`, preferred over `bin/` when present, acceptable?
- **Default:** (a), plus a dev override that QML honours only when `bin/.dev` exists. That file is git-ignored, so users never hit it.

**D10. DUX plugin registry policy on committed binaries.**
- Unknown; the rules are not on this machine.
- **Options:** (a) read the registry's CONTRIBUTING / ask its maintainers before step 1; (b) proceed and see.
- **Default:** (a). It is a potential veto.

**D11. Restart requirement.**
- Qt caches each plugin directory's file list until restart (`PLUGINS/README.md:999`), so added QML/JS files fail until `dms restart`.
- **Options:**
  - (a) announce "needs `dms restart`" in the changelog for each release that adds files;
  - (b) put new QML in new subdirectories only;
  - (c) both.
- **Default:** (c). New `components/orbitd/` goes in a new dir, and the changelog says so anyway.

**D12. Runtime dependency list in the README.**
- Python 3 goes; `pw-cat` and others go or stay depending on P1/P2/P3; `wl-copy` is optional.
- **Default:** decided with P1, then the README requirements table (`README.md:18-26`) is rewritten in the same release.

### D. JS / Rust boundary

The settled list conflicts with real synchronous call sites. The owner must resolve these; they refine the decision, they do not reopen it.

**J1. `Habits.js` and the refusal logic needed by `Ghost.js`, which stays.**
- `Ghost.js:74,80,98` calls `Habits.choose`/`bestFirst` and `Together.MAX_LIST_LENGTH`, and `Together.refusal` inside the `OrbitGhost.qml:72` binding.
- **Options:**
  - (a) `Habits.js` stays JS whole (storage is DMS prefs anyway, `HabitLog.qml:51`);
  - (b) orbitd pushes a ready `proposal` and Ghost becomes rendering only;
  - (c) Habits is duplicated in Rust and JS.
- **Default:** (a). It is 165 lines, and Rust would only hand the blob back to QML to save.

**J2. Drag-time eligibility (`Together.refusal`/`joinRefusal`/`memberRefusal`/`merge`/`fits`).**
- These run on every pointer move (`OrbitDrag.qml:52` → `TogetherSession.qml:172-187`).
- **Options:**
  - (a) orbitd pushes a per-output map `{who:{connected,sink,profile}}`; the 40-line combination check stays JS; Rust re-validates on `start`/`add`;
  - (b) everything in Rust, with drag answers via async: impossible in a binding.
- **Default:** (a), with shared golden vectors so the JS and Rust refusals agree.

**J3. `Choice.js` (225 l, view-model: icons, captions, sections).**
- The list says it moves, but it only lives in bindings (`GroupChooser.qml:54-67`, `OrbitMenu.qml:45`).
- **Default:** stays JS and reads the cached eligibility map.

**J4. `Member.js` (75 l).**
- It is used at 22 QML sites plus 11 JS modules, all synchronous, and Rust also needs it to name `orbit_together_<key>` / `orbit_wired_<key>`.
- **Options:**
  - (a) twins in JS and Rust with a shared JSON golden-vector fixture;
  - (b) orbitd pushes every key: impossible for keys computed before a session exists.
- **Default:** (a). The same applies to `Habits.tag` (SEED 2654435761), `ConnectRules.keyOf` (SEEDS 1540483477/2246822519) and `BatterySessions.sha256`.

**J5. Split helpers.**
- The pure name predicates `Route.sinkKey`/`isDeviceSink`/`addressOfSink`/`isVirtual`/`virtualName`/`wiredFilterName`/`isWiredFilter` are needed by stay-files (`Radio.js:18,37`, `Hidden.js`, `WiredSign.js`, `Polar.js:36,52,66` with `Together.MAX_MEMBERS`).
- **Options:** (a) keep a small `Names.js` in JS and twin it in Rust with golden vectors; (b) orbitd pushes them.
- **Default:** (a).

**J6. Split for `Wired.js`, `Delay.js`, `Charge.js`, `Audiophile.js`.**
- Classes C/B per the jslogic report: wording, sliders, `labelOf`/`kindOf`/`iconOf`, `cleanFine`/`fineText`/`fineFrom`, `format*`/`levelColor`, `INFOS`/`line`/`rows`.
- **Q:** accept "logic in Rust, wording in JS"?
- **Default:** yes. orbitd pushes data (facts, latencies, `charge`, the wired list), and JS formats it. About 360 JS lines stay.

**J7. `Keys.js` (124 l, only builds `dms keybinds` argv).**
- **Options:** (a) move to Rust, as listed; (b) keep in JS next to the IPC handler.
- **Default:** (a). It ends the duplicate `VolumeKeys` state machines (A14) and lets the uninstall sweep share `FALLBACK_STEP` (`orbit_uninstall.py` must stay in sync with `Keys.js` today).

**J8. Unwired code: `BatterySessions.js` (308), `ConnectRules.js` (124), `ReportFile.js` (198).**
- None has a live caller (`BatteryHistoryStore.qml:7-8`, `ConnectRulesRunner.qml:7`).
- **Options:** (a) port to Rust and leave dormant; (b) wire them first in JS, then port; (c) delete; (d) port them as part of the feature that wires them.
- **Default:** (d). Port each only in the release that turns it on; until then the JS stays as the spec with its tests.

**J9. UI JS on neither list** (Glyphs, Palette, Guide, Text, Hidden, Gauge, Sun, Perspective, BeamMotion, MemberGlyph, WiredSign, Radio, CardStatus, Members).
- **Default:** confirm that all stay JS.

**J10. Synchronous `dms ipc` answers** (`OrbitIpc.qml:280` "a call must answer at once"; `together*`, `chatEnds`, `wiredDelay`, `togetherDelay`, `disconnectIn`, `volumeKeys status`).
- **Options:**
  - (a) answer from a QML mirror of pushed state, with JS pre-validation (J2, `DisconnectPhrase.findDevice` / `cleanMinutes`);
  - (b) answer "accepted" at once and report the refusal later as a toast;
  - (c) the two-call pattern of `diagnostics` (`:281-290`). This changes the CLI contract.
- **Default:** (a), falling back to (b) only for checks that need fresh hardware state. Keep the CLI contract.

**J11. `DisconnectPhrase.js`.**
- **Options:** (a) the 82 lines stay JS for IPC validation and orbitd owns the timers plus `Disconnect`; (b) all in Rust, with the IPC answered from the mirror.
- **Default:** (a).

**J12. `Log.js`.**
- **Options:**
  - (a) one ring in orbitd, with a JS shim forwarding `log` that keeps a local ring for when orbitd is down;
  - (b) two rings merged in the report;
  - (c) the ring stays in JS and orbitd sends `log` events to it.
- **Default:** (c). Allowlist and journal rules stay in one place, and the report still works when orbitd is dead. The report is built in orbitd and asks QML for the ring snapshot.

### E. Migration order and release strategy

**M1. Big bang or incremental.**
- **Options:**
  - (a) incremental: Python and JS removed feature by feature, each step a release;
  - (b) one release with everything.
- **Default:** (a). The order is in section 4.

**M2. Python suites' fate.**
- **Options:**
  - (a) port the 95 tests 1:1 to `cargo test` and delete the Python in the same release as the feature;
  - (b) keep the Python until parity has been shown for one release.
- **Default:** (a). "No Python fallback" is settled, so a Python copy that the plugin no longer runs only ages.

**M3. Version numbering.**
- **Options:** (a) `2.0.0` at the first orbitd release, a breaking requirement (pipewire-utils?/restart); (b) minor bumps.
- **Default:** (a) for the first release with orbitd (ANC + tick + uninstall), then minors.

**M4. Branch.**
- **Q:** land on `fix/dms-2.1-no-network` (it already carries breaking removals f2bc922…f157309), or start `feat/orbitd`?
- **Default:** ship the current branch first, as its own release, then `feat/orbitd` from `main`.

**M5. Hardware verification per ANC family.**
- 13 families, and the owner probably has 1–3 devices.
- **Options:**
  - (a) byte-vector tests only, released as is;
  - (b) a beta channel / call for testers per family before deleting the Python;
  - (c) record real sessions with `ORBIT_ANC_DEBUG` hex dumps now, as golden replay fixtures.
- **Default:** (c) for the devices the owner has, plus (a) for the rest. A replay harness feeds the recorded `<<` frames and asserts the same `>>` frames and snapshots from Rust.

### F. Testing and verification

**T1. CI test matrix.**
- `cargo test`, `clippy -D warnings`, `fmt --check`, plus gjs (`tests/run.sh`) and Qt 6 `qml` (`tests/qml/run.sh`) on Ubuntu. Neither of those runs locally today.
- **Default:** all of them in CI, and required on PRs. This is the only place the JS and QML suites can run for this owner.

**T2. Golden fixtures shared between gjs and Rust.**
- **Options:**
  - (a) export JSON fixtures (inputs → outputs) once from the current JS, read by both;
  - (b) port the asserts by hand.
- **Default:** (a) for Member/Habits/ConnectRules/sha256, Together, Delay, Wired, Volume, Charge and Wear (about 970 checks). Hand-port the Python byte vectors.

**T3. New tests before porting.**
- `sdp.py` and the ANC runner (select loop, linger, settle, deadlines) have none.
- **Default:** write the Rust tests from captured SDP responses and a scripted fake socket. Do not write the Python tests first.

**T4. Protocol-level contract tests.**
- **Default:** a `tests/orbitd/` fake-orbitd for the QML tests (`ancSessions.test.qml:110`, `volumeTick.test.qml:71` change argv), plus a Rust integration test that drives the real binary over stdin with fake `dms` / `pw-*` on PATH.

**T5. `tests/qml/run.sh:51` runs `python3` (a stub generator).**
- **Options:** (a) keep Python as a dev-only test dependency; (b) rewrite it in sh/Rust.
- **Default:** (a). "No Python" applies to the shipped runtime. Confirm.

**T6. aarch64 runtime test.**
- **Default:** run `cargo test` on the native arm runner. No hardware test.

### G. Privacy and logging

**L1. stderr.**
- Anything on stderr can reach the journal through Quickshell's Process logging, and the report reads the journal.
- **Options:** (a) orbitd never writes stderr unless `ORBITD_DEBUG=1`, and QML drops stderr; (b) stderr parsed into `Log.event`.
- **Default:** (a). Errors go out as `log {code,fields}` on stdout through the allowlist.

**L2. Debug toggle.**
- **Options:** (a) the env `ORBITD_DEBUG=1` (raw hex frames, as `ORBIT_ANC_DEBUG` does today), only when run by hand; (b) a runtime `{"t":"debug"}`.
- **Default:** (a). It cannot be switched on from IPC by accident.

**L3. Addresses and names in messages.**
- **Q:** Bluetooth addresses and device names cross stdin/stdout. That pipe is private, but must they ever appear in orbitd logs, argv or panics?
- **Default:**
  - names only inside JSON on stdin, never in argv or env;
  - a custom panic hook that prints no payload with device data;
  - `log` fields go through `Allow.js`-style allowlisting.

**L4. Files orbitd may write.**
- **Default:** an exhaustive list in the README:
  - the lock in `$XDG_RUNTIME_DIR` (tmpfs);
  - `~/.cache/orbitBluetooth/battery/history.json` (0600, only once wired);
  - the uninstall edits;
  - nothing else.

**L5. Diagnostics CPU figure.**
- Today `/proc/self/stat` is quickshell (`ReportService.qml:140`).
- **Default:** report both `/proc/<ppid>/stat` (shell) and `/proc/self/stat` (orbitd), as two lines.

**L6. The report's probes.**
- **Options:** (a) orbitd spawns `dms version`/`quickshell`/`niri`/`rpm`/`journalctl` and reads `os-release`/`hostname` directly; (b) leave the probes in QML.
- **Default:** (a). Redact runs in orbitd, next to the text. `journalctl` stays a spawn (libsystemd is C).

**L7. `/etc/hostname` probe.**
- It is read only to be redacted.
- **Default:** keep it, read through `fs` (it feeds `Redact.identity`).

**L8. Clipboard (`ReportCopy.qml:55`).**
- `wl-copy` is missing here; the fallback is `dms clipboard copy`.
- **Default:** stays in QML. It is a UI button.

**L9. `scripts/diagnose.sh`.**
- **Default:** stays sh, because it must work when orbitd is dead. It adds `orbitd --version`, the arch, and `sha256sum -c bin/SHA256SUMS` (XS).

### H. Uninstall

**U1. Sweep strategy.** The binary is deleted with the folder; Python is gone.
- **Options:**
  - (a) on stdin EOF, orbitd forks a detached child (`setsid`, SIGHUP ignored, fds closed) that sleeps `GRACE_SECONDS=4`, rechecks `plugin.json` and sweeps. It runs on every shell quit, but costs 4 s of sleep.
  - (b) QML sends `{"t":"uninstall"}` from `Component.onDestruction` when `plugin.json` is gone, and orbitd detaches. This is fragile, because orbitd may already be gone.
  - (c) re-exec `/proc/self/exe sweep …` detached (works after unlink), triggered as in (a).
  - (d) memfd or a `$XDG_RUNTIME_DIR` copy (no).
- **Default:** (a)/(c): on EOF, if `plugin.json` is already gone **or** may go, spawn `/proc/self/exe --sweep <paths>` with `setsid`. The paths come from `hello`.

**U2. Exception to "dies with the shell".**
- **Q:** may a detached orbitd child outlive the shell for at most about 4 s (+ the 10 s `dms keybinds` timeout)?
- **Default:** yes. Document it as the only detached path, bounded by a hard 20 s self-kill.

**U3. Order of uninstall events.**
- **Q:** does Quickshell stop a `Process` with SIGTERM or SIGKILL, and does DMS delete the folder before or after unloading? SIGKILL skips the sweep.
- **Default:** trigger on stdin EOF, which arrives first. Accept no sweep after a shell crash, which is the same as today. Verify with spike S5.

**U4. JSON rewrite fidelity.**
- `settings.json`, `plugin_settings.json` and `session.json` are DMS's files.
- **Q:** serde_json `preserve_order` with a 2-space formatter can differ from Python's `indent=2` on floats (`1e-05`). Is a formatting difference acceptable if the content is equal?
- **Default:** accept it. Round-trip tests run on copies of real DMS files, and a file is rewritten only when something changed (as today).

**U5. Cleanup of PipeWire objects on uninstall or crash** (`orbit_pc_*`, `orbit_wired_*`, `orbit_together_*`, `orbit_tick_*`).
- **Default:** child processes die with PDEATHSIG. If P3(b) is chosen, a name-prefix sweep runs at startup and in the uninstall child.

### I. Versioning and protocol

**V1. Handshake.**
- **Options:**
  - (a) a mandatory `hello {proto:int, version, sha, arch}`; on mismatch QML stops orbitd and shows "restart the shell";
  - (b) best effort.
- **Default:** (a). `git pull` while the shell runs leaves old QML in memory with a new binary on disk. Versioned file names (D3) make this rarer, since old QML keeps launching its own binary until it is deleted.

**V2. Version source.**
- **Options:** (a) the binary embeds `plugin.json`'s version at build time (CI reads it); (b) `CARGO_PKG_VERSION` kept in sync by a CI check.
- **Default:** (b), with a CI check that `Cargo.toml` version == `plugin.json` version.

**V3. Protocol evolution.**
- **Default:** integer `proto`, bumped on any breaking change. QML and orbitd ship in the same commit, so there is no need for multi-version compatibility.

**V4. `orbitd --version` CLI.**
- **Default:** prints the version, proto, git SHA and arch, for `diagnose.sh` and support.

### J. Housekeeping found along the way

**H1.** `CLAUDE.md` still lists the `pictures/` test command and the Real device pictures privacy exception. Both were removed in f2bc922.
- **Default:** fix them in the next commit. The owner must confirm, because it is the values file.

**H2.** The README manual install path (`README.md:40`, `~/.config/DankMaterialShell`) should be `~/.config/dms/plugins/`. The requirements table (`:18-26`) also needs fixing. The docs that mention Python: `CONTRIBUTING.md:84,92,191-205`, `docs/GUIDE.md:536,787`.

**H3.** XMDeck is credited in README Credits (`README.md:273`) but in no code comment.
- **Q:** which Sony detail came from XMDeck?
- **Default:** the owner says, and the Rust Sony module credits it. Otherwise the README entry is checked.

**H4.** Credit comments: every Rust protocol module copies its Python docstring ("Written from the byte-level facts documented by … (no code copied)").
- **Default:** yes. A CI grep checks that each `protocols/*.rs` has a `Credits:` header.

---

## 3. Risks and unknowns, with spikes

| # | Risk | Spike (time-boxed) |
|---|---|---|
| S1 | **Static musl versus PipeWire** (P1). No mature pure-Rust client; pulse lacks params, quantum and explicit links. | 1–2 days: static musl binary that (1) talks to `pulse/native` with a pure-Rust crate: lists sinks with `api.bluez5.*` props, subscribes, sets volume; (2) talks to `pipewire-0` native: Hello, GetRegistry, binds one node, reads `Latency`/`Props` params and `settings` metadata. Measure lines and binary size. Decides P1, P3, P7. |
| S2 | **Tick leak into the Together copies** (NAK-251) if it does not use `autoconnect=false` plus explicit links. | Half a day: a pulse playback stream with `target.object`/`node.dont-reconnect` while a smart filter is active (`pw-loopback` from pipewire-utils installed temporarily). Check with WirePlumber 0.5.19 whether the tick reaches the copies. Decides P2. |
| S3 | **pipewire-utils absent** on Fedora by default (confirmed here: `pw-loopback`, `pw-cat`, `pw-link`, `pw-dump`, `pw-top` missing). Spawning keeps today's silent breakage. | Already answered: no spike needed. It feeds P1/P3, and the UI needs an "missing tool" diagnostic if spawning stays. |
| S4 | **AF_BLUETOOTH from static musl**: hand-written sockaddr, non-blocking connect, 8 s/5 s timeouts, SEQPACKET L2CAP for Apple. | Half a day: a 200-line Rust binary that does SDP for the Sony UUID and opens RFCOMM to the owner's headset. Compare hex with `ORBIT_ANC_DEBUG=1` from Python. Also capture SDP responses as test fixtures. |
| S5 | **Uninstall after the binary is unlinked**: how Quickshell kills a `Process` (signal, order versus EOF), whether `/proc/self/exe` still runs after `rm -rf`, and the DMS delete/unload order. | Half a day: a toy plugin with a Rust process that logs to `$XDG_RUNTIME_DIR` (test only) on EOF/SIGTERM, then a real `dms plugins uninstall`. Verify the detached child survives a `dms restart` / `systemctl --user restart dms`. |
| S6 | **Latency of keys and level messages** through `dms ipc` → QML → orbitd, and SplitParser throughput at about 30 Hz `state.levels`. | Half a day: an echo orbitd plus held-key timing with timestamps. Decides P4/P5 and whether levels may ever travel through JSON. |
| S7 | **go-git update while the binary runs** (`ETXTBSY`, half-applied update). | 2 h: a local repo with a running binary, then `dms plugins update` from a local remote, or go-git checkout in a tiny Go program. Becomes moot if D3(b) is chosen. Still check that the old file is deleted cleanly while it runs. |
| S8 | **Registry rejects committed binaries or their size** (unknown). | 1 h: the owner reads dux-plugin-registry's CONTRIBUTING (needs the network, so a human step). |
| S9 | **Reproducible static builds across two runners** (x86_64 and native arm). | Half a day: a CI workflow building a hello-world plus zbus twice, comparing hashes. |
| S10 | **Binary size** with tokio + zbus + regex + serde. | Comes with S1/S9. If it is over 3 MB, consider dropping `regex` (Redact rules hand-written) or using `regex-lite`. |
| S11 | **The `reloadPlugin` overlap and the lock**: two orbitd with RFCOMM held by the old one, while the new one waits. | Covered by the A9 implementation test: kill -STOP the old one and check that the new one waits and then takes over. |
| S12 | **Qt file-list cache** (`PLUGINS/README.md:999`): new QML files fail until restart. | No spike. Put new files in a new subdirectory and say so in the changelog (D11). |
| S13 | **Hardware coverage**: 13 ANC families, few devices. | Record hex sessions now (M5c), before the Python goes. |
| S14 | **pulse modules survive an orbitd crash** (if P3b): orphan virtual sinks. | Part of S1: load a null-sink plus loopback, kill -9 the client, check whether the module stays. Design the startup sweep accordingly. |

---

## 4. Migration order (each step ships; tests named are the gate)

0. **Prerequisites (no user change).**
   - Run spikes S1, S2, S4, S5, S6, S8.
   - Fix CLAUDE.md, README and docs (H1, H2).
   - Record ANC hex sessions (M5c).
   - Export the golden JSON fixtures from the current JS (T2).
   - CI skeleton running the gjs, Qt 6 and Python suites as they are today.
   - *Gate:* every existing suite is green in CI. This is the baseline.

1. **orbitd skeleton plus distribution.**
   - `hello`/proto/version, lock, EOF exit, PDEATHSIG supervisor, `log` events.
   - The QML `OrbitdClient` in `components/orbitd/`, arch pick (A10), crash backoff (A6), reduced-mode note (A11).
   - The CI release workflow, versioned binaries, SHA256SUMS, the reproducibility job.
   - `diagnose.sh` prints the orbitd version.
   - *Gate:* `cargo test`; a new QML test with a fake orbitd (handshake mismatch, crash backoff); the reproducible-hash job; a manual check on x86_64.

2. **Uninstall sweep in Rust** (drops `python3 -c` and the in-memory script).
   - *Gate:* the 13 `uninstall/tests` ported 1:1; round-trip on real DMS JSON copies; spike S5's manual uninstall and re-clone-during-grace check. Delete `uninstall/` and `UninstallSweep.qml`'s FileView.

3. **ANC.**
   - bt-sock + SDP + runner + 13 families. Message vocabulary `anc.watch/set/cycle`, `state.anc`, `anc.ended`. Error codes (P11).
   - *Gate:* the 62 `anc/tests` ported; new SDP tests from S4 captures; replay of the recorded hex sessions (byte-identical `>>` frames and snapshots); `tests/qml/ancSessions.test.qml` updated to the fake orbitd; hands-on test on the owner's headsets. Delete `anc/*.py`.

4. **Volume tick** (P2 outcome) **and Volume.js tick logic.**
   - *Gate:* the 20 `tick/tests` ported (Mix, Gain, Link or the stream equivalent, Session with fakes, Burst); `volume.test.js` Volume part (about 34) via fixtures; `volumeTick.test.qml` and `volumeTickTarget.test.qml` updated. Delete `tick/`. **Release 2.0.0: no Python left at runtime.**

5. **BlueZ/UPower over zbus** (busctl B1–B3, DeviceLog sources, HID_UNIQ, profile check, the disconnect owner A3).
   - *Gate:* `Route.transportPath`/`transportVolume` checks within volume.test (about 39 Route) as fixtures; DeviceLog publishes unchanged (`since`/`batteryLog`/`power` shapes compared in a QML test); manual pairing and profile-refusal check.

6. **PipeWire graph events** (facts, latency, wired outputs, quantum), ending `pactl`/`pw-dump`/`pw-top`.
   - *Gate:* audiophile 28, wired 83, delay 70 (A parts), `audioFacts.test.qml`, `twoLevelsWired`, `wiredMembers`.

7. **Loopbacks and Listen together plan** (PC filter, copies, wired filter; Together A part; the eligibility map pushed for J2).
   - *Gate:* together 149, wiredfilter 35, member 29 and the golden twins, `togetherSession`, `groupLeave` and `togetherNames` QML tests; kill -9 orbitd leaves no `orbit_*` node.

8. **Keys and routing decisions** (Keys.js, the step/target logic; writes stay QML per P4a). The settings page uses the shared client (A14).
   - *Gate:* the Keys (about 16) and Route (about 39) parts of volume.test; `volumeKeys` and `audioRouteWriting` QML tests; held-key latency at or below the S6 baseline.

9. **Battery/charge/wear** (Charge.analyze, Endurance, Wear plus MPRIS).
   - *Gate:* battery 37, card 2, wear 68, `chargeColors`/`batteryArc`/`chargeBeam` and `wearPause` QML tests.

10. **Delays, diagnostics, rules.**
    - DisconnectPhrase timers (J11), Gather/Redact/Report/Cpu (L5, L6), the Log shim (J12).
    - *Gate:* disconnectPhrase 17, diagnostics 108, reportLeaks 17 (no address, name, home path or host name in the output); `diagnose.sh` test 9 checks.

11. **Dormant features**, each in the release that wires it (J8): BatterySessions plus the history file (batterySessions 56, historyDisk 11), ConnectRules (connectRules 42), ReportFile (reportFile 54).

12. **Cleanup.** Delete the moved JS, prune the fixtures to the Rust side, and update the CLAUDE.md test commands (`cargo test` replaces the anc/tick lines), the README (Changelog, Roadmap, Credits, requirements, privacy and resources) and the `plugin.json` bump for each release.

Gate on every step: `cargo test` + `clippy` + `fmt`, the full gjs and Qt 6 suites in CI, the reproducible-hash job, the binary-size budget, and the credit-header grep.
