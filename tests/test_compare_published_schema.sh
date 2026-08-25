#!/bin/bash
# shellcheck source=helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

HASH="a3f9c1e2000000000000000000000000000000000000000000000000000000ff"
OTHER_HASH="bbbbbbbb000000000000000000000000000000000000000000000000000000ff"

# published_subgraph writes what the rover stub will hand back for a fetch.
# $1 is the schemaHash line's value, or "none" for a pre-3.0.0 marker.
published_subgraph() {
    if [ "$1" = "none" ]; then
        printf 'type Query { ping: String }\ninput SHAPlacesProjectorInput {\n    value: String = "deadbeef"\n}\n' \
            >"$STUB_STATE/rover_stdout"
        return
    fi
    printf 'type Query { ping: String }\ninput SHAPlacesProjectorInput {\n    value: String = "deadbeef"\n    schemaHash: String = "%s"\n}\n' \
        "$1" >"$STUB_STATE/rover_stdout"
}

new_sandbox
export SUPERGRAPH="nexbus-router"
export SUBGRAPH="places-projector"
export ENVIRONMENT="stag"
export SCHEMA_HASH="$HASH"
published_subgraph "$HASH"
run_script compare_published_schema.sh
assert_eq 0 "$STATUS" "hash already published: exits 0"
# Not a halt: halting would kill a consumer's own steps, and it would also skip
# the supergraph upload, so a run that published and then failed on the upload
# could never heal itself.
assert_not_halted "hash already published: does not halt the job"
assert_eq true "$(bash_env_value SCHEMA_UNCHANGED)" "hash already published: exports SCHEMA_UNCHANGED"
assert_contains "$(cat "$STUB_STATE/rover_args")" "subgraph fetch nexbus-router@stag --name places-projector" \
    "fetches the subgraph from <supergraph>@<environment>"
cleanup_sandbox

new_sandbox
export SUPERGRAPH="nexbus-router"
export SUBGRAPH="places-projector"
export ENVIRONMENT="stag"
export SCHEMA_HASH="$HASH"
published_subgraph "$OTHER_HASH"
run_script compare_published_schema.sh
assert_eq 0 "$STATUS" "different hash published: exits 0"
assert_not_halted "different hash published: does not halt"
assert_eq "" "$(bash_env_value SCHEMA_UNCHANGED)" "different hash published: exports no skip flag"
cleanup_sandbox

# Subgraphs published by <=2.3.0 carry a marker with no schemaHash field, so the
# first run after upgrading has to publish once to seed it.
new_sandbox
export SUPERGRAPH="nexbus-router"
export SUBGRAPH="places-projector"
export ENVIRONMENT="stag"
export SCHEMA_HASH="$HASH"
published_subgraph none
run_script compare_published_schema.sh
assert_eq 0 "$STATUS" "pre-3.0.0 marker with no schemaHash: exits 0"
assert_not_halted "pre-3.0.0 marker with no schemaHash: does not halt"
cleanup_sandbox

# A subgraph or variant that does not exist yet is the first-publish case.
# Proceed rather than skip: publishing an already-published schema is harmless,
# skipping an unpublished one leaves the gateway stale.
new_sandbox
export SUPERGRAPH="nexbus-router"
export SUBGRAPH="places-projector"
export ENVIRONMENT="stag"
export SCHEMA_HASH="$HASH"
echo 1 >"$STUB_STATE/rover_exit"
printf 'error[E009]: Subgraph "places-projector" does not exist\n' >"$STUB_STATE/rover_stderr"
run_script compare_published_schema.sh
assert_eq 0 "$STATUS" "rover fetch fails: exits 0"
assert_not_halted "rover fetch fails: does not halt"
assert_contains "$STDOUT" "E009" "rover fetch fails: surfaces rover's error"
assert_contains "$STDOUT" "Assuming the schema needs publishing" "rover fetch fails: says what it decided"
cleanup_sandbox

new_sandbox
export SUPERGRAPH="nexbus-router-abcdefghijklmnop"
export SUBGRAPH="places-projector"
export ENVIRONMENT="prod"
export SCHEMA_HASH="$HASH"
published_subgraph "$OTHER_HASH"
run_script compare_published_schema.sh
assert_contains "$(cat "$STUB_STATE/rover_args")" "subgraph fetch nexbus-router-abcdefghijklm@prod" \
    "truncates the supergraph graph id to 27 chars"
cleanup_sandbox

new_sandbox
export SUPERGRAPH="nexbus-router"
export SUBGRAPH=""
export ENVIRONMENT="stag"
export SCHEMA_HASH="$HASH"
published_subgraph "$OTHER_HASH"
run_script compare_published_schema.sh
assert_contains "$(cat "$STUB_STATE/rover_args")" "--name places-projector" \
    "empty subgraph parameter: falls back to CIRCLE_PROJECT_REPONAME"
cleanup_sandbox

# --- skipped by an earlier step ---------------------------------------------

new_sandbox
export FEDERATION_SKIP="PR targets develop, not master"
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
run_script compare_published_schema.sh
assert_eq 0 "$STATUS" "FEDERATION_SKIP set: exits 0"
assert_eq "" "$(cat "$STUB_STATE/rover_args" 2>/dev/null)" "FEDERATION_SKIP set: never calls rover"
assert_contains "$STDOUT" "PR targets develop" "FEDERATION_SKIP set: says why it skipped"
cleanup_sandbox

# --- failure modes ----------------------------------------------------------

new_sandbox
export SUPERGRAPH="nexbus-router"
export SUBGRAPH="places-projector"
export ENVIRONMENT="stag"
run_script compare_published_schema.sh
assert_eq 1 "$STATUS" "SCHEMA_HASH unset: exits non-zero"
assert_not_halted "SCHEMA_HASH unset: does not halt"
assert_eq "" "$(cat "$STUB_STATE/rover_args" 2>/dev/null)" "SCHEMA_HASH unset: never calls rover"
cleanup_sandbox

finish
