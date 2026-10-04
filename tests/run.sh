#!/bin/sh
# Runs every pure-logic test file (tests/*.test.js) with gjs and adds up the
# checks. Run from anywhere: sh tests/run.sh
here=$(cd "$(dirname "$0")" && pwd)
total=0
status=0
for file in "$here"/*.test.js; do
    out=$(gjs "$file") || status=1
    echo "$out" | grep -v 'tests passed$'
    n=$(echo "$out" | sed -n 's/^\([0-9]*\) tests passed$/\1/p')
    total=$((total + ${n:-0}))
done
[ "$status" -eq 0 ] && echo "$total tests passed" || echo "failures (see above)"
exit $status
