pragma Singleton
import QtQuick

QtObject {
    property var screens: ["screen0"]
    // The environment the tests see: a made-up account, so a report test can
    // check that the account's name is hidden and never written
    property var environment: ({
            "USER": "bob",
            "HOME": "/home/bob"
        })
    function env(name) {
        return environment[name];
    }
}
