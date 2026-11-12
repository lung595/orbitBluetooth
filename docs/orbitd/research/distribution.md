# Build, distribution, CI, tests and DMS plugin rules for `orbitd`

Read-only pass: no files were edited. The only things run were the Python test suites and read-only commands.

## 1. How DMS installs and updates plugins (DMS 2.1.2, `/usr/share/quickshell/dms/VERSION`)

**Install and update are done by the `dms` Go binary through go-git, not from QML.**
- `/usr/bin/dms` (86.8 MB) has go-git v6 built in. Strings found in it include `failed to clone plugin: %w`, `failed to update plugin: %w`, `plugin is not a managed git checkout`, `failed to fetch locked revision: %w`, `cannot update system plugin`, `Fetching plugin registry...` and `dux-plugin-registry.git`.
- On the QML side, `Services/PluginService.qml:486-502` (`updatePlugin`) only checks `requires_dms`. It then calls `DMSService.update` (`Services/DMSService.qml:560`, IPC `plugins.update`) and then `forceRescanPlugin`. Install goes through `DMSService.install` (`DMSService.qml:534`, `plugins.install`), called from `installFromRegistry` (`PluginService.qml:1571`).
- CLI subcommands: `dms plugins browse | install <id> | list | lock | restore [lockfile] [--prune] | uninstall | update [id] [-a|--all] [--check]`. I did not run `--check` because it goes to the network.

**On-disk state**
- `~/.config/dms/plugins/orbitBluetooth` is a full, non-shallow clone (`rev-parse --is-shallow-repository` = false) of `https://github.com/lung595/orbitBluetooth`. The refspec is `+refs/heads/*:refs/remotes/origin/*`, so every branch and its whole history comes down.
- Monorepo plugins are symlinks into `.repos/<hash>/<path>`, with a `.meta` file holding `repo=`, `path=` and `repodir=`.
- `~/.config/dms/plugins.lock.json` pins `orbitBluetooth` to commit `dbbda495` (2026-10-12) by SHA. `dms plugins restore` checks out exact locked SHAs.

**What this means for a committed binary**
- An update is a fetch plus checkout in the existing clone, not a re-clone. Every binary ever committed stays in each user's `.git` for good. Today `.git` is 27 MB (25.18 MiB pack, 559 tracked files).
- go-git keeps the executable bit. I checked three DMS-cloned repos: their files with mode 100755 are `-rwxr-xr-x` on disk. A `100755` binary therefore arrives runnable.
- **Risk, not verified:** I could not see whether go-git rewrites a changed file in place or unlinks it and creates a new one. If it writes in place while `orbitd` is running, Linux returns `ETXTBSY` and the update could fail or end half-applied.
  - One fix: put the version in the file name (`bin/orbitd-<ver>-<arch>`).
  - Another: have the QML copy the binary to `$XDG_RUNTIME_DIR` before running it.
- Users get `main` HEAD, or any locked SHA. **Every commit that a user can land on must carry a binary that matches its QML.** If CI pushes the binary in a later commit, the source commit in between has a stale binary. That calls for a protocol-version handshake on the JSON-lines channel.

**Plugin rules found in the local docs** (`/usr/share/quickshell/dms/PLUGINS/README.md`)
- `:999`: Qt keeps each plugin directory's file list until the shell restarts. A QML or JS file that an update adds next to existing ones fails with `File name case mismatch` until `dms restart`. A migration that adds QML files needs a restart, or the new files must go in a new subdirectory. A binary is not affected.
- `:1272`: the `process` permission is "not currently enforced".
- `:1265-1279`: the plugin API is experimental.
- `plugin-schema.json` has no rule about size or binaries. The README says nothing about binaries.
- The registry rules (github.com/duxlabs-dev/dux-plugin-registry, its CONTRIBUTING) are not on this machine, and I could not read them without the network. Whether it accepts binaries, has a size limit or reviews submissions is still unknown.

## 2. The repo today

- **`.github/`**: only `ISSUE_TEMPLATE/bug.yml`. **There is no CI at all, so no workflows.**
- **`.gitattributes`**: `* text=auto` only. Git's NUL-byte check would treat an ELF file as binary, but an explicit `bin/** binary -diff` line is safer.
- **`.gitignore`**: `__pycache__/`, `*.pyc`.
- **`plugin.json`**: version `1.15.0`, `requires_dms >=1.6.0`, permissions `settings_read`, `settings_write`, `process`, type `composite` with a daemon.
- **Tags**: 15 tags, the latest `v1.13.1` to `v1.15.0`. Release steps are in `CONTRIBUTING.md:270-275`: bump `plugin.json`, move the Unreleased entries in `CHANGELOG.md` (107 KB, Keep a Changelog), refresh the screenshots, run the tests, then `git tag vX && git push --tags`. Nothing is built.
- **Executable files tracked (mode 100755)**: `scripts/diagnose.sh`, `scripts/preview/{record,render}.sh`, `shaders/build.sh`, `tests/qml/run.sh`, `tests/run.sh`.
- **Python that would move to Rust**:
  - `anc/orbit_anc.py` (225 lines), `anc/sdp.py` (110 lines) and 19 modules in `anc/protocols/`.
  - `tick/orbit_tick.py`, which plays through `pw-cat`.
  - `uninstall/orbit_uninstall.py`, plus `components/common/UninstallSweep.qml:63`, which runs `python3 -c`.
  - `components/**/*.js` adds up to 6,934 lines, some of which move.
- **Current ANC wire format**: one Python process per headset (`AncService.qml:100`, `["python3","-E","-s",_helper,"-",family]`, address in `ORBIT_ANC_ADDRESS`). stdin takes text commands (`get`, `set <key> <value>`, e.g. `AncService.qml:109` `"set wear on"`). stdout sends JSON lines (`orbit_anc.py:61`). With a single resident `orbitd` this becomes many devices over one channel, so every message needs a device address.
- **Process spawns `orbitd` would replace**:
  - `pw-dump`: `together/MemberLatency.qml:47`, `volume/AudioGraph.qml/.js`
  - `pactl --format=json list sinks`: `volume/AudioFacts.qml:40`
  - `busctl`: `pairing/ProfileCheck.qml:33`, `volume/RouteDevice.qml:62,72`
  - `cava`: `volume/ScopeFeed.qml:68`
  - also `WiredWatch.qml`, `TogetherLink.qml`, `VolumeKeys.qml:100` and `BatteryHistoryStore.qml:101,118`

**Test status on this machine**
- `(cd anc && python3 -m unittest …)`: 62 tests pass. `tick/` tests pass too.
- `pictures/` no longer exists (removed in f2bc922), yet `CLAUDE.md` still lists its test command and the pictures exception. Both are out of date.
- `tests/qml/run.sh` **cannot run here**: there is no `qml`/`qml6`/`qml-qt6` (`/usr/lib64/qt6/bin` only has `qsb` and `qtpaths`) and no PySide6.
- `tests/run.sh` (about 50 `*.test.js` files) **cannot run here**: no `gjs`.
- So locally only the Python suites run today. The Rust port would replace them with `cargo test`.

**Other out-of-date docs**
- README `:40` gives the manual install path as `~/.config/DankMaterialShell/plugins/orbitBluetooth`. The real path is `~/.config/dms/plugins/`.
- The README requirements table (`:18-26`) lists Python 3 and `pw-cat`.

## 3. Toolchain and system libraries (Fedora 45, x86_64, glibc 2.44, kernel 7.3.3)

- `cargo`, `rustc`, `rustup`, `cross`, `docker`, `podman`, `musl-gcc` and `clang` are **all missing**, and there is no `~/.cargo`.
- Not installed: `pipewire-devel`, `dbus-devel`, `bluez-libs-devel`, `musl-devel`, `musl-libc-static`, `glibc-static`.
- Runtime libraries present: `libpipewire-0.3.so.0.1611.0` (pipewire 1.6.11), `libdbus-1.so.3`, `libbluetooth.so.3`, and SPA plugins in `/usr/lib64/spa-0.2`.
- Sockets present: `/run/user/1000/pipewire-0`, `pipewire-0-manager`, `pulse/` (pipewire-pulseaudio), and `bus`.
- **Important: `pipewire-utils` is NOT installed.** `pw-dump`, `pw-cli`, `pw-cat` and `pw-top` do not exist. The tick (`pw-cat`), `MemberLatency` and `AudioGraph` (`pw-dump`) already cannot work on this machine. `pactl` is present (from `pulseaudio-utils`), and so are `busctl`, `upower` and `cava`.

**PipeWire options**
- **A. Pure Rust over PipeWire's native protocol** (a Unix socket with SPA POD messages and fd passing; the protocol is documented publicly).
  - Reading the registry, node props and metadata (what `pw-dump` gives) and watching events: Core Hello, GetRegistry, binding nodes, subscribing to Props. This is feasible, but I know of no mature crate. `pipewire-rs` is bindings to the C library. Estimate: 1.5 to 3k lines to own and test.
  - Setting a volume is a `Node.SetParam` with a Props POD, which is moderate work.
  - Playing the tick needs a client node, shared-memory buffers and timing. That is hard.
  - This option keeps the build static musl.
- **A2. Pure Rust over the PulseAudio protocol to pipewire-pulse.** I believe a pure-Rust crate exists (`pulseaudio` by colinmarc), but this needs checking. It would cover sink list and volume, subscribe events and a playback stream for the tick, all statically. The cost is a dependency on pipewire-pulse, which is present here and the Fedora default.
- **B. Dynamic link against the system libpipewire (glibc).** This breaks the "static musl" decision, because a static musl binary cannot `dlopen` glibc libraries. The binary would have to be glibc and dynamic, built against an old glibc baseline, and would need `pipewire-devel` in CI and libpipewire at runtime.
- **C. Keep running `pw-dump`/`pw-cli` from Rust.** This is already broken here (no `pipewire-utils`). `pactl subscribe` and `pactl --format=json` would work on this machine.

**D-Bus**: zbus is pure Rust and builds statically. It covers the system bus (BlueZ `org.bluez`, UPower) and the session bus. Avoid `bluer` and `dbus-rs`, which link libdbus.

**Bluetooth RFCOMM and L2CAP**: raw `socket(AF_BLUETOOTH=31, SOCK_STREAM/SOCK_SEQPACKET, BTPROTO_RFCOMM=3/L2CAP=0)` through `libc` works statically. The Python code does exactly this today (`orbit_anc.py:69,91`, `sdp.py:96`). `sockaddr_rc` and `sockaddr_l2` probably have to be declared by hand, since the `libc` crate likely lacks them. No libbluetooth is needed.

**Cross-compiling**: rustup has the targets `x86_64-unknown-linux-musl` and `aarch64-unknown-linux-musl`. Pure-Rust crates need no musl-gcc. GitHub has native arm64 runners (`ubuntu-24.04-arm`, free for public repos), and `cargo-zigbuild` is another route.

## 4. Size and reproducibility

**Size (estimate, not measured)**
- A static musl binary with zbus, serde_json, a small async runtime or plain threads and the protocol code, built with `opt-level="s"`, `lto=true`, `codegen-units=1`, `panic="abort"` and `strip=true`, should be about **1.5 to 3 MB per arch**, so roughly 3 to 6 MB per release for both.
- These are full clones that keep all history. About 20 releases would add 60 to 120 MB, before git's compression (around 40 to 50% on ELF), on top of today's 27 MB.
- If CI rebuilds on every push to `main` instead of on releases, the history grows much faster.

**Verification**
- Pin the toolchain with `rust-toolchain.toml` (exact version and the two targets) and commit `Cargo.lock`.
- Build with `--locked --frozen`, `SOURCE_DATE_EPOCH`, `--remap-path-prefix=$PWD=.` (plus `$CARGO_HOME`), and `RUSTFLAGS` fixed in `.cargo/config.toml`.
- Rust plus musl, with no C dependencies, is generally reproducible bit for bit under these settings.
- Commit `bin/SHA256SUMS`. Users can check with `sha256sum -c`.
- A second CI job rebuilds from the tagged source and fails if a hash differs.
- `cargo-auditable` would add the dependency list to the ELF, a few KB, readable with `cargo audit bin`. It is optional.
- An `orbitd --version` that prints the git SHA and protocol version would let the QML refuse a binary that does not match.

**CI mechanics to decide**: the workflow needs `contents: write` to push back. It must not trigger itself (`[skip ci]` or path filters). It must decide how the tag relates to the bot commit, so the tag points at the commit that contains the binaries.

## Open questions for the owner

1. **PipeWire**: A (pure-Rust native protocol, hard for the tick), A2 (PulseAudio protocol to pipewire-pulse), B (dynamic glibc, breaks static musl) or C (CLI tools, already missing here)? Can the tick become a pulse playback stream?
2. When are binaries built and committed: on release tags only, or on every push to `main`? Which branch do users follow, `main` HEAD or the latest tag? How do we keep a source commit that `main` or a lock points to from having a stale binary?
3. Binary layout: one fixed name (`bin/orbitd-x86_64`, which risks `ETXTBSY` while running) or a name with the version in it? Where should old binaries go?
4. Since git history grows by about 3 to 6 MB per release, is that size acceptable? Would a later history rewrite or squash ever be allowed? (It would break lock SHAs.)
5. Architectures other than x86_64 and aarch64 (armv7, riscv64): no binary means no daemon. Should the plugin show a clear "unsupported arch" notice, or does the UI still load in a reduced mode?
6. Should a protocol handshake (`hello {proto, version, sha}`) be mandatory, and should the QML refuse an `orbitd` that does not match?
7. Is a bit-for-bit reproducibility check in CI required, or are committed SHA-256 sums enough? Is `cargo-auditable` wanted?
8. Rust is not installed locally. Should the dev machine get rustup and the musl targets (this downloads the toolchain once, a development step, not for users), or is building only in CI enough? For development branches the plugin needs a local build path, for example a `bin/` override or `cargo build` into `target/`, so the next session can work.
9. Tests: `qml`/PySide6 and `gjs` are missing here, so the QML and JS suites do not run locally. Should CI run them (Qt 6 and gjs on Ubuntu runners) along with `cargo test`, `clippy` and `fmt`? Should the Python tests be ported or dropped once Python is gone?
10. The registry's rules on binaries and size are unknown (not on this machine). Should someone read dux-plugin-registry's CONTRIBUTING, or ask its maintainers, before committing to binaries in the repo?
11. Restart: the migration adds and removes QML files. Should the changelog and README say "update needs `dms restart`", or should the new QML go in new subdirectories?
12. One daemon for all headsets replaces one Python process per headset. Should a protocol crash take down only that device's session (catch it inside one process) or the whole daemon, with the QML restarting it?
13. `cava` (`ScopeFeed.qml`): does it stay a separate tool, or move into `orbitd`? (It is not in the list of decisions.)
14. Out-of-date docs to fix in the same pass: the `pictures/` test command and its privacy exception in `CLAUDE.md`, the README manual install path (`~/.config/DankMaterialShell` should be `~/.config/dms`), and the README requirements (Python, `pw-cat`).

Key paths:
- `/usr/share/quickshell/dms/Services/PluginService.qml`
- `/usr/share/quickshell/dms/Services/DMSService.qml`
- `/usr/share/quickshell/dms/PLUGINS/README.md`
- `~/.config/dms/plugins.lock.json`
- `~/.config/dms/plugins/orbitBluetooth/CONTRIBUTING.md`
- `~/.config/dms/plugins/orbitBluetooth/components/noise/AncService.qml`
- `~/.config/dms/plugins/orbitBluetooth/anc/orbit_anc.py`