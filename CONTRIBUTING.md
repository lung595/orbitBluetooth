# Contributing

Everything needed to work on Orbit Bluetooth or take over the project.

## Contents

- [Development setup](#development-setup)
- [Architecture](#architecture)
- [Project layout](#project-layout)
- [Tests](#tests)
- [Screenshots, shaders and sounds](#screenshots-shaders-and-sounds)
- [Performance rules](#performance-rules)
- [Conventions](#conventions)
- [Releasing a version](#releasing-a-version)

## Development setup

1. Clone the repository into the DMS plugin folder and enable it in **Settings → Plugins**:

   ```sh
   git clone https://github.com/lung595/orbitBluetooth ~/.config/DankMaterialShell/plugins/orbitBluetooth
   ```

2. Add at least one widget (Control Center, bar or desktop) to see your changes.
3. DMS reloads QML on save, but Qt keeps `components/` and `.js` files cached in the running shell: **run `dms restart`** after changing them.
4. Set `ORBIT_ANC_DEBUG=1` in the shell's environment to see the noise-control packets on stderr.

Tools: `gjs` (JS tests), Python 3 (helper and its tests), `ffmpeg` (GIFs), Qt 6 `qsb` (shaders).

## Architecture

`plugin.json` declares a **composite** plugin with three components and a settings page:

| Component | File | Role |
| --- | --- | --- |
| Daemon | `OrbitBluetoothDaemon.qml` | One instance, shared by every surface. BlueZ exposes no connection time, charging state or discharge rate, so it records them: connection times, battery log, UPower bridge |
| Widget | `OrbitBluetoothWidget.qml` | Bar pill, bar popout and Control Center tile |
| Desktop | `OrbitBluetoothDesktop.qml` | Desktop widget, frozen until the pointer is over it |
| Settings | `OrbitBluetoothSettings.qml` | Settings page |

`components/` has one folder per feature: `scene/`, `device/`, `card/`, `volume/`, `together/`, `centre/`, `radio/`, `pairing/`, `noise/`, `wear/`, `settings/` and `common/`. A file imports its neighbours directly and another feature's folder by path (`import "../card"`).

Every surface shows the same scene, `components/scene/OrbitScene.qml`. It only holds the state the parts share and wires them; each role has its own file, and the parts reach each other through the scene's functions (`scene.hideBody(b)`, `scene.ancSend(...)`), never through one another. The drag (`OrbitDrag`; the invitation to listen together, `OrbitInvite` with its maths in `Invite.js`, is created only while a device that could join is carried), hiding in the black hole (`OrbitHidden`), focus, rename and Escape (`OrbitFocus`), noise control (`OrbitAnc`), the daemon's data and clock (`OrbitDaemonData`) and the detail card's measures (`FocusLayout`) are each a short file; they open the cards (`card/FocusCard.qml`, `card/HiddenCard.qml`, `scene/OrbitMenu.qml`). `scene/OrbitPhysics.qml` moves every device (`device/DeviceBody.qml`) in one step per frame, with the maths in `scene/Physics.js` (pure, tested). What floats above the world (`pairing/OfferCard.qml`, `scene/ScanChip.qml`, `scene/AdapterNotice.qml`, the hint and the note) is grouped by `scene/OrbitChrome.qml`.

Logic that can be tested lives in **pure `.js` files** with no QML: `card/Charge.js` (charge analysis), `card/Endurance.js` (rated battery life), `card/CardStatus.js` (the detail card's wording), `scene/Physics.js` (springs, slots, clearances), `scene/Invite.js` (the invitation's halos, thread and light dots), `noise/Anc.js` (noise-control decisions), `noise/AncSnapshot.js` (merging a headset's reports into one snapshot), `wear/Wear.js` (what a wearing status means, which players to pause and which to resume, what `wearStatus` says), `volume/Polar.js` (the scope's geometry and sound picture), `volume/Route.js`, `volume/Steps.js`, `volume/Keys.js` and `volume/Audiophile.js`, `volume/AudioGraph.js` and `volume/Codecs.js` (volumes and what plays), `radio/Radio.js` (which outputs share the adapter's radio, which pair was told about), `together/Together.js` (who may listen together, where the sound is taken from, the command of each copy and what to start or stop, one keyed `diff`), `common/Address.js` (the shapes of a Bluetooth address and of its BlueZ path, checked before any command), `device/Earbuds.js`, `device/DeviceCatalog.js` and `device/Glyphs.js` (icons).

**The volume scope** (detail card, pop-up, Dank Island) runs one `cava` and computes one picture for every screen that shows it: `volume/TwoLevels.qml` holds an output's two levels, its `ScopeFeed.qml` (cava, only while someone looks) and its `ScopeModel.qml` (points, rays or waves, moved by cava's frames, fading alone, then stopped). `PolarScope.qml` keeps the geometry, eases the levels and holds the picture; `PolarArcs.qml` draws the half circles, `PolarMoons.qml` the knobs, `PolarGestures.qml` takes the drag, wheel and mute click, and `PolarVisual.qml` only paints the shared picture at its own size. While outputs listen together, `Members.js` and `MemberColors.js` (pure, tested by `tests/members.test.js`) give the arcs' levels, the cloud's sectors and the colors (primary, secondary, tertiary in turn, turned apart when two look alike); `MemberPalette.qml` hands them to the scope and to the strip so an output has one color everywhere, and `PolarLegend.qml` writes each arc's name and level (spots from `Polar.legendSpot`) when there are three or more.

**Listen together** (`components/together/`) is the daemon's, reached through `AudioRoute.together`. `Together.js` (pure, tested by `tests/together.test.js`) decides; `TogetherSession.qml` holds the members (2 to 4), the delays and the plan, and keeps a session alive through suspends and hand-overs (a member leaves only on a BlueZ disconnection or when asked); `TogetherLink.qml` runs one `Process` per copy through an `Instantiator`, each `pw-loopback` started by `Route.loopbackArgs` (data only as positional parameters, so it dies with the shell). Both ends of a copy are `node.passive` and `node.dont-fallback` and no stream is ever held toward a member's output (D279). The scene side is `scene/OrbitTogether.qml` (the drop, the notes, Leave and Stop in `OrbitMenu.qml`); the IPC is in `common/OrbitIpc.qml`. A change to the copies must keep: no BlueZ call, no write to DMS or WirePlumber, nothing running at rest, and the level written to **all** members' filters together (`AudioRoute.writeLevel`). `tests/qml/togetherSession.test.qml` runs a session against the mock `Process` (`scripts/preview/imports/Quickshell/Io/ProcessLog.qml` records every start and stop).

**Wired outputs** (D298, `components/together/`). A member is one validated token (`Member.js`: a Bluetooth address, or the node name of an ALSA output); a wired output is told from a Bluetooth one by `Member.isWired`, never by its name. `Wired.js` (pure, tested by `tests/wired.test.js`) reads the plugged outputs from `pactl --format=json list sinks` (`command`, `parse`) or from PipeWire's own nodes (`fromNodes`, no process), tells the kind of an output (`kindOf`, `kindOfNode`: usb, hdmi, analog, other), its Material Symbol (`iconOf`) and what the command line says of it (`describe`). `WiredWatch.qml` runs that one fixed command on demand (`active`; `ready` tells "nothing plugged in" from "not read yet") and is dropped when unused. `Delay.js` works the automatic wait out (only a wired copy ever waits; `latenciesOf`) and reads and says the user's nudge (`fineText`, `fineFrom`, `FINE_STEP_MS`, `cleanFine`); `MemberLatency.qml` reads each member's latency from PipeWire's graph; `components/settings/FineDelayRow.qml` is the slider (`tests/qml/fineDelayRow.test.qml`). `common/Text.js` makes one clean line (40 characters, no control or invisible character) of any name shown in a note, an IPC answer or `hidden` (`tests/text.test.js`). `common/Guide.js`: `wiredNote` is the wired wording of `togetherNote(why, name, member)` and the member token picks it; the notes' anchors must exist in `docs/GUIDE.md` (`tests/common.test.js` checks it). `TogetherSession` keeps the name of a wired member while it is one, so the note that says it was unplugged can still name it; `volume/TwoLevels.qml` draws a wired member with `Wired.iconOf(Wired.kindOfNode(node))` and names it by `together.nameOf` (`tests/qml/twoLevelsWired.test.qml`, `tests/qml/togetherNames.test.qml`).

**The group chooser** (the right-click menu's *Create a group…*). One role per file: `together/Choice.js` is the pure logic (`labels`, `build`: the rows of the two sections, what is ticked, locked or refused and why; `toggle`; `outcome`: what the button does), tested by `tests/choice.test.js`; `scene/GroupChooser.qml` is display and wiring only, created by `OrbitMenu`'s `Loader` when the entry is chosen and gone with it, so its one `pactl` read (`WiredWatch`) and its 500 ms fallback timer exist only while it is open, and `GroupRow.qml` is one row; `scene/OrbitTogether.qml` is the scene's side (`members`, `memberCheck`, `canGroup`, `refuse`, `groupFrom`) while the session still decides (`TogetherSession.memberCheck`, `start`, `add`). A refusal never goes silent: a new reason is appended at the **end** of `Guide.js` and gets a line in the guide. `tests/qml/groupChooser.test.qml` drives the whole scene with a made-up `pactl` listing; the preview mock `FakeRoute.qml` has the knobs `wired`, `silent`, `inCall`, `refusal` and `memberCheck`, `start`, `add`.

**The ghost group** (`together/Ghost.js`, `centre/OrbitGhost.qml`, `centre/GhostGroup.qml`). `Ghost.js` is the pure part (who is proposed, the order-independent key of a proposal, the bounded list of refusals, the signature that tells when the plugged outputs must be read again), tested by `tests/ghost.test.js`. `OrbitGhost.qml` is the state: it asks `TogetherSession.check` for every candidate, owns no timer (the physics step calls `advance(dt)` and hands it its ring slot through `place()`) and gates `WiredWatch`, so the plugged outputs are read only while the ghost can appear and the sound goes to Bluetooth. `GhostGroup.qml` only draws and forwards clicks, and `OrbitWorld` loads it on demand (a `Loader` active only while there is something to show). The refusals live in `TogetherSession.declined` (daemon level, memory only). `tests/qml/ghostGroup.test.qml` runs the controller on a real session and the whole scene with real mouse events, each rule with its counter-proof; a QML test waits for the scene's own `settled` rather than a fixed delay, because offscreen the loop runs about twice as slowly as real time.

**Learned groups** (`together/Habits.js`, `together/HabitLog.qml`, `settings/HabitsRow.qml`). `Habits.js` is the pure memory of what the user listens to: the hashes of a group's outputs (its own seed), the uses, their fading (half-life of 30 days) and which learned group fits (`choose`, `bestFirst`, `reaches`); every cap is a named constant (8 groups, 999 uses, a minute). `HabitLog.qml` records a use from the session's members and the time of each change, with no timer; `HabitsRow.qml` is the *Learn my groups* switch and the *Forget what Orbit learned* button (one `GuideLink` each). `Ghost.proposal` reads the memory and ignores hidden outputs. `togetherHabits` sits in Orbit's own plugin settings, so the uninstall sweep, which deletes the whole plugin entry, takes it away (checked by the Python sweep test). Tests: `tests/habits.test.js`, `tests/ghost.test.js`, `tests/qml/habitLog.test.qml`, `tests/qml/ghostGroup.test.qml`.

**Hiding devices** (`common/Hidden.js`). One store for what is hidden, Bluetooth devices and wired outputs alike (`isHidden`, `set`, `refusal`, `entries`, `MAX` = 64): the keys are the member tokens `Member.clean` validates, and `Prefs`, the bar widget, the black hole and the ghost all read it, so the rule lives once. `together/Choice.js` holds the group chooser's *Hidden* section (its rows, what the eye and <kbd>H</kbd> do); `scene/GroupChooser.qml` and `GroupRow.qml` draw the eye, the folded section and the chip that follows a dragged row. `Perspective.leanAt(scene, holeY, profile)` gives the black hole its size with depth: it reads only the scene's `cy`, `rx` and `ry`, never `centre.flat`, which copies `holeHorizon` and would make a binding loop. A member of the group is never hidden (`Guide.togetherNote("in-group")`, and `hidden-full` when the store is full). Tests: `tests/hidden.test.js`, `tests/choice.test.js`, `tests/perspective.test.js`, `tests/qml/hideMenu.test.qml`.

**The shared-radio note** (`components/radio/`) tells, once per pair of outputs and per session, that two Bluetooth outputs playing at once share one radio (D293, P170). `Radio.js` (pure, tested by `tests/radio.test.js`) names the outputs fed sound, the pair, and whether to say it now; `RadioWatch.qml` reads PipeWire's link groups and exists only while two outputs of the adapter do; `scene/OrbitRadio.qml` creates it on demand and calls `scene.explain(Guide.radioNote())` while the orbit is open. It stores nothing and changes no codec, quality or setting: lowering a device's quality to make two fit is a rejected design (D293), keep it that way. `tests/qml/radio.test.qml` runs it against the mock PipeWire (`scripts/preview/imports/Quickshell/Services/Pipewire/Pipewire.qml`: `extraSinks`, `links`).

**The listening source at the center** (`components/centre/`) is the scene's. `Centre.js` (pure, tested by `tests/centre.test.js`) holds every size, place and duration: the group's disc sizes (the source as big as the host's core), the tilted orbit of the copies, the parallax, the discs of the row of icons (`glyphDisc`, `glyphSpacing`, `glyphsOffset`) and the pulse along a beam. `Sun.js` (pure, tested by `tests/sun.test.js`) is the solar system: the sun's path, its size and depth, the view that the devices around it are placed in, and the order the host is drawn in; `Physics.js` functions take the scene's geometry, so `OrbitCentre.sunGeometry()` and `geometryOf(body)` hand them the sun's view (the scene itself when no group has the center). `MasterVolume.js` (pure) keeps the gaps when the general level moves. `OrbitCentre.qml` is the state (who is in, the voyage, the stage, the beams' clock) and answers what the bodies ask (`target`, `size`, `holds`); it has **no timer**: `OrbitPhysics.step` calls its `advance(dt, driven)`, so the trip rides the loop that already stops when nobody sees the scene (never start a timer or animation there: the scene settles, and `tests/qml/centreLoop.test.qml` fails if it does not). `CentreVolume.qml` is the levels, `CentreWatch.qml` (loaded only while someone sees the group move) reads PipeWire's links, and `CentreBeams.qml`, `CentreRing.qml` (the gauge), `CentreLabel.qml` (the icons under the group), `LevelArc.qml` and `MemberLevel.qml` are the parts, each loaded only while a group exists. The wheel is `volume/NotchWheel.qml`, shared with the card. `tests/qml/centre.test.qml` runs `OrbitCentre` against a made-up scene (the counter-proofs: the beams' clock, the PipeWire watch, the snap with Reduce motion).

**The profile view** (`components/centre/Perspective.js`, pure, tested by `tests/perspective.test.js`) is how the scene looks while a group has the center: the camera sits 15° above the plane of the orbits (`PITCH`, orbits flat at `FLAT` ≈ 0.268) and a body's size is 1 / its distance (`size`), its darkness grows with distance (`haze`) and it leans a little with its height (`lean`; a belt body without an orbit takes a depth from its height on screen, `depthAt`). `OrbitCentre.profile` is how far the scene has gone into it (`presence`, 0 with no group) and `OrbitCentre.flat` is the geometry then, so every reader of positions takes a geometry and none reads the scene. There are two views (`Centre.js`): this computer's (`stage = 1`; the group is the host ring's planet of index 0, `Centre.groupAt`, which keeps its slot while it has the middle so the ring does not reshuffle) and the group's (`stage = 0`; the host's system sits behind on the sun's path, `Sun.js`). The draw order is the one of D299: the host's core at `100 + y`, the group at `100 + y + LIFT` once `away > 0.5` (`Sun.groupZ`), its members at `groupZ + depth`, the beams at `groupZ − 2` and the ring at `groupZ − 0.01`; never lower the host under the fixed layers. `Physics.hitDiameter` is the click zone (28 px at least) that `BodyPointer` and `OrbitWorld.bodyAt` share, and `Physics.dropRadius` the drop zone (twice the disc, 60 px at least). **The depth of field** (`scene/Depth.js`, pure, tested by `tests/depth.test.js`) is two parts: `FrozenBlur.qml` renders a blurred, darkened copy of a part of the sky **once** into a texture and keeps it (no effect redraws between two retakes), and `DecorDepth.qml` fades that copy in with the camera's progress and switches the live source off in memory while the copy is whole; outside a group neither exists. `scripts/preview/depth-bench.sh` measures it. Never start an animation there: the fade is a binding on the value the scene's loop already moves.

**The volume gauge** (`centre/Gauge.js`, `centre/LevelGauge.qml`, `centre/CentreRing.qml`). `Gauge.js` is the whole geometry in one pure file (start 135°, sweep 270°, angle, point, length, turn, hit zone, the band's SVG outline, the marks), and `MasterVolume.fromPointer` uses it, so the drawing and the pointer cannot disagree. `LevelGauge.qml` draws the level as a fill and not a stroke (a stroke takes no gradient in Qt Quick Shapes), with a static glow at its end and no animation; `CentreRing.qml` places it on the source disc **as drawn** (`centre.bodyOf`, or `centre.spotOf` for a wired source), never on where the group is meant to be, which leads the disc while the camera travels. The hit zone is the band and its two ends, never the gap, which belongs to the icons. `LevelArc.qml` now only serves `MemberLevel.qml`. Tests: `tests/gauge.test.js`, `tests/qml/centreRing.test.qml`, `tests/qml/ringAnchor.test.qml` (samples every 16 ms and fails with the old anchor).

**Group icons** (`centre/GroupGlyphs.qml`). The row of overlapping discs that says a group, with no name anywhere: `CentreLabel.qml` places it under the group (above it when the group is on the far side of the host's ring in this computer's view) and `GhostGroup.qml` under the ghost; the discs' size and overlap come from `Centre.js` (pure). The names are in a tip loaded only while the pointer is on it. Tests: `tests/centre.test.js`, `tests/qml/groupGlyphs.test.qml`.

**Battery tones and copies over the source.** `device/Battery.js` (pure): the battery tones (`tone(level, charging)`, thresholds `OK_FROM`, `LOW_FROM`, `CRITICAL_MAX`); `BodyArcs.qml` maps a tone to a `NightColors` color, and `Charge.js`'s ramp reuses `CRITICAL_MAX`. `Centre.js`: `bodyZ` (copies over the source, `COPY_LIFT`), `solidity` (how whole a copy is: it falls to a dashed outline behind the source, `BEHIND_SPAN`), `inkOf` (how soft its picture is then, `BEHIND_INK`) and `sizes` (the copies' orbit, `ORBIT_SPREAD` times a tight ring). `centre/BehindOutline.qml` is the outline (a `Shape` that `DeviceBody` and `WiredBody` load for a copy only, laid out once and only faded by `solid`), and `centre/CentreOrbit.qml` the copies' trajectory: two instances that `OrbitWorld` loads while a group has the center, the far half under the source and the near half over it but under every copy (a copy is at least 0.25 over the source's order, so the line passes under it). Both are drawn once and only carried, scaled or faded, so they add no timer and no repaint; `NightColors.behindInk` and `memberInk(solid)` give their colors. Tests: `tests/battery.test.js`, `tests/centre.test.js`, `tests/qml/copyAbove.test.qml`, `tests/qml/orbitTrace.test.qml`.

**The sky's glow and veil** (`scene/Atmosphere.qml`): a soft, static, elliptical glow or veil of the sky's own color (one `Vignette`, drawn once, only moved with the group, never animated). `OrbitBackdrop` uses it for the glow behind a group on a solid sky and `OrbitWorld` for the veil between the host's system and the group. Every threshold lives in `Depth.js` and is tested by `tests/depth.test.js` and `tests/qml/skyDepth.test.qml`; a veil on the glass must fall to zero **before** the edge of its clip.

**Wired members of the group** (`components/centre/`). `WiredSign.js` (pure, tested by `tests/wiredsign.test.js`) holds the shape (`CORNER`, the `inside` hit test), the cable (`TIGHTEN`, `SLACK`, `drop`, `along`) and `reconcile`, which rows of the model to add or remove for the group's members; `device/Glyphs.js` has the four pictos (`Glyphs.wired(kind)`, the kind from `together/Wired.js`). `Centre.place` is the one placement rule of a member (position, depth, size): `OrbitCentre.target` uses it for Bluetooth bodies, which the physics moves with springs, and `OrbitCentre.spotOf(address)` for wired squares, which it does not: they are placed from the group's clock on every read, with no spring, so they can never keep the scene from settling. `OrbitCentre.wired` is a `ListModel` kept in step with the members (`_syncWired`) so that the delegates, and their one-shot animations, survive every other change of the group. `WiredMembers.qml` is a `Repeater` over it (siblings of the device bodies, so they sort with them; `list()` and `at(x, y)` give the scene's hit tests and drops their bodies through `OrbitWorld.bodyList()` and `bodyAt()`); `WiredBody.qml` is the square, `WiredPointer.qml` takes the click (menu) and the wheel (`CentreVolume.turn`), `WiredLabel.qml` writes the name on hover and `WiredCable.qml` draws the cable in `CentreBeams` (ends from `OrbitCentre.pointOf`). The cable's tightening (one non-repeating 0.4 s `NumberAnimation`) and the brief `PopAnimation` are the only animations; never add a timer or a looping one there: `tests/qml/wiredMembers.test.qml` fails if the scene does not settle with a wired member, with or without *Reduce motion*. Colors come from `NightColors.connected*`. The mock `FakeRoute` has made-up wired outputs (`usbDac`, `screen`, `jack`) and `scripts/preview/wired.qml` renders them offscreen.

**Noise control** is the only part outside QML: QML cannot open a Bluetooth socket, so `components/noise/AncService.qml` runs `anc/orbit_anc.py`, which speaks each vendor protocol (`anc/protocols/`, one module per brand) through a JSON session on stdin/stdout. `anc/sdp.py` finds the RFCOMM channel. The Sony protocol is split by role: `sony_frame.py` (framing and checksum), `sony.py` (the handshake and noise control), `sony_extras.py` (the wearing sensor and the length of a conversation, from SonyHeadphonesClient, MIT).

**Pause on removal** (`components/wear/`): `AncService` keeps one session open for a Sony headset that reports a wearing sensor (only while the setting is on); `WearPause.qml` follows the headsets whose snapshot says so, and one `WearHeadset.qml` per headset reads the status, asks `HeadsetStreams.qml` which applications play on it (PipeWire) and pauses or resumes the matching MPRIS players. All decisions are in `Wear.js`.

**New headphones pop-up**: `components/pairing/NewDeviceWatch.qml` (in the daemon) drives the pop-up and pairing, with `BackgroundScan.qml` (the opt-in short scan), `OfferQueue.qml` (what to offer next, snoozes; `Offer.js`, pure) and `DemoDevice.qml` (the made-up headset of the demo) and `PairingFlow.qml` (the pairing steps: pair, check, connect, time-out); `NewDeviceWindow.qml` is its layer-shell window and `PairingSheet.qml` the sheet itself (two skins, colours from `Palette.js`), which `scripts/preview/sheet.qml` renders offscreen with six test palettes, or records frame by frame. Before a new device is trusted, `ProfileCheck.qml` reads its Bluetooth profiles with `busctl` and `Guard.js` (pure, tested) decides: a non-input device that can also send key presses stays blocked until the user confirms. Never trust a device from its name alone.

**Guided, never blocked**: `components/common/Guide.js` (pure, tested) builds the guide links and the short notes (`connectNote`); `scene/OrbitNote.qml` shows them at the bottom of the sky and `common/GuideLink.qml` is the GitHub mark (drawn by `common/GitHubMark.qml`) that opens a guide section on click. A new refusal gets a note and an anchor that exists in `docs/GUIDE.md` (the tests check it). Every new Quickshell import or service used by a component needs its mock in `scripts/preview/imports/`, or the previews break; the made-up devices and state of the screenshots live in `scripts/preview/mock/`.

**Uninstalling leaves nothing** (value 12): `components/common/UninstallSweep.qml` (in the daemon) reads `uninstall/orbit_uninstall.py` when Orbit loads; when Orbit is unloaded and its `plugin.json` is gone, it starts that script detached, from memory (`python3 -c`), since the folder no longer exists. The script waits 4 s, checks again (an update may re-clone the folder) and only then edits the shell's JSON files, which DMS watches. Never create QML objects in `Component.onDestruction`: it crashed the shell.

**Real device pictures** (opt-in) is the only network use: `components/common/PictureService.qml` runs `pictures/orbit_pictures.py` (Wikimedia Commons, then Sketchfab; standard library only), and `components/common/Pictures.js` decides which names may be sent. Keep the list of hosts in sync between the helper header, the settings description, the README and the GUIDE.

Settings are read through `components/common/Prefs.qml`, a reactive view shared by every surface.

## Project layout

```
orbitBluetooth/
├── plugin.json                  # manifest: id, version, components, permissions
├── OrbitBluetoothDaemon.qml     # shared bookkeeping (see Architecture)
├── OrbitBluetoothWidget.qml     # Control Center tile, bar pill and popout
├── OrbitBluetoothDesktop.qml    # desktop widget
├── OrbitBluetoothSettings.qml   # settings page: the chip tabs, one file each in components/settings/
├── components/
│   ├── settings/                # one tab per file (Look, Sound, Orbit, Headphones, Desktop, Scanning) and their shared rows (`FineDelayRow.qml` is the Wired delay slider, `HabitsRow.qml` the learned-groups switch and button)
│   ├── scene/                   # the sky every surface shows
│   │   ├── OrbitScene.qml       # the scene: composition and wiring of the files below
│   │   ├── Orbit.js, OrbitDevices.qml  # which devices the orbit shows (Orbit.js pure, tested), one model entry per body
│   │   ├── OrbitConnections.qml, OrbitDiscovery.qml, OrbitOffer.qml  # connection flow, scan only while viewed, offer to connect
│   │   ├── OrbitDrag.qml, OrbitHidden.qml, OrbitFocus.qml  # the drag gestures, hiding in the black hole, focus + rename + Escape
│   │   ├── OrbitAnc.qml, OrbitDaemonData.qml, FocusLayout.qml  # noise control, what the daemon publishes + its clock, the detail card's measures
│   │   ├── OrbitBackdrop.qml, OrbitWorld.qml, OrbitCore.qml, OrbitHint.qml  # sky, orbits and bodies, host core, drag hint
│   │   ├── OrbitPhysics.qml, Physics.js  # one motion step for every body (Physics.js pure, tested)
│   │   ├── Cover.js             # is the desktop hidden behind windows? (pure, tested)
│   │   ├── OrbitChrome.qml, ScanChip.qml, AdapterNotice.qml, OrbitNote.qml  # what floats above the world: scan chip, Bluetooth off, notes
│   │   ├── OrbitMenu.qml        # the right-click menu (with Leave / Stop together)
│   │   ├── OrbitTogether.qml    # Listen together in the scene: the drop, the notes, leave and stop
│   │   ├── GroupChooser.qml, GroupRow.qml  # the *Create a group…* checklist (created by the menu only while it is open) and its rows
│   │   ├── BlackHole.qml, RingWave.qml   # the "Hidden" black hole (two shaders), the connected ring's wave
│   │   ├── Depth.js, Atmosphere.qml  # the depth of field's thresholds (pure, tested) and the sky's static glow or veil
│   │   └── Starfield.qml, Vignette.qml, NightColors.qml
│   ├── device/                  # one orbiting device
│   │   ├── DeviceBody.qml, BodyFace.qml, BodyPointer.qml, QuickDisconnect.qml  # body (state, motion), its look, its mouse, its close button
│   │   ├── ConnectingFx.qml, LockRing.qml, EnergyBeam.qml, LabelGlow.qml  # connection comet and rings, lock ring, charging beam (shaders/beam.frag), label glow
│   │   ├── BodyTether.qml, ChargeBeam.qml, BodyArcs.qml, BodyLabel.qml, Battery.js  # tether to the core, charge beam, rings (noise control, battery), caption, the battery tones (pure, tested)
│   │   ├── DeviceGlyph.qml, DeviceCatalog.js, Glyphs.js, PopAnimation.qml   # device icons (Glyphs.js also draws the wired pictos), the brief pop of a body that says "here"
│   │   └── EarbudsTrio.qml, EarbudArt.qml, Earbuds.js     # case + buds mini orbit
│   ├── card/                    # the detail and hidden-devices cards
│   │   ├── FocusCard.qml, PlanetControl.qml  # detail card (layout of its sections); focused glyph: click to mute, wheel for the volume
│   │   ├── CardActions.qml, CardButton.qml, NameBox.qml  # corner buttons (back, look, connect, hide, forget), their round button, the name and its rename
│   │   ├── VolumeSection.qml, FoldButton.qml, GlyphPicker.qml  # the two volumes (strip or scope) and the button that folds them, the glyph grid
│   │   ├── BatteryCard.qml, CardBattery.qml, StatTiles.qml  # gauge, chart and READY AT / SPEED / HEALTH tiles; the card's own wiring of them
│   │   ├── Charge.js, Endurance.js, CardStatus.js  # battery analysis, rated life, the card's wording (pure, tested)
│   │   └── HiddenCard.qml, PaperColors.qml   # hidden devices; light-theme colors
│   ├── volume/                  # the two volumes and the scope
│   │   ├── TwoLevels.qml        # an output's two volumes, its cava and its picture (base of CardVolume, VolumeOverlay)
│   │   ├── CardVolume.qml, Volume.js         # the detail card's two volumes and tick (Volume.js pure, tested)
│   │   ├── VolumeOverlay.qml, VolumePopup.qml, IslandFace.qml  # volume pop-up per screen, its face inside Dank Island
│   │   ├── DmsOsdOff.qml        # holds DMS's own volume OSD off, in memory, while the pop-up is on (D273)
│   │   ├── ClickAwayHold.qml    # hides the island's click-away layer while the face is up; the island's spring stays DMS's
│   │   ├── AudioFacts.qml, FactsLine.qml, Audiophile.js  # what plays: `pactl` read on demand, the line with its info button, parsing (pure, tested)
│   │   ├── AudioGraph.qml, AudioGraph.js, Codecs.js  # `pw-dump` / `pw-top` read only while looked at and wanted; their parsing and the codec / bit rate tables (pure, tested)
│   │   ├── VolumeStrip.qml      # menus: the two volumes folded into a thin line, unfolds on click
│   │   ├── ScopeScreen.qml      # the dark scope screen shared by card, pop-up and island
│   │   ├── PolarScope.qml, PolarVisual.qml, Polar.js   # geometry and easing, the painted picture (Polar.js pure, tested)
│   │   ├── PolarArcs.qml, PolarMoons.qml, PolarGestures.qml  # half circles, knobs, drag / wheel / mute
│   │   ├── PolarGrid.qml, PolarReadouts.qml, PolarLegend.qml  # the scope's screen (grid), icons and numbers, the names of three or four arcs
│   │   ├── Members.js, MemberColors.js, MemberPalette.qml  # outputs listening together: levels, cloud sectors, theme colors (pure, tested)
│   │   ├── ScopeFeed.qml, ScopeModel.qml     # live stereo bands from cava; the picture they move, once for every screen
│   │   ├── AudioRoute.qml, RouteDevice.qml, Route.js   # the two levels of each output: PC filter, absolute volume, IPC
│   │   └── VolumeKeys.qml, Keys.js, Steps.js # volume keys through `dms keybinds`, smart steps (pure, tested)
│   ├── together/                # Listen together (D254, D277, D279, D298)
│   │   ├── Together.js          # who may join, where the sound comes from, the copies' commands (pure, tested)
│   │   ├── TogetherSession.qml  # the members, delays and plan of a session; survives suspend and hand-over
│   │   ├── TogetherLink.qml     # one pw-loopback per extra output, started and stopped by key
│   │   ├── Member.js, Wired.js, WiredWatch.qml  # who a member can be (a Bluetooth address or a wired output), the plugged wired outputs and their kinds (pure, tested), read on demand
│   │   ├── Delay.js, MemberLatency.qml          # the wait that lines wired outputs up with Bluetooth ones, and each member's latency
│   │   ├── Choice.js, Ghost.js  # what the group chooser lists and asks, the ghost group's rules (pure, tested)
│   │   └── Habits.js, HabitLog.qml  # what you listen to together, as hashes: the memory (pure, tested) and its log
│   ├── radio/                   # the shared-radio note (D293)
│   │   └── Radio.js, RadioWatch.qml
│   ├── centre/                  # the listening source at the center and the sun around it
│   │   ├── Centre.js, Sun.js, Perspective.js, MasterVolume.js, WiredSign.js   # sizes, places and durations; the sun's path, size and view; the profile view's maths; the general volume's gaps; the wired members' shape and cable (pure, tested)
│   │   ├── OrbitCentre.qml      # the state and the answers to the bodies, no timer of its own
│   │   ├── CentreVolume.qml, CentreWatch.qml, CentreBeams.qml, CentreRing.qml, CentreLabel.qml, LevelArc.qml, MemberLevel.qml  # levels, PipeWire watch, beams, the gauge, the icons under the group, a copy's own arc
│   │   ├── Gauge.js, LevelGauge.qml, GroupGlyphs.qml  # the gauge's geometry (pure, tested), its drawing, the row of member icons
│   │   ├── WiredMembers.qml, WiredBody.qml, WiredPointer.qml, WiredLabel.qml, WiredCable.qml  # the wired members: the rounded square, its mouse, its name, its cable
│   │   ├── BehindOutline.qml, CentreOrbit.qml  # a copy behind the source (its dashed outline) and the copies' trajectory (a light dashed ellipse, two halves)
│   │   └── OrbitGhost.qml, GhostGroup.qml  # the ghost group: its state (no timer), its drawing
│   ├── pairing/                 # new device pop-up and pairing offer
│   │   ├── NewDeviceWatch.qml, PairingFlow.qml, BackgroundScan.qml, OfferQueue.qml, DemoDevice.qml, Offer.js, Guard.js, ProfileCheck.qml  # pop-up, pairing steps, background scan, what to offer, demo, the input-device guard
│   │   ├── NewDeviceWindow.qml, PairingSheet.qml, Palette.js  # the window and the sheet (the card, its keys and its parts)
│   │   ├── PairingSkin.qml, PictureColor.qml, PairingMotion.qml  # the two skins' colours, the picture's colour, the sheet's clock and entrance
│   │   ├── PairingSky.qml, PairingPlanet.qml, PairingHeader.qml  # the scene behind the device, status and close button
│   │   ├── PairingStage.qml, PairingIdentity.qml, PairingMiddle.qml, PairingButton.qml, Light.qml  # device, name and subtitle, tiles/steps/quick actions, actions, round light
│   │   └── OfferCard.qml        # the scene's pairing offer
│   ├── noise/                   # noise control
│   │   └── AncService.qml, AncPanel.qml, ChatEnds.qml, Anc.js, AncSnapshot.js
│   ├── wear/                    # pause on removal (Sony)
│   │   └── WearPause.qml, WearHeadset.qml, HeadsetStreams.qml, Wear.js
│   └── common/                  # shared by every feature
│       ├── Prefs.qml            # settings, shared by every surface
│       ├── OrbitIpc.qml         # the `dms ipc call orbitBluetooth` commands, one call each on the owning service
│       ├── Address.js                                    # address forms and BlueZ device path, one definition (pure, tested)
│       ├── Hidden.js                                     # the one store of hidden devices, wired outputs included (pure, tested)
│       ├── Text.js                                       # one clean line from a device or output name, for every note and answer (pure, tested)
│       ├── Guide.js, GuideLink.qml, GitHubMark.qml       # guide links and notes (value 10)
│       ├── PictureService.qml, Pictures.js               # real device pictures (opt-in)
│       └── SoundFx.qml, UninstallSweep.qml
├── anc/
│   ├── orbit_anc.py             # noise-control helper (JSON session)
│   ├── sdp.py                   # minimal SDP client (finds RFCOMM channels)
│   ├── protocols/               # one module per brand + shared checksums
│   └── tests/                   # unittest: frames, checksums, each brand
├── pictures/
│   ├── orbit_pictures.py        # picture lookup (Wikimedia Commons, Sketchfab)
│   └── tests/                   # unittest, no network
├── uninstall/
│   ├── orbit_uninstall.py       # erases what DMS keeps once Orbit is removed
│   └── tests/                   # unittest, on fake shell files
├── tests/qml/                   # pop-up scenario, polar scope, audio facts and audio graph, control sessions, pause on removal and Listen together tests, the group chooser, the ghost group and its learned groups, hiding from the menu, wired members and pulling them out, the gauge's anchor, the group icons, copies over the source and their trajectory, the wired delay row, stubs for Quickshell/DMS
├── tests/*.test.js, lib.js, run.sh  # gjs: one file per role (noise, wear, battery, card, device, pairing, common, volume, audiophile, audiograph, together, centre, sun, scene, perspective, depth, member, wired, wiredfilter, wiredsign, delay, text, choice, ghost, habits, hidden, gauge), the shared loader, the runner
├── shaders/                     # .frag sources, compiled .qsb, build.sh
├── scripts/
│   ├── gen_sounds.py            # synthesizes sounds/*.wav
│   └── preview/                 # offscreen renderer: shot.qml (modes), mock/ (devices, state, route, wallpaper), imports/ (mock services)
├── screenshots/                 # images used by the docs
├── sounds/
└── docs/GUIDE.md                # user guide
```

## Tests

```sh
(cd anc && python3 -m unittest discover -s tests -t .)   # noise-control protocols
(cd pictures && python3 -m unittest discover -s tests -t .)   # picture lookup, without network
(cd uninstall && python3 -m unittest discover -s tests -t .)  # uninstall sweep, on fake shell files
sh tests/qml/run.sh                                       # new-device pop-up scenario, polar scope, audio facts, control sessions, pause on removal, Listen together session, center, group chooser, ghost group and wired members (Qt 6); one test: sh tests/qml/run.sh centreLoop
sh tests/run.sh                                          # every pure .js module, one test file per role (or gjs tests/volume.test.js for one)
```

Run them all before every commit. A new headphone brand needs a module in `anc/protocols/` and tests in `anc/tests/`.

## Screenshots, shaders and sounds

```sh
scripts/preview/render.sh          # PNG screenshots (mock devices, no real data)
scripts/preview/record.sh          # all GIFs (needs ffmpeg)
scripts/preview/record.sh beam     # one of: beam, gauge, focus, connect
shaders/build.sh                   # recompile after editing shaders/*.frag (needs qsb)
python3 scripts/gen_sounds.py      # regenerate sounds/*.wav
```

The compiled `.qsb` files are committed, so users do not need `qsb`. The shader renders need the OpenGL backend, which `render.sh` sets.

## Performance rules

Orbit must cost nothing while nobody looks at it. Keep these rules when changing the code:

- **Never loop a QML animation** (`NumberAnimation` with `loops`, `Animator`, a running `FrameAnimation`). In Qt, any running animation makes *every* shell window (bars, wallpaper) redraw at the display rate. Use a plain `Timer` (30 Hz, 60 Hz while a comet turns or a card is open) and compute effects from one effects clock.
- **Display-synced frames only for gestures**, and only until the motion has calmed down.
- **Paint backgrounds once** (stars, nebulae, veil); effects only move fixed geometry.
- **Hidden means frozen**: the desktop orbit is asleep while windows fill its screen, even with *Ambient motion* on (`Cover.js`, pure, tested, reads niri's layout from DMS's `NiriService`).
- **Run nothing while hidden**: discovery, polling and the noise-control helper only run while a view is open (the exceptions are the new-device pop-up's 8 s background scan, with its battery and audio rules, and the one idle control connection that *Pause when you take the headset off* keeps for a Sony headset with a wearing sensor: no timer, the headset reports by itself); everything pauses while the session is locked or the monitors are off.
- **Load on demand**: the multimedia backend only when sounds are enabled.
- **Listen together holds nothing at rest**: the copies are passive, never fall back to another output and no stream, silence or keep-alive is ever opened toward a member (a multipoint headset must be free to hand over to a phone). Check in an isolated PipeWire server (a scratch `PIPEWIRE_RUNTIME_DIR`, never the live one): with nothing playing every member output, copy and filter must be `idle`; a non-passive copy keeps the outputs `running`. Kill the shell stand-in with `kill -9` and every copy and node must be gone within two seconds.
- **Honor DMS Reduce motion.**

Measure before and after a change: CPU of the whole shell, % of one core, each state for 10 s, same machine (240 Hz screen). DMS alone: 0.7 %.

| State | 1.4.1 | 1.4.0 | 1.3.2 |
| --- | --- | --- | --- |
| Idle (bar icon, view closed) | 0.5 | 0.7 | 0.5 |
| View open, left alone | 3.8 | 3.6 | 3.7 |
| View open while scanning | 5.2 | 10.1 | 8.0 |
| Desktop widget, *Ambient motion* on | 9.2 | 8.8 | 8.5 |

Short runs are noisy (about ±2 points while scanning).

## Conventions

- **Language**: code, comments, UI and docs in English.
- **Comments**: every file starts with a short comment saying what it is and why.
- **Privacy**: no telemetry, ever. No network access except the opt-in, off-by-default **Real device pictures** (model names only). Nothing written to disk except settings through DMS and that feature's pictures cache.
- **Settings**: every option works out of the box; descriptions stay one short line; options that cost battery are marked ⚡.
- **Docs**: user-facing changes go in `docs/GUIDE.md` (and the README if they change installation or the basics), plus an entry in `CHANGELOG.md`.

## Releasing a version

1. Bump `version` in `plugin.json` ([Semantic Versioning](https://semver.org/)).
2. Move the `Unreleased` entries of `CHANGELOG.md` under the new version and date.
3. Refresh screenshots if the look changed (`scripts/preview/`).
4. Run the tests, commit, then tag: `git tag v1.10.1 && git push --tags`.
