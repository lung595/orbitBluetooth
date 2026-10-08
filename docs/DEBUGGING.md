# Debugging Orbit Bluetooth

For someone who has a problem and wants to tell the maintainer about it without giving anything personal away.

## Contents

- [What the report holds](#what-the-report-holds)
- [Getting your report](#getting-your-report)
- [Reading the journal yourself](#reading-the-journal-yourself)
- [The event codes](#the-event-codes)
- [Cases](#cases)

## What the report holds

An anonymous text you read before you paste it into a GitHub issue. Orbit never sends it anywhere: it stays on your machine until you decide to share it.

- **In it:** the time (UTC), the versions of Orbit, DMS, Quickshell, Qt and niri, the distribution, which surfaces are active, the settings that choose a behaviour, a few counts (devices, timers, helper programs running), the shell's CPU over one second, the last events Orbit recorded and the lines Orbit left in the DMS journal.
- **Never in it:** a device name, a Bluetooth or network address, a host name, your login, a path under your home folder, a token or any text you typed. Events are built from a fixed list of codes and words; whatever else reaches them is replaced by `?`, and every line is cleaned a second time before it is kept.
- **Not kept:** the events live in memory, at most 200, and vanish with the shell (a restart, a crash, a log out). Nothing is written to disk and nothing runs while nobody asks for a report.

The CPU figure is the **whole shell** (DMS and every plugin together) over one second, measured only when you ask for the report. The shell is one process, so Orbit's own share cannot be told apart from it.

## Getting your report

The report is built by `diagnostics/Report.js` and gathered by `ReportService.qml`, only when asked. Three ways to ask (see [Report a problem](GUIDE.md#report-a-problem)):

- **Settings → Orbit → Copy report**: about two seconds, then the report is on the clipboard (`wl-copy --sensitive` through standard input, so DMS's history does not keep it; DMS's own copy if `wl-copy` is missing, which the message then admits).
- **`dms ipc call orbitBluetooth diagnostics`**: the first call starts it, the same call two seconds later hands it over.
- **`sh scripts/diagnose.sh`**: both calls, plus the latest Quickshell crash folder with your login and home folder replaced.

Each ask logs `ORB-I030` with `via`. The journal lines below are also yours to copy by hand.

## Reading the journal yourself

Errors and warnings are written to the DMS journal with the tag `[orbit]`:

```sh
journalctl --user -u dms -n 300 --no-pager | grep '\[orbit\]'
```

Read the lines before you paste them: the shell's own messages can name folders under your home folder.

## The event codes

A code is `ORB-` followed by a level letter (`E` error, `W` warning, `I` info, `D` debug) and a number. Errors and warnings reach the journal; info and debug stay in memory. A code's number never changes meaning once released.

| Code | Level | Meaning | Fields |
|---|---|---|---|
| `ORB-E001` | error | A Bluetooth action (connect, disconnect, pair, trust, forget, scan, power) failed | `action`, `reason` |
| `ORB-E002` | error | Pairing failed | `reason` |
| `ORB-E003` | error | A helper program (`pw-loopback`, `pw-play`, `cava`, `wl-copy`, `dms`, `pactl`, `python`, `bluetoothctl`) stopped unexpectedly | `tool`, `code` (its exit status) |
| `ORB-E004` | error | The real device pictures lookup failed | `reason` |
| `ORB-E005` | error | Noise control (ANC) could not be changed | `reason` |
| `ORB-W010` | warning | No usable Bluetooth adapter | `state` |
| `ORB-W011` | warning | A helper program is missing | `tool` |
| `ORB-I020` | info | A surface (widget, desktop, daemon, settings, pop-up) was loaded | `surface` |
| `ORB-I021` | info | A surface was unloaded | `surface` |
| `ORB-I030` | info | A diagnostic report was requested | `via` |
| `ORB-D040` | debug | The scene changed state (hidden, visible, ambient) | `state`, `count` |

The words a field may hold are listed in `diagnostics/Codes.js`; a test fails when a code is missing from this table.

## Cases

### The widget disappears

Look for `ORB-W010` (no usable adapter) and `ORB-I021` (a surface was unloaded) in your report. An adapter that is off or missing hides the devices; see [Bluetooth is off](GUIDE.md#bluetooth-is-off).

### A device does not connect

`ORB-E001` with `action=connect` and its `reason` tells what BlueZ answered (`timeout`, `refused`, `blocked`, `not_found`). The steps are in [If it does not connect](GUIDE.md#if-it-does-not-connect).

### A helper program keeps stopping

`ORB-E003` names the program (`tool`) and its exit status (`code`); `ORB-W011` says it is not installed.

### The shell restarts or the bar freezes

The memory buffer is lost with the shell, so the report right after a restart is empty. Quickshell keeps its own crash folder under `~/.cache/quickshell/crashes/`; it contains paths with your login, so read it before sharing any of it. Orbit does not keep a trace on disk.
