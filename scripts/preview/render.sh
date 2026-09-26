#!/bin/sh
# Regenerates the README screenshots from mock data (no real devices,
# hostnames or wallpapers are involved). Needs Qt 6 and a DMS install for
# the Material Symbols font.
set -e
cd "$(dirname "$0")"
out=../../screenshots
mkdir -p "$out"
# GPU rendering (OpenGL) is needed for the black hole shader; the default
# offscreen backend is software-only and skips shaders.
run() { QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl qml-qt6 -I imports shot.qml -- "$1" "$(realpath "$out")/$2"; }
run orbit orbit.png
run zoom charging.png
run orbitfocus detail-charging.png
run desktop desktop.png
run desktopfocus desktop-detail.png
run hiddencard hidden.png
run menu menu.png
run connecting connecting.png
run ancfocus noise-control.png
run buds earbuds.png
run budsdock earbuds-dock.png
