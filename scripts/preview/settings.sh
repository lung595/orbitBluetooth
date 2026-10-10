#!/bin/sh
# Renders the settings page states (rail, search, pages) from made-up data.
# Usage: sh scripts/preview/settings.sh <out-folder>   (default: /tmp/orbit-settings)
set -e
cd "$(dirname "$0")"
out=${1:-/tmp/orbit-settings}
mkdir -p "$out"
for s in default category search jump none many battery battery-narrow battery-light default-narrow search-narrow default-light search-light jump-light; do
    QT_QPA_PLATFORM=offscreen qml-qt6 -I imports -I ../../tests/qml/stubs settings.qml -- "$s" "$(realpath "$out")/$s.png"
done
