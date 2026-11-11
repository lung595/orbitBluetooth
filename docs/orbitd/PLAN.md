# orbitd: the plan

The owner's decisions for the backend rewrite, taken on 2026-11-11. They
override the research in `research/` wherever the two disagree (the research
was written before the scope was narrowed). Read this first, then the
research for file:line facts.

## Why

Rust buys **reliability and independence**, not lightness. Measured on the
owner's machine: a Python helper costs about 11.5 MB and starts in 10–25 ms,
only while it runs; the DMS shell is about 890 MB. A resident orbitd costs an
estimated 2–4 MB at all times. What Rust fixes is that Orbit depends on tools
a default install does not have: `pipewire-utils` (`pw-loopback`, `pw-link`,
`pw-dump`, `pw-top`) is missing on stock Fedora, so the PC volume filter, the
Listen together copies, latency and the graph facts fail silently today. Rust is also memory-safe where Orbit parses bytes sent by a
headset (the ANC protocols).

## Decisions

- **Scope: the system only.** orbitd owns what touches the system: the ANC
  protocols (RFCOMM, SDP), PipeWire (PC filter, Listen together copies,
  wired filter, latency, quantum, graph facts), D-Bus
  (BlueZ, UPower, MPRIS) and the uninstall cleanup.
- **The pure JS logic stays in JS**, all of it: Route, Together, Choice,
  Wired, Delay, Habits, Member, Charge, Endurance, Wear's state machine,
  DeviceCatalog, ConnectRules, DisconnectPhrase, Keys, diagnostics. It already
  runs in the QML engine with no process boundary, it is tested, and about half
  of it is called synchronously from bindings. orbitd pushes data; JS decides
  and formats. Move a JS function only if it cannot work without system access.
- **QML stays for the UI; GLSL stays; per-frame JS stays.** cava stays a
  QML-spawned process (per-frame UI feed).
- **Binary: glibc, dynamically linked against libpipewire-0.3** through the
  `pipewire` crate (pipewire-rs). libpipewire ships with PipeWire itself
  (`pipewire-libs`), so it is present wherever PipeWire runs. Build on an old
  glibc baseline so it runs on every current distribution; musl distributions
  are not supported. D-Bus through `zbus` (pure Rust). RFCOMM/L2CAP through raw
  `libc` sockets. Static musl and a home-made PipeWire protocol client are
  rejected.
- **Resident:** orbitd runs for as long as the plugin is loaded, one per
  shell, asleep without events, and dies with the shell (stdin EOF, parent
  death signal). Nothing survives the shell, not even for the uninstall.
- **Uninstall:** removing Orbit removes everything of Orbit, leaving as little
  as possible, with no separate script: orbitd does the cleanup itself (its
  settings, widgets, keys if bound) and never outlives the shell. Replaces
  `uninstall/orbit_uninstall.py` and the `python3 -c` sweep.
- **No Python at runtime** once orbitd ships (no fallback). Python stays
  allowed for dev-only tooling.
- **Talk:** JSON lines over stdin/stdout, as `anc/orbit_anc.py` does today.
- **Privacy:** zero network, zero telemetry, nothing on stderr unless run by
  hand with a debug variable, no log files, no addresses or names in argv,
  env or panics.

## Order of work

1. **Release 2.0.0 first, without Rust.** `main` already holds the 2.0 work
   (DMS 2.1 fixes, pictures, pairing sheet, Orbit OSD and launcher removed).
   Before the bump, **repair the features broken without pipewire-utils** using
   what a default install has (`pactl`, pipewire-pulse): the PC volume
   filter, the Listen together copies, the wired filter.
   Test without installing pipewire-utils. Then bump `plugin.json` and the
   CHANGELOG to 2.0.0. The owner tests and pushes.
2. **Spike** (decides the PipeWire layer): pipewire-rs on this machine,
   registry and node params (Latency, Props), loopback/filter creation.
   Measure lines and binary size.
3. **orbitd skeleton:** handshake (`hello {proto, version, arch}`), single
   instance lock, EOF exit, parent death signal, child supervision, `log`
   events through the JS allowlist, QML client in `components/orbitd/`, arch
   pick, crash backoff, reduced mode when the binary is missing.
4. **PipeWire** (replaces the pactl repair and pw-dump/pw-top).
5. **D-Bus:** BlueZ, UPower, MPRIS (replaces `busctl`).
6. **Uninstall cleanup.**
7. **ANC last**, once the rest has proven itself: SDP, the session runner,
   13 families ported from `anc/` with the Python tests ported 1:1, and real
   sessions recorded first (see Tests). Then delete `anc/`.

Each step lands with its tests green and the Python or tool it replaces
deleted in the same step.

## Distribution

- Work happens on branches (`feat/orbitd`, ...). `main` only receives release
  merges. Every commit on `main` that needs orbitd carries the matching
  binaries.
- GitHub Actions builds x86_64 and aarch64 (native arm runner), runs every
  suite (`cargo test`, clippy, fmt, gjs, Qt 6 qml, Python while it exists),
  and on release commits the binaries with `bin/SHA256SUMS`; a second job
  rebuilds and fails on a hash mismatch. Binary names carry the version
  (`bin/orbitd-<version>-<arch>`). Size budget enforced in CI.
- Check the DMS plugin registry's rules on committed binaries before the
  first release that ships one.

## Tests

- Locally and in CI. The owner installs once:
  `sudo dnf install -y gh qt6-qtdeclarative-devel gjs rustup pipewire-devel clang-devel && rustup-init -y`.
  Do **not** install pipewire-utils: tests must reflect a default install.
- The existing suites are the golden reference: 95 Python tests, about 970
  JS checks, the QML suites.
- ANC: the owner has **Sony, Samsung Galaxy Buds, Soundcore and Nothing**
  devices. The agent records real sessions itself (`ORBIT_ANC_DEBUG=1` hex
  dumps through the current Python helper) when a device is connected, as
  replay fixtures before the Python is deleted. The other families rely on the
  byte-vector tests. Never unpair, forget or rename a real device.
- The agent runs every test itself; the owner tests only at the end.

## How the loop works

- Commits locally on branches. **Never pushes**, never merges into `main`,
  never publishes a release: the owner tests, approves, then pushes.
- Stops only on blocking decisions: a spike result that changes this plan,
  a conflict with the project values (CLAUDE.md), or something only the owner
  can do. Technical choices inside this plan are the agent's.
- Follows CLAUDE.md: README and Changelog updated when something is finished,
  credits kept next to each ported protocol, comments explain why, Theme tokens
  for chrome.
