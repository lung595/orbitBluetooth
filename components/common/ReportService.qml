import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Common
import "../../diagnostics/Cpu.js" as Cpu
import "../../diagnostics/Gather.js" as Gather
import "../../diagnostics/Log.js" as Log
import "../../diagnostics/Redact.js" as Redact
import "../../diagnostics/Report.js" as Report

// Builds the anonymous report (level 2) when somebody asks for it, and does
// nothing otherwise: no timer, no process, no file open at rest. A request
// reads the shell's CPU ticks, waits one second, reads them again (the only
// way to get a rate), then runs the few short tools of Gather.PROBES one
// after the other and assembles the text with Report.build. The settings
// button and the IPC command share this one component.
Item {
    id: root

    // Orbit's settings, read key by key through Gather.settingsOf
    required property var prefs
    // Which surfaces this instance can say are alive: { settings: true, ... }
    property var surfaces: ({})

    readonly property bool busy: _phase !== "idle"
    // The finished report, kept until takeReport() hands it over
    property string report: ""
    signal built(string text)

    // "idle", "before", "waiting", "after", "probing"
    property string _phase: "idle"
    property string _via: "button"
    property real _ticks: -1
    property real _startedAt: 0
    property var _cpu: null
    property var _answers: ({})
    property int _probe: 0
    property string _plugin: ""

    function request(via) {
        if (busy)
            return false;
        _via = via;
        Log.event("ORB-I030", {
            "via": via
        });
        report = "";
        _answers = ({});
        _cpu = null;
        manifest.path = Paths.strip(Qt.resolvedUrl("../../plugin.json"));
        manifest.reload();
        _plugin = Gather.pluginVersion(manifest.text());
        _phase = "before";
        _read();
        return true;
    }

    // The finished report, once: it is not kept longer than needed
    function takeReport() {
        const text = report;
        report = "";
        return text;
    }

    // The path is set on the first request, so nothing is opened before one;
    // setting it loads the file, later requests reload it
    function _read() {
        if (stat.path === "/proc/self/stat")
            stat.reload();
        else
            stat.path = "/proc/self/stat";
    }

    function _ticksNow() {
        return Cpu.ticksOf(stat.text());
    }

    function _loaded() {
        if (_phase === "before") {
            _ticks = _ticksNow();
            _startedAt = Date.now();
            _phase = "waiting";
            window.restart();
        } else if (_phase === "after") {
            const ms = Date.now() - _startedAt;
            _cpu = {
                "percent": Cpu.percent(_ticks, _ticksNow(), ms),
                "windowMs": ms
            };
            _probe = 0;
            _phase = "probing";
            _next();
        }
    }

    function _next() {
        if (_probe >= Gather.PROBES.length) {
            _finish();
            return;
        }
        probe.launch(Gather.PROBES[_probe].command);
    }

    function _finish() {
        // The devices are counted and their names hidden before any engine
        // line is cleaned: read now, bound to nothing
        const devices = Bluetooth.devices.values;
        for (const device of devices)
            Redact.register("device", device.deviceName || device.name || "");
        const a = _answers;
        const text = Report.build({
            "now": Date.now(),
            "plugin": _plugin,
            "versions": {
                "dms": a.dms,
                "quickshell": a.quickshell,
                "qt": a.qt,
                "niri": a.niri,
                "distro": a.distro
            },
            "surfaces": surfaces,
            "settings": Gather.settingsOf(key => prefs[key]),
            "facts": {
                "devices": devices.length,
                "reduceMotion": prefs.reduceMotion
            },
            "cpu": _cpu,
            "journal": a.journal
        });
        report = text;
        _phase = "idle";
        built(text);
    }

    // Opened only for the one read of the request (the path is set there)
    FileView {
        id: stat
        printErrors: false
        onLoaded: root._loaded()
    }

    // Read synchronously, once per request
    FileView {
        id: manifest
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: window
        interval: 1000
        onTriggered: {
            root._phase = "after";
            root._read();
        }
    }

    ToolProcess {
        id: probe
        stdout: StdioCollector {
            id: answer
        }
        // A tool that is not installed (rpm off Fedora, niri under another
        // compositor) answers nothing: the report says "unknown" for it
        onFinished: code => {
            const spec = Gather.PROBES[root._probe];
            const answers = root._answers;
            answers[spec.key] = Gather.parse(spec.key, code === -1 ? "" : answer.text);
            root._answers = answers;
            root._probe++;
            root._next();
        }
    }
}
