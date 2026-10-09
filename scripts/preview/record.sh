#!/bin/sh
# Records the README GIFs from mock data (no real devices, hostnames or
# wallpapers). Needs Qt 6, ffmpeg and a DMS install for the icon font.
# Usage: scripts/preview/record.sh [scene ...]   (default: all scenes)
set -e
cd "$(dirname "$0")"
out=$(realpath ../../screenshots)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
scenes=${*:-beam beamstyles gauge focus connect newdevice}
for s in $scenes; do
    # The four charging beam styles, one GIF each (beams.qml shows each moving, at rest
    # under Reduce motion, and as a second charging device)
    if [ "$s" = beamstyles ]; then
        for style in pulse filament chain horizon; do
            mkdir -p "$tmp/$style"
            QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl qml-qt6 -I imports beams.qml -- gif "$style" "$tmp/$style"
            ffmpeg -loglevel error -y -framerate 25 -i "$tmp/$style/f%04d.png" \
                -vf "crop=330:216:10:10,fps=20,split[a][b];[a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
                -loop 0 "$out/charging-beam-$style.gif"
            echo "charging-beam-$style.gif: $(ls "$tmp/$style" | wc -l) frames"
        done
        continue
    fi
    mkdir -p "$tmp/$s"
    # OpenGL rendering: the software backend skips shaders (charging beam)
    # and effects (the pop-up's shadow and rounded clip)
    if [ "$s" = newdevice ]; then
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl qml-qt6 -I imports sheet.qml -- green record "$tmp/$s"
    else
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl qml-qt6 -I imports record.qml -- "$s" "$tmp/$s"
    fi
    # Frame each scene on its subject to keep the files small
    case $s in
    beam) frame="crop=360:230:100:125" ;;
    gauge) frame="crop=380:420:90:40" ;;
    newdevice) frame="crop=400:600:20:0" ;;
    *) frame="scale=400:-1:flags=lanczos" ;;
    esac
    # Close-ups keep 20 fps; whole-scene clips use 15 fps and fewer colors
    case $s in
    beam | gauge | newdevice) rate=20 colors=128 ;;
    *) rate=15 colors=96 ;;
    esac
    ffmpeg -loglevel error -y -framerate 25 -i "$tmp/$s/f%04d.png" \
        -vf "$frame,fps=$rate,split[a][b];[a]palettegen=max_colors=$colors:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
        -loop 0 "$out/$s.gif"
    echo "$s.gif: $(ls "$tmp/$s" | wc -l) frames"
done
