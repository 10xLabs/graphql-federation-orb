#!/bin/bash
# shellcheck source=helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

new_sandbox
export SUPERGRAPH="nexbus-router"
export NEXBUS_ROUTER_APOLLO_KEY="service:nexbus-router:secret"
run_script set_apollo_key.sh
assert_eq 0 "$STATUS" "derives key var name: exits 0"
assert_eq "service:nexbus-router:secret" "$(bash_env_value APOLLO_KEY)" \
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
assert_eq "service:truncated:secret" "$(bash_env_value APOLLO_KEY)" \
    "truncates supergraph to 27 chars: looks up the truncated var name"
cleanup_sandbox

# CircleCI sources BASH_ENV, so the exported value has to survive shell parsing
# intact. An unquoted key would truncate at the space and run the substitution.
new_sandbox
export SUPERGRAPH="nexbus-router"
# shellcheck disable=SC2016  # the unexpanded metacharacters are the point
export NEXBUS_ROUTER_APOLLO_KEY='service:nexbus router:$(id) `id` #x'"'"'q'
run_script set_apollo_key.sh
assert_eq 0 "$STATUS" "shell metacharacters in the key: exits 0"
# shellcheck disable=SC2016
assert_eq 'service:nexbus router:$(id) `id` #x'"'"'q' "$(bash_env_value APOLLO_KEY)" \
    "shell metacharacters in the key: survives BASH_ENV being sourced"
cleanup_sandbox

# A supergraph that derives a non-identifier must say so. ${!name} would raise a
# bash "bad substitution" and kill the step with an internal error instead.
new_sandbox
export SUPERGRAPH="2024-router"
run_script set_apollo_key.sh
assert_eq 1 "$STATUS" "supergraph deriving a non-identifier: exits non-zero"
assert_contains "$STDERR" "2024_ROUTER_APOLLO_KEY" \
    "supergraph deriving a non-identifier: names the variable it tried"
assert_not_contains "$STDERR" "bad substitution" \
    "supergraph deriving a non-identifier: no bash internal error"
assert_eq "" "$(cat "$BASH_ENV")" "supergraph deriving a non-identifier: exports nothing"
cleanup_sandbox

# An unset context variable must fail here, not two steps later inside rover.
new_sandbox
export SUPERGRAPH="nexbus-router"
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

new_sandbox
export FEDERATION_SKIP="PR targets develop, not master"
export SUPERGRAPH="nexbus-router"
run_script set_apollo_key.sh
assert_eq 0 "$STATUS" "FEDERATION_SKIP set: exits 0"
assert_eq "" "$(cat "$BASH_ENV")" "FEDERATION_SKIP set: exports nothing"
cleanup_sandbox

finish
