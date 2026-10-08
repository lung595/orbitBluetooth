import QtQuick
import Quickshell.Io
import "../../diagnostics/Gather.js" as Gather
import "../../diagnostics/Log.js" as Log

// Puts the report on the clipboard through a program, never through
// Quickshell's own clipboard: only wl-copy can mark the text as sensitive,
// which keeps it out of DMS's clipboard history (D371). The text goes in by
// standard input (nothing on the command line), and the fallback is DMS's own
// copy. Nothing runs until copy() is called.
Item {
    id: root

    // "idle", "copying", "copied" or "none" (no tool could copy it)
    property string result: "idle"
    // True when only the fallback worked: the history may hold the report
    property bool inHistory: false

    property string _text: ""
    property int _tool: 0

    function copy(text) {
        if (result === "copying")
            return;
        _text = text;
        inHistory = false;
        result = "copying";
        _try(0);
    }

    function _try(index) {
        _tool = index;
        run.command = Gather.COPY_TOOLS[index].command;
        run.stdinEnabled = true;
        run.running = true;
    }

    function _failed(code) {
        const tool = Gather.COPY_TOOLS[_tool].tool;
        if (Gather.missing(code))
            Log.event("ORB-W011", {
                "tool": tool
            });
        else
            Log.event("ORB-E003", {
                "tool": tool,
                "code": code
            });
        if (_tool + 1 < Gather.COPY_TOOLS.length) {
            _try(_tool + 1);
            return;
        }
        _text = "";
        result = "none";
    }

    Process {
        id: run
        // Closing standard input ends the copy; wl-copy then serves the text
        // from the background and this process returns
        onStarted: {
            write(root._text);
            stdinEnabled = false;
        }
        onExited: code => {
            if (code !== 0) {
                root._failed(code);
                return;
            }
            root.inHistory = root._tool > 0;
            root._text = "";
            root.result = "copied";
        }
    }
}
