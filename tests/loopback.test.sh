#!/bin/sh
# Test of the loopback script (Route.loopbackArgs) with a stand-in `pipewire`
# on PATH and a made-up $XDG_RUNTIME_DIR: hostile values stay inside their
# quoted strings, no name on disk ever holds data, the config is reached
# through a link to /dev/fd/3, the process goes when its standard input
# closes (the shell went away), and nothing runs without an absolute
# $XDG_RUNTIME_DIR.
# Needs gjs (the script is read from Route.js) and bash. Run: sh tests/loopback.test.sh
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'exec 4>&- 2>/dev/null; rm -rf "$work"' EXIT
fails=0
check() {
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got $2, want $3)"; fails=$((fails + 1)); fi
}

script=$(cd "$root" && gjs -c 'imports.searchPath.unshift("tests"); print(imports.lib.load("Route.js", ["loopbackArgs"]).loopbackArgs("a", "b")[2]);') || { echo "FAIL the script could not be read from Route.js"; exit 1; }

mkdir -p "$work/bin" "$work/out" "$work/run"
chmod 700 "$work/run"
# What the real pipewire would see: its arguments, the config read through
# the link, the runtime folder, then it waits until it is stopped
cat >"$work/bin/pipewire" <<'SH'
#!/bin/sh
out=$(dirname "$0")/../out
printf '%s\n' "$@" >"$out/args"
cat "$2" >"$out/conf"
readlink "$2" >"$out/link"
find "$XDG_RUNTIME_DIR" -type f -size +0c >"$out/files"
ls -A "$XDG_RUNTIME_DIR" >"$out/names"
: >"$out/ready"
exec sleep 30
SH
chmod +x "$work/bin/pipewire"

# Values that try to close their string and add a module of their own
cap='a"b\c } ] context.exec = [ { path = touch args = /tmp/orbit-pwned } ]'
pb='\" } { name = libpipewire-module-x } "'
delay='0.1" } ] x'
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

mkfifo "$work/in"
XDG_RUNTIME_DIR="$work/run" PATH="$work/bin:$PATH" bash -c "$script" orbit "$cap" "$pb" "$delay" <"$work/in" &
job=$!
# The writing end of the pipe the script watches: closing it is the shell going away
exec 4>"$work/in"
n=0
while [ ! -e "$work/out/ready" ] && [ $n -lt 50 ]; do sleep 0.1; n=$((n + 1)); done
check "pipewire is run on the config's link" "$(cat "$work/out/args" 2>/dev/null | tr '\n' ' ')" "-c $work/run/orbit-loopback.conf "
check "the link points to /dev/fd/3" "$(cat "$work/out/link" 2>/dev/null)" "/dev/fd/3"
check "no name on disk holds data" "$(cat "$work/out/files" 2>/dev/null)" ""
check "the runtime folder holds the link alone" "$(cat "$work/out/names" 2>/dev/null)" "orbit-loopback.conf"
conf=$(cat "$work/out/conf" 2>/dev/null)
check "each value is one escaped string" "$(printf '%s' "$conf" | grep -cF "capture.props = \"$(esc "$cap")\" playback.props = \"$(esc "$pb")\" target.delay.sec = \"$(esc "$delay")\" } } ]")" 1
# The config with every quoted string emptied: what is left is all that runs
bare=$(printf '%s\n' "$conf" | sed -E 's/"([^"\\]|\\.)*"/""/g')
check "outside the strings: Orbit's modules alone, no context.exec" "$(printf '%s' "$bare" | grep -o '{ name = [a-z-]*' | tr '\n' ' ')$(printf '%s' "$bare" | grep -c 'context\.exec')" "{ name = libpipewire-module-rt { name = libpipewire-module-protocol-native { name = libpipewire-module-client-node { name = libpipewire-module-adapter { name = libpipewire-module-loopback 0"
check "the rt module comes first and may be missing" "$(printf '%s' "$bare" | grep -c 'context.modules = \[ { name = libpipewire-module-rt flags = \[ ifexists nofail \] }')" 1
check "quiet and named Orbit" "$(printf '%s\n' "$conf" | head -1)" "context.properties = { log.level = 0 application.name = Orbit }"

# The shell goes away: its pipe closes and the stand-in is stopped
exec 4>&-
n=0
while kill -0 "$job" 2>/dev/null && [ $n -lt 30 ]; do sleep 0.1; n=$((n + 1)); done
check "standard input closed: it is gone" "$(kill -0 "$job" 2>/dev/null && echo running || echo gone)" "gone"
kill "$job" 2>/dev/null
check "nothing but the link is left" "$(ls -A "$work/run")" "orbit-loopback.conf"

# Without a runtime folder nothing runs
rm -f "$work/out/args"
env -u XDG_RUNTIME_DIR PATH="$work/bin:$PATH" bash -c "$script" orbit a b </dev/null 2>/dev/null
check "no XDG_RUNTIME_DIR: exit 1, pipewire never run" "$?, $([ -e "$work/out/args" ] && echo run || echo not-run)" "1, not-run"
XDG_RUNTIME_DIR=run PATH="$work/bin:$PATH" bash -c "$script" orbit a b </dev/null 2>/dev/null
check "a relative one: the same" "$?, $([ -e "$work/out/args" ] && echo run || echo not-run)" "1, not-run"

[ "$fails" -eq 0 ] && echo "loopback script: all passed" || exit 1
