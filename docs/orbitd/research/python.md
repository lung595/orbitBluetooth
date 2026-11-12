# Python/shell helpers that orbitd must replace

Repo: `~/.config/dms/plugins/orbitBluetooth`. I edited nothing. I ran the three Python suites with `python3 -B` and all pass: anc 62 tests, tick 20, uninstall 13. There is no `.github/workflows/` directory yet, so the musl build pipeline has to be written from scratch.

## 0. Size

| Area | Files | Lines |
|---|---|---|
| `anc/orbit_anc.py` (runner) | 1 | 225 |
| `anc/sdp.py` | 1 | 110 |
| `anc/protocols/*.py` | 16 files, **13 families** | 2160 |
| `anc/tests/*.py` | 4 | 668 (62 tests) |
| `tick/orbit_tick.py` | 1 | 214 |
| `tick/tests/test_orbit_tick.py` | 1 | 222 (20 tests) |
| `uninstall/orbit_uninstall.py` | 1 | 215 |
| `uninstall/tests/test_uninstall.py` | 1 | 192 (13 tests) |
| `scripts/diagnose.sh` | 1 | 108 (9 checks in `tests/diagnose.test.sh`) |

On the "16 brands" figure: there are 16 *files* in `anc/protocols/`, but only 13 families in `anc/protocols/__init__.py:15-29`. The families cover about 19 trade names through the regexes in `components/noise/Anc.js:9-24`: Beats goes to apple, CMF to nothing, Honor to huawei, OnePlus and realme to oppo, Redmi to xiaomi, Anker to soundcore. The 3 files that are not families are `base.py`, `checksums.py` and `safer.py`. Sony is split into 3 files.

---

## 1. `anc/orbit_anc.py`: noise-control session runner

### Lifecycle today
- **Who starts it:** `components/noise/AncService.qml:90-108` (`_open`), with `["python3","-E","-s", helper, "-", family]`; the `-` means the address comes from `ORBIT_ANC_ADDRESS` (audit 2026-11).
- **Device address and name:** passed in the environment as `ORBIT_ANC_ADDRESS` and `ORBIT_ANC_NAME` (`AncService.qml:101-104`). This is a privacy choice: argv is readable by every user through `/proc`. The runner caps the name at 248 chars (`orbit_anc.py:234-238`).
- **One process per headset.** It is opened when one of these holds (`_wanted`, `AncService.qml:84-88`):
  - engine `"live"`;
  - a viewer count above 0;
  - `Wear.sessionWanted` (Sony wear pause).
- **How it ends:** QML sets `stdinEnabled=false` (`_release`, `:111-115`). The runner then waits for the headset to answer:
  - `LINGER_SECONDS=1.5` if the session is ready, `HANDSHAKE_GRACE=6.0` if not (`:186`);
  - it cuts this to 0.2 s once nothing is left in `pending`, `deferred` or `awaiting` (`:202-204`).
- **Hard stops:**
  - handshake timeout 10 s (`HANDSHAKE_TIMEOUT`, `:165-166`);
  - connect timeout 8 s (`CONNECT_TIMEOUT`);
  - the shell's `Component.onDestruction` sets `running=false` (`AncService.qml:345`).
- **Exit codes:** 0 ok, 1 socket error or protocol error (a frame no parser expected, audit 2026-11; the shell does not retry it), 2 unsupported family or bad argv.
- **What QML does on exit** (`_onExit`, `AncService.qml:263-293`). The daemon needs an explicit "ended" event to replace the process exit:
  - marks the snapshot `live:false`;
  - replays queued `set` lines into a new session;
  - re-syncs only if the session reached `ready` (`proc.reached`);
  - after an error it never retries and logs `ORB-E005`.
- Only one connection per headset at a time. Commands sent while a session is closing are queued in QML (`_queue`, `:143-148`).

### stdin (text lines, `parse_command`, `:108-117`)
```
get                 -> proto.refresh()
set <key> <value>   -> key in {mode, ambient, voice, chat, chatEnds, wear}
```
- Values stay strings.
- `set` before ready goes to `proto.pending` and is replayed in `mark_ready`.
- `set chat` or `set chatEnds` before the headset announces the feature goes to `proto.deferred` (`base.py:135-161`, `LATE_FEATURES`).
- Value checks are in `base.py:Protocol.set`:
  - `ambient` is clamped to `[0, ambientMax]`;
  - bool values are `1|true|on`;
  - `chatEnds` must be `0..3`.
- Lines QML actually sends: `set wear on|off` (`:106`, `:299`), `set chat off` (disconnect and reconnect, `:174`, `:239`), and `set <key> <value>` from `send()`.

### stdout (compact JSON, one object per line, emitted only when it changes)
```json
{"status":"connecting"}
{"status":"ready","model":"","features":{"modes":["off","nc","ambient"],"ambientMax":20,"levelMode":"ambient","voice":true,"chat":true,"chatEnds":false,"wear":false},"state":{"mode":"nc","ambient":null,"voice":null,"chat":false,"chatEnds":null,"wearing":null,"battery":{"left":{"level":80,"charging":false},"right":{"level":75,"charging":false},"case":{"level":40,"charging":true}}}}
{"status":"error","error":"vendor service not found"}
```
- The vocabulary is defined in `base.py:1-23`. Battery parts are `left`, `right`, `case` or `single`. `wearing` is 0-4.
- `snapshot()` never sends half-built state: before ready it is always `{"status":"connecting"}` (`base.py:167-179`).
- **Settle window:** the first `ready` is held back 0.5 s (`SETTLE_SECONDS`, `:46`, `:197-201`) so the card fills in once. A final snapshot goes out even if the session ends inside that window (`:212-214`).
- **Error strings are part of the API.** `Anc.errorText` (`Anc.js:91-103`) matches `"unsupported"`, `/not found/`, `/refused|denied|busy|reset/i` and `/timed out/i`. Python emits `str(OSError)`, for example `"[Errno 111] Connection refused"`, plus the fixed strings `"vendor service not found"`, `"timed out"`, `"headset closed the connection"`, `"connection failed"` and `"connection lost"`. Rust's `io::Error` Display (`"Connection refused (os error 111)"`) still matches. The safest choice is to emit the same fixed strings.
- Debug: `ORBIT_ANC_DEBUG=1` prints `>> hex` and `<< hex` on stderr only (`:51-57`).

### OS facilities
- **RFCOMM:** `AF_BLUETOOTH, SOCK_STREAM, BTPROTO_RFCOMM`, connected to `(bdaddr, channel)` (`open_socket`, `:65-105`).
  - Tries the SDP-found channel for the first UUID that resolves, then the fallback channel(s).
  - Fallbacks: Bose `[8,2]`, Huawei `[1,16]`, Nothing `[15,28]`; every other family has `None`.
- **L2CAP:** `SOCK_SEQPACKET, BTPROTO_L2CAP`. Apple uses PSM `0x1001` (`apple.py:14`, `:83`).
- Blocking connect with a timeout, then non-blocking.
- A `selectors` loop over the socket and raw `os.read(stdin)`. It polls every 0.25 s while handshaking, settling or `wants_tick()`, and otherwise blocks indefinitely.
- `proto.tick(monotonic)` runs after every event. The receive buffer is capped at 64 KiB (`base.py:116`, P117).
- Randomness: Xiaomi sends `os.urandom(16)` as its login challenge (`xiaomi.py:65`).

### `anc/sdp.py` (110 lines)
- Hand-written SDP client: one ServiceSearchAttributeRequest (PDU 0x06) for one 128-bit UUID, asking only for attribute 0x0004, over L2CAP PSM 1, following continuation state.
- Parses data elements recursively and walks ProtocolDescriptorList to find the RFCOMM (0x0003) channel.
- Timeout 5 s. Functions: `parse_element`, `build_request`, `split_response`, `rfcomm_channel`, `find_rfcomm_channel`.
- **There are no tests for sdp.py.** Write Rust tests with captured response bytes.

### Protocol families (lines, transport, ready_timeout, sources)

| family | lines | transport | ready_timeout | written from (credits must follow) |
|---|---|---|---|---|
| sony (`sony.py` 295 + `sony_extras.py` 82 + `sony_frame.py` 44) | 421 | RFCOMM UUID v2 `956c7b26…`, v1 `96cc203e…` | – (own retries: `RETRY_SECONDS=1.25`, `MAX_TRIES=3`) | Gadgetbridge, mos9527/SonyHeadphonesClient (**MIT**; wear and chat-ends, `sony_extras.py:1-12`); XM6 wear flow validated by phedoreanu, PR #63 |
| apple | 199 | L2CAP PSM 0x1001 | – (`RETRY_NOTIFICATIONS=1.5`) | LibrePods, MagicPodsCore |
| samsung | 170 | RFCOMM 3 UUIDs | 4.0 | GalaxyBudsClient, Gadgetbridge (CRC16-XMODEM) |
| huawei | 158 | RFCOMM SPP, fallback [1,16] | 3.0 (+ `SETTLE_SECONDS=1.5`, `time.monotonic` at `:110`, `:140`) | OpenFreebuds, Gadgetbridge (CRC16-XMODEM) |
| xiaomi (+ `safer.py` 77) | 217 | RFCOMM `0000fd2d…` | 6.0 | Gadgetbridge; SAFER+ from Bluetooth Core Vol 2 Part H (E1/Ar') |
| nothing | 137 | RFCOMM `aeac4a03…`, fallback [15,28] | 3.0 | Gadgetbridge, EarA-linux, earctl, cmfctl (CRC16-MODBUS) |
| soundcore | 136 | RFCOMM SPP | 3.0 | OpenSCQ30 (sum8) |
| bose | 104 | RFCOMM BMAP `…deca-fade…` + SPP, fallback [8,2] | 4.0 | Gadgetbridge, based-connect, bosectl |
| earfun | 100 | RFCOMM SPP | 3.0 | Gadgetbridge (GAIA) |
| oppo | 91 | RFCOMM `0000079a…` | 3.0 | Gadgetbridge (HeyMelody) |
| moondrop | 78 | RFCOMM GAIA `00001107…` + SPP | 3.0 | Gadgetbridge (GAIA v3) |
| onemore | 59 | RFCOMM SPP | 3.0 | Gadgetbridge |
| haylou | 53 | RFCOMM SPP | 2.0 | Gadgetbridge |
| shared: `base.py` 179, `checksums.py` 27, `__init__.py` 31 | 237 | | | |

**Credit gap:** README Credits (`README.md:273`) names **XMDeck**, but no code comment in `anc/` mentions it (grep finds nothing). Either the Rust Sony module adds the XMDeck comment, or the README entry needs checking. Every Rust module should copy its "Written from the byte-level facts documented by … (no code copied)" docstring.

### anc tests: 62 cases
- **`test_protocols.py` (28):**
  - Sony 3: XM6 query reply, charging bit, every data frame acked.
  - Apple 3: silent Max re-asked, plain AirPods with no modes, chat deferred.
  - Nothing 3, Samsung 2, Bose 3 (QC35 ANR, audio modes, error means no ANC), Soundcore 2 (Life Q30, Space Q45 adaptive).
  - Huawei 5 (read/set, NC normal level, charging per part, CRC checked, models without ANC), Oppo 2, Xiaomi 1 (login then state).
  - SmallBrands 4: earfun, moondrop, haylou, onemore.
- **`test_sony_extras.py` (22):** 15 on wear, 7 on ConversationEnds. It drives a fake `Headset` that records sent frames.
- **`test_framing.py` (10):** CRC-XMODEM vector (GalaxyBudsClient), CRC-MODBUS vector (Nothing), frames for Sony, Apple, Nothing, Samsung and Soundcore, SAFER+ vectors and tables.
- **`test_buffer.py` (2):** garbage capped at 64 KiB, and frames still parsed after garbage.
- **Not tested:** the runner itself (select loop, linger, settle, deadlines) and `sdp.py`.

### Rust effort and crates
- **Effort:**
  - **Runner, multiplexed in the daemon: M.** One task per address, with the linger, grace, settle and early-exit timers kept exactly.
  - **SDP: S.**
  - **Protocols: L in total** (about 2.2k Python lines, roughly 3–3.5k Rust). Sony is M/L. Apple, Xiaomi (SAFER+), Huawei, Samsung, Nothing, Bose and Soundcore are M each. EarFun, Oppo, Moondrop, 1MORE and Haylou are S. The Python design (pure byte-in/byte-out, a `send` callback, `tick(now)`) maps cleanly onto a sans-IO `trait Protocol`, and all 62 tests can be ported as pure unit tests with the same byte vectors.
- **Sockets:**
  - Use **raw `libc`** (or `nix`) for `sockaddr_rc` / `sockaddr_l2`: bdaddr is reversed, PSM little-endian, `SOCK_SEQPACKET` for L2CAP. Do a non-blocking connect, then poll or `SO_ERROR` for the 8 s and 5 s timeouts. Wrap the fd with tokio `AsyncFd` (or `mio`, or `poll`).
  - **Avoid `bluer`.** It depends on the `dbus` crate, which needs libdbus (C), and that is bad for a *static musl* build. It has no SDP client either, so `sdp.py` must be reimplemented anyway. If D-Bus is needed elsewhere, use `zbus`, which is pure Rust and works under musl.
- **Other crates:** `serde` and `serde_json`; `getrandom` (or `libc::getrandom`) for the Xiaomi challenge; optionally `tokio` (rt + io + time) or a hand-rolled `poll` loop. Checksums and SAFER+ are hand-written; no crate is needed.

---

## 2. `tick/orbit_tick.py`: resident volume-tick player (214 lines)

### Lifecycle
- **Who starts it:** `components/volume/VolumeTick.qml:57-72`, with `["python3","-I", helper, <sink node name>, sounds/volume.wav]`. `tests/qml/volumeTick.test.qml:71` asserts exactly this argv and will need updating.
- Up to `Volume.MAX_TICKS=4` players at once, one per output (`Volume.js:26`), in an `Instantiator` of `Process`.
- Starts on the first tick. QML closes stdin after `IDLE_MS=2000` without a tick (`Volume.js:75`, `VolumeTick.qml:84-88`). QML drops ticks closer together than `MIN_GAP_MS=50`.
- Ends on stdin EOF once the voice still ringing has finished, or on SIGTERM (`signal.signal(SIGTERM, sys.exit(0))`, `:168`). pw-cat then reads EOF too. `out.wait(timeout=1)`, then kill (`:202-210`).

### stdin protocol (no stdout at all)
```
t            -> one tick at gain 1.0
t 0.42       -> one tick at gain 0.42 (clamped 0..1; NaN/inf/garbage -> 1.0)
anything else -> ignored
```
- Every line in one read collapses to one tick, the last one (`:185-193`).
- Lines are capped at 64 bytes (`MAX_LINE`).

### Mechanics
- **Sound and mixer:**
  - `load()`: mono s16 48 kHz WAV, × `HEADROOM=0.5`, attack 72 samples, release 240.
  - `mix()`: 10 ms chunks (`CHUNK=480`).
  - `replace()`: the voice still ringing fades out over `FADE=240` samples. At most 2 voices sound at once.
  - The start offset inside a chunk is computed from a `deadline` clock (`:189-193`).
- **Output:** a `pw-cat -p --raw --rate 48000 --channels 1 --format s16 --latency 20ms -P node.name=orbit_tick_<pid>,node.autoconnect=false -` child process, with PCM on its stdin (`:164-167`).
- **Linking:** `link()` polls `pw-link -o` and `pw-link -i` up to 40 times, 50 ms apart. It then runs `pw-link -- <stream:port> <sink:input>` for each sink input (`link_plan`, `:129-157`).
  - Why: this keeps WirePlumber from routing the stream through the Listen-together filter, so a tick does not leak into the copies.
  - Missing pw-link or a hung PipeWire just means no tick, never an error.
- Waits in `select()`: no CPU while idle, writes 100 times a second while a tick rings.

### Tests: 20 cases
- `MixTest` 7: copy and end, delay, gain, fade-out on replace, 2 voices at most, no clip, shipped wav fades at both ends.
- `GainTest` 3.
- `LinkTest` 3: links to the sink's own inputs, never to the filter, nothing until both ends exist.
- `SessionTest` 2: end-to-end with a **fake `pw-cat` and `pw-link` on PATH**; an output that vanishes ends quietly.
- `BurstTest` 5: stays below full scale, no clip, at most 20 starts a second, at most 2 ringing, no click.

### Rust effort: S for the DSP, S/M or L for PipeWire
- **DSP:** a pure port of `mix`, `replace`, `parse_gain` and `load` (hand-parse the WAV or use `hound`).
- **PipeWire constraint:** `pipewire-rs` links **libpipewire (C, dynamic)**, which conflicts with a static musl binary that is committed to the repo and must run anywhere. The options are below. The same decision affects the other agents' "PipeWire events replacing pw-dump/pactl" work.
  - (a) Keep spawning `pw-cat` and `pw-link` from orbitd. **S.** The same OS tools as today, and the fake-PATH tests port as-is.
  - (b) `dlopen` libpipewire at runtime. M/L, unsafe FFI, and not static in practice.
  - (c) Implement the PipeWire native protocol over `$XDG_RUNTIME_DIR/pipewire-0` in pure Rust. L; no mature crate exists that I know of.
- **In the daemon:** one task per sink, stdin replaced by `{"op":"tick","sink":…,"gain":…}`. The 2 s idle timer can move into orbitd, and the SIGTERM handling becomes the daemon's.

---

## 3. `uninstall/orbit_uninstall.py`: sweep after uninstall (215 lines)

### Lifecycle today
- `components/common/UninstallSweep.qml` reads the **source text** of the script at load (`FileView`, `:35-53`).
- In `Component.onDestruction` (`:55-64`) it checks whether `plugin.json` is gone. If it is, it runs `Quickshell.execDetached(["python3","-E","-s","-c", script, pluginId, manifest, cacheDir, settings.json, plugin_settings.json, session.json])`.
- It runs from memory because the folder no longer exists by then.
- No stdin and no stdout ("Nothing is printed").

### What `sweep()` does (`:195-209`)
1. `valid()` (`:184-192`): the plugin id must match `[A-Za-z0-9_-]{1,64}`, the manifest basename must be `plugin.json`, the cache basename must equal the plugin id, and every path must be absolute.
2. `sleep(GRACE_SECONDS=4)`, then a second check for `plugin.json`. An update that re-clones the folder must not be swept.
3. `rmtree(~/.cache/<id>)`.
4. Edits three JSON files atomically, only if something changed (`edit`, `:110-134`: mkstemp in the same directory, `copymode`, `os.replace`, `indent=2`, `ensure_ascii=False`):
   - `plugin_settings.json`: deletes `data[id]`;
   - `settings.json`: removes widgets matching `id`, `id:*` or `plugin_id` from `barConfigs[*].{left,center,right}Widgets` and from `controlCenterWidgets`, and removes matching `desktopWidgetInstances`;
   - `session.json`: removes `desktopWidgetInstancePositions[<removed ids>]`.
5. `give_back_keys()` (`:175-181`):
   - `dms keybinds show niri` (JSON); finds `XF86Audio{Raise,Lower}Volume` bound to an action containing `ipc call <id> volume`;
   - parses the step with the regex at `:170` (clamped 1..20, fallback `FALLBACK_STEP=3`, which must stay in sync with `components/volume/Keys.js`);
   - for each key, `dms keybinds set niri <key> "spawn dms ipc call audio increment|decrement <step>" --allow-when-locked --json`;
   - the subprocess timeout is 10 s.

### Tests: 13 cases
- `SweepTest` 9: nothing while installed, leaves nothing, forgets what it learned, memory kept while installed, re-clone during the grace keeps everything, untouched files not rewritten, permissions kept, broken or missing files left alone, bad args erase nothing.
- `KeysTest` 3.
- `IdTest` 1.
- Uses a fake `Shell` with temporary files and an injected `run`.

### The constraint, and how it could work in Rust
The binary lives inside the plugin folder that DMS deletes. Facts that help: on Linux, a running process whose executable was unlinked keeps running, and `/proc/self/exe` can still be executed after the file is deleted.

- **A (recommended): orbitd sweeps itself on shutdown.**
  - QML passes `pluginId`, `manifest`, `cacheDir` and the three JSON paths to orbitd at start, in argv or a `hello` message. No personal data is involved: they are paths.
  - On stdin EOF or SIGTERM, orbitd `fork()`s and the child calls `setsid()`, ignores SIGHUP and closes its fds. Alternatively it spawns `/proc/self/exe sweep <args>` with `setsid` and `process_group(0)`.
  - The child sleeps 4 s, rechecks `plugin.json`, then sweeps.
  - It runs on every shell quit or reload but exits after 4 s when `plugin.json` is still there. That costs nothing.
  - It removes `UninstallSweep.qml`'s FileView and the in-memory script string, and the python3 dependency.
  - **Risks to check:**
    - How Quickshell stops a `Process` on destruction (SIGTERM vs SIGKILL). SIGKILL would skip the sweep, so the fork must happen on stdin EOF, which comes first.
    - Whether DMS deletes the folder before or after unloading. The 4 s grace covers both orders.
    - Shell crashes: on SIGKILL the sweep never runs. That is acceptable, since today's QML `onDestruction` would not run either.
- **B: QML still decides, and orbitd forks the detached sweeper on a `{"op":"uninstall"}` message.** This keeps today's "plugin.json is gone" check in QML. It depends on orbitd still being alive inside `Component.onDestruction`, which is fragile.
- **C: copy the binary to `$XDG_RUNTIME_DIR` (or a memfd) at start and exec it later.** This writes to disk or adds complexity. Not recommended.
- **D: keep a tiny Python sweep.** This conflicts with "no Python" because it keeps python3 as a dependency. Owner decision.

**Porting details:**
- `serde_json` with the `preserve_order` feature, plus a 2-space `PrettyFormatter`, which matches Python's `indent=2` (`": "` separators, raw UTF-8).
- Float formatting can differ from Python, for example `1e-05` vs `0.00001`. Add a round-trip test on real DMS files.
- Atomic write: `tempfile::NamedTempFile::new_in(dir)` plus `set_permissions` from the original file, then `persist`. Or hand-roll it with `O_EXCL`.
- `std::process::Command("dms")` with a 10 s timeout.
- **Effort: S/M** (port plus the detach logic); the 13 tests port 1:1.

---

## 4. `scripts/diagnose.sh` (108 lines, POSIX sh)
- **What it is:** a user-run CLI, not a helper. Nothing starts it automatically.
- **Main path:** calls `dms ipc call orbitBluetooth diagnostics` twice, 2 s apart, with one extra retry on `"Still collecting"`.
- **Fallback:** prints `dms version`, `quickshell --version`, `niri --version`, `/etc/os-release` and the `[orbit]` lines from `journalctl --user -u dms -n 300`.
- Adds the latest `~/.cache/quickshell/crashes/*` (file names and sizes, the first 40 lines of each `.txt` and `metadata`).
- Everything goes through `reduce()`, which removes:
  - `$HOME`, the login and the host name, as fixed text via awk with ENVIRON, never as a pattern, and only when at least 3 chars;
  - `/home/*` and `/run/user/N` paths;
  - MAC addresses (with `:`, `-` or `_`), IPv4 addresses, runs of 40 or more token chars, and emails.
- Tests: `tests/diagnose.test.sh`, 9 checks, with fake tools on PATH and a fake home.
- **Recommendation: keep it as sh.** It is the fallback for when the plugin and daemon do not answer, so it must not depend on orbitd. Optional additions, effort XS: one line `orbitd --version` (and its arch) in the fallback, and the binary's SHA-256 checked against the committed one. If it were ported anyway, it is S, but there is no gain.

---

## 5. Cross-cutting points for the daemon protocol
- **One process becomes one multiplexed daemon.** Every message needs `addr` (ANC) or `sink` (tick). Process exit becomes explicit events. Suggested shapes:
  - ANC: `{"op":"anc.open","addr":"AA:…","family":"sony","name":"…"}`, `{"op":"anc.set","addr":…,"key":"mode","value":"nc"}`, `{"op":"anc.get"}`, `{"op":"anc.close","addr":…}`;
  - events: `{"ev":"anc","addr":…, <same snapshot as today>}` and `{"ev":"anc.ended","addr":…,"code":0|1|2}`, which drives `_onExit`'s requeue, `reached` and no-retry-after-error logic;
  - tick: `{"op":"tick","sink":…,"gain":0.42}`.
  - The device name moves from the env var into the JSON on stdin, which keeps it out of `/proc/*/cmdline` just as the env var did.
- **Semantics to keep exactly:**
  - linger 1.5 s, grace 6 s, early exit 0.2 s;
  - handshake 10 s, connect 8 s, SDP 5 s, settle 0.5 s;
  - per-brand `ready_timeout`;
  - Sony ack and retry (1.25 s × 3), Apple re-ask at 1.5 s;
  - only one RFCOMM connection per headset;
  - `pending` and `deferred` queues;
  - 64 KiB buffer cap.
- **Privacy:** no network, `ORBIT_ANC_DEBUG` writes to stderr only and never to a file. The daemon must not log addresses or names by default.
- **Tests to update:**
  - `tests/qml/ancSessions.test.qml:110` (`ORBIT_ANC_NAME` in the environment);
  - `tests/qml/volumeTick.test.qml:71` (`python3 -I` argv);
  - the CLAUDE.md test commands (`anc/` and `tick/` unittest lines);
  - docs: `CONTRIBUTING.md:84`, `:92`, `:191-205`; `docs/GUIDE.md:536`, `:787` ("Python standard library only").

## 6. Questions for the owner
1. **Uninstall:** strategy A (orbitd forks a detached sweeper on stdin EOF, 4 s grace) or B (QML sends `uninstall` and orbitd detaches)? Is a python3 dependency for the sweep alone acceptable (D), or must python3 disappear entirely?
2. **PipeWire:** should orbitd keep spawning `pw-cat`, `pw-link` and `pw-dump` (static musl, no libpipewire), or link libpipewire, which breaks "static" and the arch-only selection? Or pure-Rust native protocol (L)? This decides the tick port and the other agents' PipeWire work.
3. **D-Bus:** `zbus` (pure Rust, musl OK) rather than `bluer` and `dbus` (libdbus C)? I recommend zbus plus raw libc Bluetooth sockets.
4. **Async runtime:** tokio (current-thread), or a hand-rolled `poll(2)` loop to keep the binary small? Is there a target binary size?
5. **ANC engine:** keep "demand" vs "live" exactly (sessions opened and closed per viewer), or let orbitd hold the connections and QML only subscribe?
6. Should the error strings stay byte-identical to the Python ones, since `Anc.errorText` regex-matches them, or should they become error codes?
7. **XMDeck** is credited in the README but in no code comment. Which Sony detail came from it, so the Rust comment can credit it?
8. Should `scripts/diagnose.sh` stay sh, and print the orbitd version, arch and SHA check?
9. Should the 95 Python tests be ported 1:1 to `cargo test` and the Python suites deleted in the same release, or kept until parity is shown?
10. Should `sdp.py` get tests now (captured SDP responses), before the port?
11. Should `ORBIT_ANC_DEBUG` stay as an env var of orbitd, or become a `{"op":"debug"}` toggle?
12. **Release:** should the GitHub Actions workflow (none exists yet) also check that the committed binary's SHA matches a reproducible build, and with which toolchain pin?
