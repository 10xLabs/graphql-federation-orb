#!/bin/bash
# shellcheck source=tests/helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

new_sandbox
export SUPERGRAPH="nexbus-router"
export NEXBUS_ROUTER_APOLLO_KEY="service:nexbus-router:secret"
run_script set_apollo_key.sh
assert_eq 0 "$STATUS" "derives key var name: exits 0"
assert_eq 'export APOLLO_KEY=service:nexbus-router:secret' "$(cat "$BASH_ENV")" \
    "derives key var name: exports APOLLO_KEY into BASH_ENV"
assert_not_contains "$STDOUT$STDERR" "secret" "does not print the key value"
cleanup_sandbox

# The Apollo graph id is truncated to 27 chars, so the key lookup must use the
# same truncation as the graph ref built by check/publish/fetch.
new_sandbox
export SUPERGRAPH="nexbus-router-abcdefghijklmnop"
export NEXBUS_ROUTER_ABCDEFGHIJKLM_APOLLO_KEY="service:truncated:secret"
run_script set_apollo_key.sh
assert_eq 0 "$STATUS" "truncates supergraph to 27 chars: exits 0"
assert_eq 'export APOLLO_KEY=service:truncated:secret' "$(cat "$BASH_ENV")" \
    "truncates supergraph to 27 chars: looks up the truncated var name"
cleanup_sandbox

# An unset context variable must fail here, not two steps later inside rover.
new_sandbox
export SUPERGRAPH="nexbus-router"
unset NEXBUS_ROUTER_APOLLO_KEY NEXBUS_ROUTER_ABCDEFGHIJKLM_APOLLO_KEY
run_script set_apollo_key.sh
assert_eq 1 "$STATUS" "missing context variable: exits non-zero"
assert_contains "$STDERR" "NEXBUS_ROUTER_APOLLO_KEY" \
    "missing context variable: names the variable the context must provide"
assert_eq "" "$(cat "$BASH_ENV")" "missing context variable: exports nothing"
cleanup_sandbox

new_sandbox
run_script set_apollo_key.sh
assert_eq 1 "$STATUS" "missing SUPERGRAPH: exits non-zero"
cleanup_sandbox

finish
