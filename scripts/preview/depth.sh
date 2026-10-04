#!/bin/sh
# Renders a Listen together with GPU shaders, to see the sky out of focus
# (D294): the blurred, darkened sky once the group has the centre.
# Usage: sh depth.sh <output folder> [mode...]   (default modes: together3 together3-reduce)
# Made-up devices only. The default offscreen backend is software-only and
# skips shaders and effects, so this asks for OpenGL.
set -e
cd "$(dirname "$0")"
out=$1
shift
[ -d "$out" ] || { echo "usage: sh depth.sh <existing output folder> [mode...]"; exit 1; }
[ $# -gt 0 ] || set -- together3 together3-reduce
for mode in "$@"; do
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl /usr/lib64/qt6/bin/qml -I imports shot.qml -- "$mode" "$out/depth-$mode.png"
done
