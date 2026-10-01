# Orbit Bluetooth: working notes

Values of the project. They hold for every change; do not ask again.

- **Open source** (MIT). Nothing proprietary, nothing closed.
- **Total privacy, zero telemetry.** No network access, no analytics, no
  crash reports. Anything that would need the network is out of scope, with
  one exception decided by the owner: **Real device pictures**, opt-in and
  off by default, which looks up only the model name of paired devices on
  the hosts named in `pictures/orbit_pictures.py`, the settings page and the
  README. Never the Bluetooth address, never a personal name. Data stays in
  memory or in DMS's own plugin settings, never in a log file; the
  downloaded pictures live in `~/.cache/orbitBluetooth/pictures` and can be
  deleted from the settings.
- **Credit what inspired it.** When an idea, protocol or design comes from
  someone else's work, say so in the README **Credits** section and in the
  code comment next to it, and thank them. Protocols are reimplemented from
  public documentation, never copied.

Workflow:

- Update `README.md` when something is finished (features, settings,
  privacy, benchmark if relevant), and add it to the **Changelog**; take it
  off the **Roadmap** as soon as it ships. Bump `plugin.json` for a release.
- Tests: `(cd anc && python3 -m unittest discover -s tests -t .)` and
  `(cd pictures && python3 -m unittest discover -s tests -t .)` and
  `gjs tests/anc.test.js` when gjs is available.
- Code comments explain *why*, in English, like the surrounding code.
- Use `Theme` tokens (spacing, radius, surface colors) for chrome. The night
  sky is the only place with fixed colors, and they live in `NightColors`.
