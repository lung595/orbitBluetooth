#!/bin/sh
# Runs the QML tests (the "new device" pop-up, the polar scope, the
# keyboard-profile question of the connection flow) without Quickshell or a
# Bluetooth adapter: stubs/ stands in for Quickshell and the DMS services,
# Device.qml for a BlueZ device, and NewDeviceWindow.qml replaces the real
# layer-shell window. Needs Qt 6 (qml, qml6, qml-qt6 or PySide6).
# Run from anywhere: sh tests/qml/run.sh
# The stubs come last: the last import path wins, and the preview imports
# (Theme, StyledText) have their own, smaller qs.Services.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$(dirname "$here")")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# The work folder mirrors the plugin root: components/ as it is, the tests
# beside it, and two stand-ins over the real window and D-Bus check
cp -r "$root"/components "$work"/
cp "$here"/ProfileCheck.qml "$here"/NewDeviceWindow.qml "$work"/components/pairing/
cp "$here"/Device.qml "$here"/*.test.qml "$work"/
# The preview's made-up route (and overlay) stand in for the daemon's
mkdir "$work"/mock
cp "$root"/scripts/preview/mock/*.qml "$work"/mock/
# Quickshell's device list is a model with .values; the stub keeps a plain list
sed -i 's/Bluetooth\.devices\.values/Bluetooth.list/g' "$work"/components/pairing/*.qml
export QT_QPA_PLATFORM=offscreen
# Print to the terminal, not to journald, including print() lines
export QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES='qml.debug=true;js.debug=true'
# Fedora keeps Qt 6's tools out of PATH
for tool in qml6 qml-qt6 qml /usr/lib64/qt6/bin/qml; do
    if command -v "$tool" >/dev/null 2>&1; then
        for test in "$work"/*.test.qml; do
            "$tool" -I "$root/scripts/preview/imports" -I "$here/stubs" "$test"
        done
        exit 0
    fi
done
python3 - "$root/scripts/preview/imports" "$here/stubs" "$work/newDevice.test.qml" <<'PY'
import sys
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
app = QGuiApplication(sys.argv[:1])
engine = QQmlApplicationEngine()
for path in sys.argv[1:3]:
    engine.addImportPath(path)
engine.load(QUrl.fromLocalFile(sys.argv[3]))
sys.exit(app.exec() if engine.rootObjects() else 1)
PY
