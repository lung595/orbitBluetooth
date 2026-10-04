#!/bin/sh
# Counts the frames a scene draws once it has settled, and the CPU the process
# used for the whole run (the same scenario in both versions, so the
# difference is the feature's), to compare the sky's depth of field with and
# without it, in and out of a group (D294).
# Usage: sh depth-bench.sh <output folder> <label> [mode...]
#   (default modes: orbit-bench together3-bench together3-bench-reduce)
# The log of each run is <folder>/bench-<label>-<mode>.log. Made-up devices
# only; OpenGL offscreen (the default backend draws no effects).
# Qt's own frame times (QSG_RENDER_TIMING) are in whole milliseconds: on a
# real GPU every frame of this scene reads 0 ms, so they are not summed here.
set -e
cd "$(dirname "$0")"
out=$1
label=$2
shift 2
[ -d "$out" ] && [ -n "$label" ] || { echo "usage: sh depth-bench.sh <existing output folder> <label> [mode...]"; exit 1; }
[ $# -gt 0 ] || set -- orbit-bench together3-bench together3-bench-reduce
for mode in "$@"; do
    log="$out/bench-$label-$mode.log"
    # Qt logs to the journal unless told otherwise; `print` needs qml.debug
    /usr/bin/time -f '%U %S' -o "$out/bench-time.txt" env QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES='qml.debug=true;js.debug=true' QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl /usr/lib64/qt6/bin/qml -I imports shot.qml -- "$mode" "$out/unused.png" >"$log" 2>&1 || echo "qml exited with $? (see $log)"
    printf '%s %s: ' "$label" "$mode"
    grep -o 'bench .* frames [0-9]* in' "$log" | tr '\n' ' '
    printf '| cpu seconds (user, system): %s\n' "$(cat "$out/bench-time.txt")"
done
