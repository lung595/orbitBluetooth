# Orbit Bluetooth: working notes

Values of the project. They hold for every change; do not ask again.

- **Open source** (MIT). Nothing proprietary, nothing closed.
- **Total privacy, zero telemetry.** No network access, no analytics, no
  crash reports, no remote images or lookups. Anything that would need the
  network is out of scope. Data stays in memory or in DMS's own plugin
  settings, never in a log file.
- **Credit what inspired it.** When an idea, protocol or design comes from
  someone else's work, say so in the README **Credits** section and in the
  code comment next to it, and thank them. Protocols are reimplemented from
  public documentation, never copied.

Workflow:

- Update `README.md` when something is finished (features, settings,
  privacy, benchmark if relevant), and add it to the **Changelog**; take it
  off the **Roadmap** as soon as it ships. Bump `plugin.json` for a release.
- Tests: `(cd anc && python3 -m unittest discover -s tests -t .)` and
  `gjs tests/anc.test.js` when gjs is available.
- Code comments explain *why*, in English, like the surrounding code.
- Use `Theme` tokens (spacing, radius, surface colors) for chrome. The night
  sky is the only place with fixed colors, and they live in `NightColors`.
