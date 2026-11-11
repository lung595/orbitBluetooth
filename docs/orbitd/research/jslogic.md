# Pure JS logic slated for orbitd: who calls it, and what can actually move

I made no edits. gjs is not installed on this machine, so I did not run the JS tests. Check counts below are static counts of `eq(` lines. Loops add more checks at run time (I noted `for` loops where they exist).

## 0. Main findings (read first)

1. **Four files with no live caller.** `BatterySessions.js` (308 lines) is only used by `components/battery/BatteryHistoryStore.qml`, and nothing creates that component (its header at :7-8 says "Not loaded by any view yet"). `ConnectRules.js` (124) is only used by `ConnectRulesRunner.qml`, also never created (its header at :7 says the same). `ReportFile.js` (198) is only imported by `tests/qml/reportFile.test.qml`. `Endurance.js` is live, but its only caller is `BodyState.qml:56`. Porting the first three adds no live behaviour. The owner should choose: port them, wire them first, or drop them.
2. **Some files the decision says to keep in JS depend on files it says to move.** These imports are synchronous and sit in bindings:
   - `together/Ghost.js` (keep) imports `Habits.js`, `Together.js` and `Member.js`. It calls `Habits.choose` and `Habits.bestFirst` (Ghost.js:74, :80) and `Together.MAX_LIST_LENGTH` (:98). It runs inside the `OrbitGhost.qml:72` binding `proposal`, which also passes `list => session.check(list)`, i.e. `Together.refusal`.
   - `volume/Polar.js` (keep) uses `Together.MAX_MEMBERS` (:36, :52, :66).
   - `scene/Physics.js`'s drag path depends on `Together.refusal` / `joinRefusal`. Each pointer move runs `OrbitDrag.qml:52` → `OrbitTogether.relevant` → `session.relevant`, then `ready()` → `_note` → `session.dropCheck` → `Together.refusal` / `joinRefusal` (TogetherSession.qml:172-187). `candidates(b)` (OrbitTogether.qml:47) runs `ready` once for every body.
   - Other UI JS files not on either list import moved files: `common/Guide.js` (Together, Member), `common/Hidden.js` (Member, Wired.labelOf), `centre/MemberGlyph.js` (Catalog, Glyphs, Member), `centre/WiredSign.js` (Wired.kindOf), `radio/Radio.js` (Route.addressOfSink, :18 and :37).
   - The decision's "JS stays" list is incomplete. Glyphs, Palette, Guide, Text, Hidden, Gauge, Sun, Perspective, BeamMotion and others appear on neither list.
3. **`dms ipc` handlers must answer synchronously.** OrbitIpc.qml functions return a `string` straight away; the comment at :280 says "a call must answer at once". The handlers that call moved code are `together`, `togetherAdd`, `togetherStatus`, `togetherOutputs`, `wiredDelay`, `togetherDelay` (OrbitIpc.qml:212-276) and the `DisconnectDelays.start` / `stop` results. Each one needs one of:
   - a cached copy that the daemon pushes,
   - the validation kept in JS,
   - or the "ask twice" pattern that `diagnostics()` already uses (:281-290). This last option changes the CLI contract.
4. **Many Route.js helpers take live Quickshell `PwNode` objects, not data.** These are `deviceSink`, `sinkNamed`, `virtualSink`, `tickOutput`, `levelNodes`, `writeLevel`, `writeMuted` and `shownLevels`. `writeLevel` sets `n.audio.volume` during the drag gesture (AudioRoute.qml:182-188). They can only move if the daemon also takes over the PipeWire volume write path, which is a separate decision. The node lookups are used in property bindings (`RouteDevice.qml:30,32`, `HeadsetStreams.qml:17-18`, `TwoLevels.qml:32`).
5. **`Member.js` (75 lines) must exist in both JS and Rust with identical output.** `Member.key` and `Member.hash` (FNV-style, `SEEDS=[2166136261,305419896]`) produce the node names `orbit_together_<key>` and `orbit_wired_<key>`. JS needs them for synchronous reads (22 QML call sites plus 8 JS modules). Rust needs them to build the `pw-loopback` names. The same goes for `BatterySessions.sha256` (:142), `ConnectRules.keyOf` (`SEEDS=[1540483477,2246822519]`) and `Habits.tag` (`SEED=2654435761`). Byte-exact golden vectors are mandatory for these.

## 1. Every file in scope

How to read the tables:
- **Binding** means a `readonly property` expression, re-evaluated synchronously.
- **Gesture** means it runs during a pointer drag or a frame loop.
- **Event** means a handler such as `onExited`, `onXChanged`, a signal or a timer; these could wait for an async reply.
- **IPC-sync** means a `dms ipc` handler that must return at once.
- Functions starting with `_` are private and not listed.

### volume/

| File | Lines | Exported | Call sites → kind | Tests (eq) | Class |
|---|---|---|---|---|---|
| Route.js | 284 | `virtualName isVirtual addressOfVirtual sinkKey isDeviceSink addressOfSink deviceSink sinkNamed tickOutput virtualSink description loopbackArgs filterArgs wiredFilterName isWiredFilter wiredFilterArgs muteTarget levelNodes tickNodes writeLevel writeMuted ipcLevel transportPath transportVolume iconFor shownLevels`, constants `PREFIX MAX_DELAY_MS WIRED_PREFIX LOOPBACK_SCRIPT` | see below | volume.test.js about 39 of 169; wiredfilter.test.js 9 of 35; QML: audioRouteWriting, togetherSession | **Split** |
| Audiophile.js | 168 | `INFOS CHANNEL_NAMES connectionOf factsOf parse kilohertz chainOf textOf line rows merge needs` | see below | audiophile.test.js 28; settingsSearch.test.js uses INFOS; QML audioFacts | **B** |
| Keys.js | 124 | `action setArgs dmsAction backArgs isOrbit classify succeeded`, constants `PROVIDER KEYS DMS_VERB FALLBACK_STEP SHOW_ARGS` | see below | volume.test.js about 16; QML volumeKeys | **A** |
| Volume.js | 129 | `stepSize clamp step validSink stepsCrossed due tickGain linearGain audible tickTargets slotsFor`, constants `MAX_TICKS MIN_GAP_MS TICK_KNEE MIN_GAIN IDLE_MS` | see below | volume.test.js about 34; QML volumeTick, volumeTickTarget | **A** |
| Members.js | 55 | `heardOf scales sectors scaleAt easeAll settled` (imports Polar) | see below | members.test.js 25 | **C** |

**Route.js call sites:**
- *Gesture:* `AudioRoute.writeLevel` :182-188 calls `levelNodes`, `writeLevel`, `tickNodes`, and `tickOutput` (:173). It is reached from `stepNode` (wheel, keys) and from slider drags.
- *Event / IPC:* `writeMuted` (:203, toggleMute). IPC-sync: `ipcLevel` (AudioRoute.qml:220, GroupVolume.qml:86) and `muteTarget` (:357).
- *Function calls on demand:* `sinkNamed` and `wiredFilterName` (AudioRoute.qml:43, :46), called from bindings in TogetherSession (`_facts`, `_sound`, `plan` :246, `_gone`, `sharedNode`).
- *Bindings:* `deviceSink` and `virtualSink` (RouteDevice.qml:30, :32; HeadsetStreams.qml:17-18), `shownLevels` and `iconFor` (TwoLevels.qml:32, :54).
- *Process `command:` binding:* `filterArgs` (RouteDevice.qml:107).
- *Event `onExited`:* `transportPath` and `transportVolume` (RouteDevice.qml:67, :82).
- *JS callers:* Together.js (`isDeviceSink isVirtual isWiredFilter loopbackArgs wiredFilterArgs MAX_DELAY_MS`) and Radio.js (`addressOfSink`).

**Route.js split:**
- **A** (string and argv builders, BlueZ parsing): `loopbackArgs`, `filterArgs`, `wiredFilterArgs`, `description`, `transportPath`, `transportVolume`. The daemon spawns `pw-loopback` and reads the AVRCP `Volume` over D-Bus. `LOOPBACK_SCRIPT`'s "die with the shell" trick becomes the daemon's own child lifetime.
- **C** (live PwNode or icons): `deviceSink`, `sinkNamed`, `virtualSink`, `tickOutput`, `levelNodes`, `tickNodes`, `writeLevel`, `writeMuted`, `shownLevels`, `iconFor`, `muteTarget`.
- **Both sides** (name predicates: tiny, pure, needed by stay-files): `sinkKey`, `isDeviceSink`, `addressOfSink`, `isVirtual`, `virtualName`, `wiredFilterName`, `isWiredFilter`.
- `ipcLevel` is IPC-sync, so it either stays or gets a Rust twin.

**Audiophile.js call sites:**
- *Static table:* `INFOS`, read in Prefs.qml:129 (binding `factsLine` / `factsMore` built per key) and as a model in AudioPage.qml:22.
- *Event:* `parse` in AudioFacts.qml:44 (`onExited` of `pactl --format=json list sinks`).
- *Bindings:* `merge`, `line`, `rows`, `needs` (TwoLevels.qml:140, :146-148).
- B: the daemon pushes `{sink: facts}`, already merged with the pw-dump / pw-top graph, from PipeWire events. That ends the `pactl` / `pw-dump` / `pw-top` runs. Keep `INFOS` and the roughly 50 lines of `line`/`rows`/`textOf` in JS (UI wording that depends on prefs). `needs()` disappears.

**Keys.js call sites:** all event-driven, in VolumeKeys.qml. `FALLBACK_STEP` is a property default (:25), `setArgs` is called when the run starts (:49), `backArgs` (:81), `SHOW_ARGS` is a command (:102), `classify` (:107, `onExited`), `succeeded` (:125, `onExited`). VolumeKeys is created in OrbitBluetoothDaemon.qml:96 and settings/VolumeKeysRow.qml:19. Note that this logic drives the `dms keybinds` CLI, so it is shell-out logic whether it lives in Rust or JS.

**Volume.js call sites:** only `VolumeTick.play()` uses it (:35-51, :76, :86, :93): `stepsCrossed`, `stepSize`, `due`, `tickTargets`, `slotsFor`, `MAX_TICKS` (Instantiator model), `IDLE_MS` (Timer interval). `play` is called on each step, but it is fire-and-forget: it returns nothing to the gesture. Send `{"tick":{nodes,before,after,levels}}` and the daemon decides and plays. This also replaces `python3 tick/orbit_tick.py` (VolumeTick.qml:67).

**Members.js call sites:**
- *Binding:* `heardOf` (TwoLevels.qml:84), `sectors` (PolarScope.qml:237), `scaleAt` (PolarVisual.qml:67, :153; :153 is in the particle paint path).
- *Frame loop:* `easeAll` (PolarScope.qml:264, the Timer at `1000/fps`), `settled` (:208).
- It is the polar renderer's helper (it imports Polar.js). It is not routing; keep it in JS.

### together/ (Ghost.js excluded)

| File | Lines | Exported | Call sites → kind | Tests (eq) | Class |
|---|---|---|---|---|---|
| Together.js | 334 | `address member inCall memberRefusal fits clean refusal joinRefusal merge without present source plan cleanDelay delayArg isOutput isSource args filterCommand commands diff prune withDelay parseList status`, constants `MAX_MEMBERS MAX_DELAY_MS FILTER_KEY NAME MAX_LIST_LENGTH` | see below | together.test.js 149; wiredfilter.test.js 13; choice/delay/habits/ghost use constants; QML togetherSession, groupLeave, wiredMembers, togetherNames | **Split** |
| Choice.js | 225 | `labels build toggle outcome hideWhy`, constants `SECTIONS HIDDEN WIRED_ICONS BLUETOOTH_ICONS FALLBACK_ICON CAPTIONS` | see below | choice.test.js 82; QML groupChooser, hideMenu | **C** |
| Wired.js | 185 | `command labelOf parse fromNodes kindOf kindOfNode iconOf describe sameSet`, constants `MAX_TEXT MAX_OUTPUTS FALLBACK_LABEL SINK_NAME ICONS` | see below | wired.test.js 83; QML wiredWatch, twoLevelsWired | **Split** |
| Delay.js | 169 | `isLatency cleanFine fineText fineFrom latenciesOf autoDelayMs delaysFor unknownOf total waitsFor`, constants `MAX_FINE_MS FINE_STEP_MS` | see below | delay.test.js 70; QML fineDelayRow | **Split** |
| Habits.js | 165 | `dayOf tag keyOf tagsOf score sets ranked count record forget choose partners bestFirst reaches`, constants `MAX_SETS MAX_USES MIN_USE_MS HALF_LIFE_DAYS DAY_MS SEED TAG` | see below | habits.test.js 40 (5 loops); ghost.test.js 83 runs it indirectly; QML habitLog, habitsRow, ghostGroup | **C** (B only if Ghost's ranking also moves) |
| Member.js | 75 | `clean kind isWired hash key`, constants `SINK_PREFIX MAX_LENGTH WIRED SLUG_LENGTH SEEDS` | 22 QML sites plus Route, Together, Choice, Delay, Habits, Ghost, Guide, Hidden, MemberGlyph, WiredSign, ConnectRules; all synchronous | member.test.js 29 | **C and Rust twin** (golden) |

**Together.js call sites:**
- *Gesture* (each pointer move): `refusal`, `joinRefusal`, `merge`, `member`, through `dropCheck` and `relevant` (TogetherSession.qml:121-197). Reached from OrbitDrag.qml:52 and OrbitTogether.qml:26-47.
- *Bindings:* `memberRefusal` (GroupChooser `view` callback :62, OrbitTogether.canGroup in OrbitMenu.qml:45), `plan` (TogetherSession.qml:246), `MAX_MEMBERS` (GroupGlyphs.qml:31, PolarScope.qml:78-79).
- *Event:* `commands` (`_replan` :290-298, fired from `on*Changed`), `diff` (TogetherLink.qml:38), `prune`, `withDelay` (:232, :240).
- *IPC-sync:* `parseList`, `status`, `member`, `MAX_DELAY_MS` (OrbitIpc.qml:214, :237, :266, :273).

**Together.js split:**
- **A:** `plan`, `source`, `present`, `args`, `filterCommand`, `commands`, `diff`, `cleanDelay`, `delayArg`, `isOutput`, `isSource`. The daemon owns the copies and runs them on PipeWire default-sink and node events. TogetherLink.qml goes away.
- **B:** session state (`members`, `delays`, `source`, `latencies`). It becomes a daemon-owned record pushed to QML. `isMember` and the face read the cached copy.
- **C:** `refusal`, `joinRefusal`, `memberRefusal`, `merge`, `clean`, `member`, `fits`, `inCall`, plus the constants. They are needed synchronously during drag and in the Ghost and chooser bindings. A workable redesign: the daemon pushes a per-output map `{who: {connected, sink, profile}}` (what `_facts` computes now, TogetherSession.qml:79-93), and the 40-line combination logic stays in JS. The Rust twin re-validates on `start` / `add`.

**Choice.js call sites:**
- *Bindings:* `labels` (GroupChooser.qml:54; OrbitMenu.qml:45 in the menu entries), `build` (GroupChooser.qml:55), `outcome` (:67; OrbitTogether.qml:107).
- *Event:* `toggle` (:94, click), `hideWhy` (OrbitHidden.qml:37).
- It is a view-model (icons, captions, sections). It only needs the cached eligibility map. Keep in JS.

**Wired.js call sites:**
- *Event:* `command`, `parse`, `sameSet` (WiredWatch.qml:36-43, `pactl` `onExited`).
- *On demand / IPC-sync:* `fromNodes` (AudioRoute.qml:51), `describe` (OrbitIpc.qml:245).
- *Binding:* `labelOf` (TogetherSession.nameOf :59; Hidden.js:55; Choice.js :116-145), `kindOf` (WiredSign.js:23; Choice.js:127), `iconOf` and `kindOfNode` (TwoLevels.qml:70).

**Wired.js split:**
- **A:** `parse`, `command`, `sameSet`, `fromNodes`, `describe`. The daemon pushes the list of wired outputs from PipeWire node events, which ends the WiredWatch `pactl` polling-on-demand.
- **C:** `labelOf`, `kindOf`, `kindOfNode`, `iconOf`, `ICONS`.

**Delay.js call sites:**
- *Event:* `latenciesOf` (MemberLatency.qml:54, `pw-dump` `onExited`), `unknownOf` (TogetherSession.qml:277, `onMeasured`), `waitsFor` and `total` (:292-293, `_replan`).
- *Binding:* `cleanFine` (Prefs.qml:73; FineDelayRow.qml:29, :32), `fineText` (FineDelayRow.qml:83 slider label, :131), `MAX_FINE_MS` and `FINE_STEP_MS` (slider bounds :108-110).
- *IPC-sync:* `fineFrom` and `fineText` (OrbitIpc.qml:253, :258).

**Delay.js split:**
- **A:** `latenciesOf`, `autoDelayMs`, `delaysFor`, `unknownOf`, `total`, `waitsFor`, `isLatency`. Latency comes from PipeWire events, which ends `pw-dump`.
- **C:** `cleanFine`, `fineText`, `fineFrom` and the constants (slider and IPC, about 40 lines).

**Habits.js call sites:**
- *Binding:* `reaches` (OrbitGhost.qml:60), `dayOf` (:77), and `choose` / `bestFirst` through Ghost.js inside the `proposal` binding (:72).
- *Event:* `record` and `count` / `forget` (HabitLog.qml:29-30, :50-51; HabitsRow.qml:31, :120).
- Storage is DMS plugin settings (`prefs.set("togetherHabits")`), and only QML can write that.
- `record` / `forget` / `count` (event-driven) could move, but they are about 30 lines and the daemon would only hand the blob back to QML to save. Since Ghost.js stays, keeping Habits in JS is the consistent choice.

### battery/, card/, wear/, rules/, device/, delay/

| File | Lines | Exported | Call sites → kind | Tests (eq) | Class |
|---|---|---|---|---|---|
| battery/BatterySessions.js | 308 | `newTracker feed disconnect usable estimate thresholdOf newAlert lowBattery sha256 deviceKey newHistory parse writeCommand eraseCommand serialize prune record touch lastSeen sessionsOf`, constants `THRESHOLDS DEFAULT_THRESHOLD MIN_SESSIONS RECENT_SESSIONS KEEP_MS MAX_GAP_MS MIN_USABLE_MS MIN_USABLE_DROP MAX_SESSIONS_PER_DEVICE MAX_DEVICES FUTURE_SLACK_MS REARM_MARGIN` | only BatteryHistoryStore.qml (:19-105, all functions or events), which nothing creates | batterySessions.test.js 56 (2 loops); historyDisk.test.js 11 | **A** (unwired) |
| card/Charge.js | 250 | `analyze formatMinutes formatShort formatClock approxMark timeText levelText statItems footnote levelColor`, constants `STALE_MS TAPER_FROM TAPER_FACTOR RAMP UP_*` | see below | battery.test.js about 15 of 37; card.test.js 2; QML chargeColors, batteryArc, chargeBeam | **Split** |
| card/Endurance.js | 66 | `ratedHours`, tables `MODELS KINDS` | binding BodyState.qml:56 only, as input to `analyze` | battery.test.js about 2 | **A** (with analyze) |
| card/CardStatus.js | 56 | `kindLine statusIcon statusText detailText` | binding CardBattery.qml:28-30, FocusCard.qml:103 (wording; `statusText` takes `scene.now`) | card.test.js about 22 | **C** |
| wear/Wear.js | 173 | `classify step eligible sessionWanted followed changes token busName playerKeys streamKeys sameApp pausable stillPaused resumable report`, constants `WORN REMOVED MPRIS_PREFIX STREAM_PROPS` | see below | wear.test.js 68; QML wearPause | **A** |
| rules/ConnectRules.js | 124 | `keyOf sanitize newState noteUserVolume onConnected`, constants `STORM_MS UNSUPPORTED USER_LOWERED INVALID STORM SEEDS` | events in ConnectRulesRunner.qml:21-40, which nothing creates | connectRules.test.js 42; QML connectRulesRunner | **A** (unwired) |
| device/DeviceCatalog.js | 159 | `kindFromBluezIcon familyFromBluezIcon deviceName modelName isUnnamed kindFor resolve hash01 formatDuration`, tables `families rules` | see below | device.test.js 5 (thin) | **C** (Rust twin of `resolve` / `families` if the daemon needs kind) |
| device/Glyphs.js | 101 | `path label wired`, tables `paths labels order wiredGlyphs` | bindings DeviceGlyph.qml:37, WiredBody.qml:150, GlyphPicker.qml:20, OrbitPage.qml:57-58, CardStatus.js:16, MemberGlyph.js:13 | diagnostics and reportFile load it, 0 direct checks | **C** |
| delay/DisconnectPhrase.js | 82 | `note fold connectedOf findDevice cleanMinutes schedule cancel`, constants `MIN_MINUTES MAX_MINUTES MAX_PHRASE NOTES` | see below | disconnectPhrase.test.js 17; QML disconnectDelays | **B** |

**Charge.js call sites:**
- `analyze`: binding BodyState.qml:57, once per body. It is re-evaluated **every second** through `scene.now` (OrbitDaemonData.qml:34-43, a 1 s Timer while awake) and on every globals change.
- *Bindings:* `timeText` and `statItems` (FocusCard.qml:30, :38), `footnote` (CardBattery.qml:27), `levelColor` (BatteryCard.qml:35, EarbudsTrio.qml:226), `formatShort` (BodyLabel.qml:72), `levelText` (CardStatus.js:51).

**Charge.js split:**
- **B:** `analyze`, with `_minutesToFull` and `_risingRun`. The daemon already owns the battery log and UPower data, so it pushes `charge` for each device on every sample. `now` only affects the 25-minute `STALE_MS` and countdowns, which QML can derive from `fullAt` and `scene.now`.
- **C:** `format*`, `timeText`, `levelText`, `statItems`, `footnote`, `approxMark`, `levelColor`, `RAMP` (UI wording and colour, about 110 lines).

**Wear.js call sites:**
- *Event:* `step`, `pausable`, `stillPaused`, `resumable` (WearHeadset.qml:34-75; they take `Mpris.players.values` and `MprisPlaybackState`), `followed` and `changes` (WearPause.qml:29-32).
- *IPC:* `report` (WearPause.qml:76, `wearStatus`).
- *Called by AncService:* `sessionWanted` and `eligible` (AncService.qml:87, :105, :301; these move with the ANC code).
- *Binding:* `streamKeys` (HeadsetStreams.qml:47).
- Clean A, but only if the daemon also takes over MPRIS (`org.mpris.MediaPlayer2.*` over D-Bus) and the PipeWire stream properties.

**DeviceCatalog.js call sites:** all synchronous.
- *Bindings:* `deviceName` (BodyState.qml:20, TwoLevels.qml:71, :86, Widget.qml:53, OfferCard.qml:37, HiddenCard.qml:32), `modelName` (BodyState.qml:22), `resolve` (BodyState.qml:23, Widget.qml:99, HiddenCard.qml:176, TwoLevels.qml:54, MemberGlyph.js:14), `hash01` (DeviceBody.qml:32, home position), `isUnnamed` (OrbitDevices.qml:30, OrbitOffer.qml:26), `families` (Choice.js:133), `formatDuration` (BodyLabel.qml:85, CardStatus.js:42).
- *Event:* OrbitConnections.qml:42.

**DisconnectPhrase.js call sites:**
- *IPC-sync:* `cleanMinutes`, `findDevice`, `connectedOf`, `schedule`, `cancel` (DisconnectDelays.qml:58-94; `start` / `stop` return `{ok, why}` to OrbitIpc), `note` (OrbitIpc.qml:65).
- *Event:* `cancel` (:118).
- The timers and `device.disconnect()` can live in the daemon (BlueZ `Disconnect` over D-Bus). Validation and `findDevice` must answer the IPC at once, from a pushed device list (or keep this 82-line file in JS).

### diagnostics/

| File | Lines | Exported | Call sites → kind | Tests (eq) | Class |
|---|---|---|---|---|---|
| Allow.js | 37 | `value pick`, `INT_LIMIT` | JS only (Log, Report, ReportFile) | diagnostics.test.js about 11 | A |
| Codes.js | 114 | tables `LABEL PLUGIN FIELDS CODES SURFACES SETTINGS FACTS DEVICE` | JS only | about 7 | A, and a JS copy of the code IDs if Log stays local |
| Cpu.js | 41 | `ticksOf percent line` | ReportService.qml:76, :88 (event, /proc/stat) | about 8 | A |
| Gather.js | 105 | `account parse pluginVersion settingsOf missing capped`, `PROBES COPY_TOOLS MAX_REPORT` | see below | about 12 | A, but `settingsOf` needs prefs pushed |
| Log.js | 75 | `setSink levelOf event entries clear`, ring `CAPACITY=200` | see below | about 8; reportLeaks.test.js 17 | **B** |
| Redact.js | 227 | `register identity forget text command` | ReportService.qml:110; JS (Log, Report, ReportFile) | about 42; reportLeaks.test.js | A |
| RedactRules.js | 181 | `apply` plus regex tables | JS only (Redact) | through Redact | A |
| Report.js | 120 | `build` | ReportService.qml:112 (event, after the probes finish) | about 1 direct, plus leaks | A |
| ReportFile.js | 198 | `fileName devices errors build` | **no QML caller**, tests only | reportFile.test.js 54 (9 loops); QML reportFile.test | A (unwired) |

**Gather.js call sites:**
- *Event:* `missing` (ReportCopy.qml:38), `pluginVersion` (ReportService.qml:53), `account` (:131), `parse` (:172, probe `onExited`), `settingsOf` (:123).
- *IPC-sync:* `capped` (OrbitIpc.qml:287).

**Log.js call sites:** `Log.event` is fire-and-forget at 13 sites: the four entry-point `Component.onCompleted` / `onDestruction` handlers, AncService.qml:279, AdapterNotice.qml:22, OrbitScene.qml:109, RouteDevice.qml:113, ReportCopy.qml:39, :43, ReportService.qml:45. It is never in a binding.

The diagnostics report flow is already asynchronous (ask twice), so moving it is easy. The exception is Log: keep a small JS `Log.event` that forwards to the daemon and keeps a local ring for errors raised while the daemon is down or crashed.

## 2. Totals

- **A, move cleanly (about 1,950 lines):**
  - Keys 124, Volume 129, Wear 173, Endurance 66.
  - The three unwired files: BatterySessions 308, ConnectRules 124, ReportFile 198.
  - diagnostics minus the Log shim: Allow, Codes, Cpu, Gather, Redact, RedactRules, Report (825).
  - The A parts of Route (about 90), Together (about 120), Wired (about 70), Delay (about 100).
- **B, daemon pushes and QML keeps a cache:**
  - Audiophile facts.
  - Charge.analyze.
  - The Listen together session record and the per-output eligibility map.
  - The wired-output list and the latencies.
  - DisconnectPhrase's pending delays and connected list.
  - Log (forwarding shim).
- **C, stay in JS:**
  - Members 55, Choice 225, Habits 165 (because Ghost.js stays), Member 75 (plus a Rust twin), CardStatus 56, Glyphs 101, DeviceCatalog 159 (plus a twin if needed).
  - The C parts of Route (about 130), Together (about 100), Wired (about 50), Delay (about 40), Charge (about 110), Audiophile (about 60).

**Golden test reference for the port:**
- together 149, volume 169 (Volume about 34, Route about 39, Keys about 16; Polar 44 and Steps 7 stay in JS), wired 83, delay 70, wear 68, batterySessions 56 plus historyDisk 11, reportFile 54, diagnostics 108, connectRules 42, battery 37, wiredfilter 35, audiophile 28, member 29, disconnectPhrase 17, reportLeaks 17.
- About 970 static checks touch modules that are moving, in whole or in part.
- Thin coverage: DeviceCatalog has only 5 checks, and Endurance only about 2.

## 3. Questions for the owner

1. Should the three unwired files (BatterySessions, ConnectRules, ReportFile) be ported to Rust, wired up first, or deleted?
2. Ghost.js stays in JS, but it needs `Habits.choose`/`bestFirst` and `Together.refusal` synchronously. Keep Habits and the refusal logic in JS, or have the daemon push a ready-made `proposal`?
3. Drag-time eligibility: is "daemon pushes a per-output `{connected, sink, profile}` map, JS keeps the 40-line combination check" acceptable?
4. Who writes the PipeWire volume? Today it is QML through `node.audio.volume` (Route.writeLevel, during the gesture). Does that stay in QML, or move to the daemon, with possible slider lag over the process boundary?
5. IPC answers that are synchronous today (`together*`, `wiredDelay`, `disconnectAfter`): answer from a cached copy, keep the validation in JS, or switch to "accepted, then ask the status"?
6. Is the daemon allowed to take over MPRIS (needed for Wear) and BlueZ `Disconnect` (DisconnectPhrase), or does Quickshell's `Mpris` / `Bluetooth` stay the source?
7. Does the daemon need the device kind (Endurance, ANC family)? If so, should QML push `kind` (it applies the user's `glyphOverrides`), or should DeviceCatalog be duplicated in Rust?
8. UI JS files on neither list (Guide, Hidden, Text, Palette, MemberGlyph, WiredSign, Radio, Glyphs, Gauge, Sun, Perspective, BeamMotion, etc.): confirm they all stay in JS.
9. Should Member.key, Habits.tag, the ConnectRules key and BatterySessions.sha256 get shared golden vectors (a JSON fixture read by both the gjs and the Rust tests)?
10. Keys.js only builds `dms keybinds` command lines. Is moving it to Rust worth it, or does it stay in JS since it is shell-out logic anyway?

## Files read (main ones)

- ~/.config/dms/plugins/orbitBluetooth/components/volume/Route.js
- ~/.config/dms/plugins/orbitBluetooth/components/volume/Audiophile.js
- ~/.config/dms/plugins/orbitBluetooth/components/volume/AudioRoute.qml
- ~/.config/dms/plugins/orbitBluetooth/components/volume/VolumeTick.qml
- ~/.config/dms/plugins/orbitBluetooth/components/together/Together.js
- ~/.config/dms/plugins/orbitBluetooth/components/together/Choice.js
- ~/.config/dms/plugins/orbitBluetooth/components/together/TogetherSession.qml
- ~/.config/dms/plugins/orbitBluetooth/components/scene/OrbitTogether.qml
- ~/.config/dms/plugins/orbitBluetooth/components/scene/OrbitDrag.qml
- ~/.config/dms/plugins/orbitBluetooth/components/centre/OrbitGhost.qml
- ~/.config/dms/plugins/orbitBluetooth/components/common/OrbitIpc.qml
- ~/.config/dms/plugins/orbitBluetooth/components/device/BodyState.qml
- ~/.config/dms/plugins/orbitBluetooth/components/scene/OrbitDaemonData.qml
- ~/.config/dms/plugins/orbitBluetooth/components/battery/BatteryHistoryStore.qml
- ~/.config/dms/plugins/orbitBluetooth/components/rules/ConnectRulesRunner.qml
- ~/.config/dms/plugins/orbitBluetooth/components/delay/DisconnectDelays.qml
- ~/.config/dms/plugins/orbitBluetooth/tests/lib.js