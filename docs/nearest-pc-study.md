# Nearest-PC filter: feasibility study

Status: slice 1 (NAK-12) wrote the study and the rule; slice 2 (NAK-110)
reads the signal and wires the rule into the pop-up (`Signal.js`,
`SignalRead.qml`, `OfferQueue.qml`). Thresholds are still unmeasured.

Goal: when several PCs run Orbit, only the PC nearest to a new pair of
headphones opens the pairing sheet. Every PC decides alone; nothing is
exchanged between PCs.

## Where the signal strength comes from

- **BlueZ `org.bluez.Device1.RSSI`** (`int16`, dBm) is the source. It is an
  optional property that BlueZ 5.87 declares on every device and sets only
  from advertising or inquiry reports, so it exists while the adapter
  discovers and is absent otherwise. Checked on this machine with discovery
  off: introspection lists `RSSI` and `TxPower`, reading `RSSI` on a paired
  device answers "No such property".
- **Quickshell 0.3.1 does not expose it.** `BluetoothDevice` has no
  `signalStrength` (its type list has `address`, `battery`, `bonded`,
  `connected`, `icon`, `name`, `paired`, `trusted`… and nothing about signal),
  which is why `Orbit.js` already treats the field as `undefined`.
- **Reading it ourselves** would be one D-Bus read per candidate device, only
  at the moment a candidate shows up (a `Process` with a command array such as
  `busctl get-property org.bluez <device path> org.bluez.Device1 RSSI` on the
  system bus, started on demand, stopped right after). That is slice 2; this slice only fixes the rule.

## What the plugin already provides

- `BackgroundScan.qml` runs a discovery of 8 s every `offerEvery` seconds, only
  when Bluetooth is on, the screen is awake, no Bluetooth audio plays and the
  battery allows it. It does not read signal strength.
- `OfferQueue.consider` already refuses a device when the adapter is not
  discovering ("only what discovery just found is in range"). This is the
  natural place for the wait of slice 2: it already runs at that moment, so no
  new timer is needed at rest (one single-shot `Timer` per waiting offer).
- **The wait alone suppresses nothing.** `connected` is this adapter's own
  link (`Offer.js`, `OfferQueue.qml`): a headset connected to PC A stays in PC
  B's BlueZ device list until `TemporaryTimeout` (30 s by default,
  `/etc/bluetooth/main.conf`), longer than the longest wait (6 s + 1.5 s), and
  the sheet only offers (the user acts on A). So B's wait usually ends first
  and B opens anyway. Only the signal floor keeps a far PC quiet, unless
  slice 2 re-checks at fire time (RSSI still present and fresh, device still
  advertising, or its Device1 object gone).
- The floor also hides the pop-up for a one-PC user whose headset reads below
  the floor, a change from today's behavior that slice 2 must decide (for
  example an option that is off by default).

## Not measured

- No real headset, no second PC, no second adapter was used: the values above
  are reasoned, not measured, and are tested only as arithmetic on fixtures.
- RSSI update rate and read cost during a real discovery: not measured. BlueZ
  emits `PropertiesChanged` only when the value moves, and on many adapters the
  inquiry reports a single value per response, so a read at the moment the
  device appears is expected to be enough (to confirm in slice 2).
- Spread between adapters of different sensitivity, and ties between two PCs
  at equal signal: not measured. A tie keeps both PCs offering, which is
  today's behavior; the first that pairs wins; whether the other's sheet then
  closes depends on the fire-time re-check below, since `connected` is only
  this adapter's own link.
- Whether a read of `RSSI` right after `PropertiesChanged: Discovering=true`
  is already filled: not measured.
- **Main open question for slice 2:** what is observable at fire time on the
  far PC when the headset is connected to another PC (RSSI cleared, device
  removed, or neither before `TemporaryTimeout`). Without a signal there, the
  delay only orders PCs that both see the device; it does not silence the
  farther one.

## Slice 2: what was built, what is still open

- One `busctl --json=short --timeout=2 get-property -- org.bluez <path> org.bluez.Device1
  RSSI` per read, started when a candidate appears and again when its wait
  ends; the process is gone right after, reads go one at a time. Checked on
  this machine: without discovery BlueZ answers "No such property" with exit
  code 1, which counts as no reading.
- At the end of the wait (`NearestFilter.recheck`): signal gone while the
  adapter still discovers means no sheet; once discovery has ended BlueZ
  clears every reading, so a missing one proves nothing and the sheet opens
  as today. Still unknown on real hardware: whether a headset connected to
  another PC keeps a reading on this adapter.
- Only the screen state feeds the rule so far; recent use is not known to
  Orbit and counts for nothing.
- Tests use a fake `busctl` on `PATH` (`tests/signal.test.js`) and a fake
  reader in the whole pop-up flow (`tests/qml/nearestWindow.test.qml`).
