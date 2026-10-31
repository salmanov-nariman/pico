#!/bin/bash
set -euo pipefail

# Pass the owner-built CLI path. No app launch or real builds are performed.
pico_cli=${1:?Usage: bash Tests/DeveloperCLIChecks.sh /path/to/pico-cli}

expect_exit() {
    local expected=$1
    shift
    local actual=0
    "$pico_cli" "$@" >/dev/null 2>&1 || actual=$?
    if [ "$actual" -ne "$expected" ]; then
        echo "Expected exit $expected, received $actual: $*" >&2
        exit 1
    fi
}

expect_exit 0 --help
expect_exit 64 notify unknown-event
expect_exit 64 build --
expect_exit 64 build /usr/bin/true
expect_exit 0 build -- /usr/bin/true
expect_exit 1 test -- /usr/bin/false
expect_exit 7 build -- /bin/sh -c 'exit 7'
expect_exit 127 build -- /nonexistent/pico-check-command

output=$("$pico_cli" test -- /usr/bin/printf '%s|%s' 'one argument' 'second argument')
if [ "$output" != 'one argument|second argument' ]; then
    echo "Argument boundaries or stdout were not preserved" >&2
    exit 1
fi
echo "Developer CLI checks passed"
