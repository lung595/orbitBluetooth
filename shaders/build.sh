#!/bin/sh
# Recompiles the shaders after editing a .frag (Qt 6 "qsb" tool). The
# compiled .qsb files are committed so the plugin works without it.
set -e
cd "$(dirname "$0")"
QSB=${QSB:-$(command -v qsb || echo /usr/lib64/qt6/bin/qsb)}
for f in *.frag; do
    "$QSB" --qt6 -o "$f.qsb" "$f"
done
