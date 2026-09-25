#!/bin/sh
# Records the README GIFs from mock data (no real devices, hostnames or
# wallpapers). Needs Qt 6, ffmpeg and a DMS install for the icon font.
# Usage: scripts/preview/record.sh [scene ...]   (default: all scenes)
set -e
cd "$(dirname "$0")"
out=$(realpath ../../screenshots)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
scenes=${*:-beam gauge focus connect}
for s in $scenes; do
    mkdir -p "$tmp/$s"
    QT_QPA_PLATFORM=offscreen qml-qt6 -I imports record.qml -- "$s" "$tmp/$s"
    # Frame each scene on its subject to keep the files small
    case $s in
    beam) frame="crop=360:230:100:125" ;;
    gauge) frame="crop=380:420:90:40" ;;
    *) frame="scale=400:-1:flags=lanczos" ;;
    esac
    # Close-ups keep 20 fps; whole-scene clips use 15 fps and fewer colors
    case $s in
    beam | gauge) rate=20 colors=128 ;;
    *) rate=15 colors=96 ;;
    esac
    ffmpeg -loglevel error -y -framerate 25 -i "$tmp/$s/f%04d.png" \
        -vf "$frame,fps=$rate,split[a][b];[a]palettegen=max_colors=$colors:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
        -loop 0 "$out/$s.gif"
    echo "$s.gif: $(ls "$tmp/$s" | wc -l) frames"
done
