import QtQuick

// The count of failed checks of one QML test, and how the test ends: the
// same lines and exit code in every test
QtObject {
    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function finish() {
        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
