#!/bin/bash
# shellcheck source=helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

new_sandbox
run_script reset_state.sh
assert_eq 0 "$STATUS" "happy path: exits 0"
assert_eq "" "$(bash_env_value FEDERATION_SKIP)" "clears FEDERATION_SKIP"
assert_eq "" "$(bash_env_value SCHEMA_UNCHANGED)" "clears SCHEMA_UNCHANGED"
cleanup_sandbox

# $BASH_ENV lives for the whole job, so flags written by an earlier command in
# the same job are still there. Clearing them is the whole point of this step.
new_sandbox
printf 'export FEDERATION_SKIP=%q\nexport SCHEMA_UNCHANGED=true\n' "PR targets develop, not master" >"$BASH_ENV"
run_script reset_state.sh
assert_eq "" "$(bash_env_value FEDERATION_SKIP)" "clears a FEDERATION_SKIP left by an earlier command"
assert_eq "" "$(bash_env_value SCHEMA_UNCHANGED)" "clears a SCHEMA_UNCHANGED left by an earlier command"
cleanup_sandbox

# The one skip the orb reads but never writes: a job-level opt-out.
new_sandbox
export GRAPHQL_FEDERATION_DISABLED=1
run_script reset_state.sh
assert_contains "$(bash_env_value FEDERATION_SKIP)" "GRAPHQL_FEDERATION_DISABLED" \
    "GRAPHQL_FEDERATION_DISABLED set: seeds FEDERATION_SKIP"
assert_eq "" "$(bash_env_value SCHEMA_UNCHANGED)" "GRAPHQL_FEDERATION_DISABLED set: still clears SCHEMA_UNCHANGED"
cleanup_sandbox

finish
