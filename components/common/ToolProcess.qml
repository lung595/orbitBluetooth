import Quickshell.Io

// A Process that always ends with one `finished` signal. Quickshell emits
// neither `started` nor `exited` when the program is not installed: it only
// warns and sets `running` back to false. Without this, a missing tool would
// leave its caller waiting for good.
Process {
    id: root

    // The exit status, or -1 when the program could not be started
    signal finished(int code)
    // The program is running: for callers that must talk to it at once
    signal launched

    // "idle", "launching" (asked, not started yet), "running" or "ended"
    property string _phase: "idle"

    function launch(argv) {
        command = argv;
        _phase = "launching";
        running = true;
    }

    onStarted: {
        _phase = "running";
        launched();
    }
    onExited: code => {
        _phase = "ended";
        finished(code);
    }
    onRunningChanged: {
        if (!running && _phase === "launching") {
            _phase = "ended";
            finished(-1);
        }
    }
}
