#!/bin/sh
# Prints the anonymous Orbit diagnostic report, to read and paste in a GitHub
# issue (docs/DEBUGGING.md). It asks the running plugin for its report, and
# adds the latest Quickshell crash folder if there is one. Nothing is sent
# anywhere, nothing is written to disk, no network, no argument is read.
#
#   sh scripts/diagnose.sh
#
# Everything printed goes through reduce() first: the home folder, the login
# name, the host name, addresses and long secrets-looking runs are replaced.
set -u

# Replaces every occurrence of a fixed text (not a pattern: a "." in a host
# name or a "/" in a path must mean itself). The text travels in the
# environment, so no program is ever built from it. Under 3 characters it
# would hide too much, so it is left alone.
replace_fixed() {
    FROM="$1" TO="$2" awk '
        BEGIN { from = ENVIRON["FROM"]; to = ENVIRON["TO"]; n = length(from) }
        n < 3 { print; next }
        {
            out = ""
            while ((i = index($0, from)) > 0) {
                out = out substr($0, 1, i - 1) to
                $0 = substr($0, i + n)
            }
            print out $0
        }'
}

# The reduction, as a filter. The plugin's own report is already clean; this
# is the second wall for what only the shell or the journal knows.
reduce() {
    user=$(id -un 2>/dev/null || echo "")
    host=$(hostname 2>/dev/null || echo "")
    replace_fixed "${HOME:-}" "~" |
        sed -E \
            -e 's#(/var)?/home/[^/ :"]+#~#g' \
            -e 's#/run/user/[0-9]+#/run/user/<uid>#g' \
            -e 's#^([A-Z][a-z]{2} [ 0-9][0-9] [0-9:]{8}) [^ ]+ #\1 #' \
            -e 's#([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}#<mac>#g' \
            -e 's#([0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}#<mac>#g' \
            -e 's#([0-9]{1,3}\.){3}[0-9]{1,3}#<ip>#g' \
            -e 's#[A-Za-z0-9+_-]{40,}#<secret>#g' \
            -e 's#[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}#<email>#g' |
        replace_fixed "$user" "user" |
        replace_fixed "$host" "host"
}

# The plugin's own report: the first call starts it, the second hands it over
# once it is ready (about two seconds, a CPU measure included)
report_from_shell() {
    command -v dms >/dev/null 2>&1 || return 1
    dms ipc call orbitBluetooth diagnostics >/dev/null 2>&1 || return 1
    sleep 2
    out=$(dms ipc call orbitBluetooth diagnostics 2>/dev/null) || return 1
    case $out in
    "Still collecting"*)
        sleep 2
        out=$(dms ipc call orbitBluetooth diagnostics 2>/dev/null) || return 1
        ;;
    esac
    case $out in
    "OrbitBluetooth diagnostic report"*)
        printf '%s\n' "$out"
        ;;
    *) return 1 ;;
    esac
}

# Without the shell or the plugin: versions and the lines Orbit left in the
# DMS journal, which is all that survives a restart
report_without_shell() {
    echo "OrbitBluetooth diagnostic report (anonymous, from the command line: the plugin did not answer)"
    echo "Created      : $(date -u '+%Y-%m-%d %H:%M:%S') UTC"
    echo "DMS          : $(dms version 2>/dev/null | head -n 1)"
    echo "Quickshell   : $(quickshell --version 2>/dev/null | head -n 1)"
    echo "Compositor   : $(niri --version 2>/dev/null | head -n 1)"
    echo "Distribution : $(sed -n 's/^PRETTY_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/os-release 2>/dev/null | head -n 1)"
    echo "Journal lines (last 50 at most):"
    lines=$(journalctl --user -u dms -n 300 --no-pager 2>/dev/null | grep -F '[orbit]' | tail -n 50)
    if [ -n "$lines" ]; then
        printf '%s\n' "$lines" | sed 's/^/  /'
    else
        echo "  none"
    fi
}

# The latest crash folder Quickshell kept: its file names and the start of
# its text description, not the memory dump
crash() {
    dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/crashes"
    [ -d "$dir" ] || return 0
    latest=$(ls -1t "$dir" 2>/dev/null | head -n 1)
    [ -n "$latest" ] || return 0
    echo "Latest Quickshell crash folder (file names and sizes, then the start of its text):"
    ls -l "$dir/$latest" 2>/dev/null | tail -n +2 | awk '{print "  " $5 "  " $9}'
    for f in "$dir/$latest"/*.txt "$dir/$latest/metadata"; do
        [ -f "$f" ] || continue
        echo "  --- $(basename "$f")"
        head -n 40 "$f" | sed 's/^/  /'
    done
}

{
    report_from_shell || report_without_shell
    crash
} | reduce
