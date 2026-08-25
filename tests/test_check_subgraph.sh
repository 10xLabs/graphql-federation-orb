#!/bin/bash
# shellcheck source=helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

HASH="a3f9c1e2000000000000000000000000000000000000000000000000000000ff"

# check_subgraph.sh consumes what build_schema.sh produced: schema.graphql on
# disk plus SCHEMA_HASH in the environment.
seed_built_schema() {
    printf 'type Query { ping: String }\n' >schema.graphql
    export SCHEMA_HASH="$HASH"
}

new_sandbox
seed_built_schema
export SUPERGRAPH="nexbus-router"
export SUBGRAPH="places-projector"
export ENVIRONMENT="stag"
run_script check_subgraph.sh
assert_eq 0 "$STATUS" "happy path: exits 0"
schema="$(cat schema.graphql)"
assert_contains "$schema" "type Query { ping: String }" "leaves the built schema in place"
assert_contains "$schema" "input SHAPlacesProjectorInput {" "appends the PascalCase marker type"
assert_contains "$schema" "value: String = \"$CIRCLE_SHA1\"" \
    "marker carries CIRCLE_SHA1 for the supergraph composition check"
assert_contains "$schema" "schemaHash: String = \"$HASH\"" \
    "marker carries the schema hash for the next run's comparison"
assert_contains "$(cat "$STUB_STATE/rover_args")" "subgraph check nexbus-router@stag" \
    "passes <supergraph>@<environment> as the graph ref"
assert_contains "$(cat "$STUB_STATE/rover_args")" "--name places-projector" "passes the subgraph name"
assert_contains "$(cat "$STUB_STATE/rover_args")" "--schema schema.graphql" "checks the built schema"
cleanup_sandbox

new_sandbox
seed_built_schema
export SUPERGRAPH="nexbus-router"
export SUBGRAPH=""
export ENVIRONMENT="stag"
run_script check_subgraph.sh
assert_contains "$(cat "$STUB_STATE/rover_args")" "--name places-projector" \
    "empty subgraph parameter: falls back to CIRCLE_PROJECT_REPONAME"
assert_contains "$(cat schema.graphql)" "input SHAPlacesProjectorInput {" \
    "empty subgraph parameter: marker type uses the fallback name"
cleanup_sandbox

new_sandbox
seed_built_schema
export SUPERGRAPH="nexbus-router-abcdefghijklmnop"
export SUBGRAPH="places-projector"
export ENVIRONMENT="prod"
run_script check_subgraph.sh
assert_contains "$(cat "$STUB_STATE/rover_args")" "subgraph check nexbus-router-abcdefghijklm@prod" \
    "truncates the supergraph graph id to 27 chars"
cleanup_sandbox

# --- skipped by an earlier step ---------------------------------------------

new_sandbox
seed_built_schema
export FEDERATION_SKIP="PR targets develop, not master"
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DOMAIN_NAME="stag.kolors.com.mx"
run_script check_subgraph.sh
assert_eq 0 "$STATUS" "FEDERATION_SKIP set: exits 0"
assert_eq "" "$(cat "$STUB_STATE/rover_args" 2>/dev/null)" "FEDERATION_SKIP set: never calls rover"
cleanup_sandbox

# The schema is already published, so there is nothing to check. Reaching rover
# here would re-check an identical schema on every build.
new_sandbox
seed_built_schema
export SCHEMA_UNCHANGED=true
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DOMAIN_NAME="stag.kolors.com.mx"
run_script check_subgraph.sh
assert_eq 0 "$STATUS" "SCHEMA_UNCHANGED set: exits 0"
assert_eq "" "$(cat "$STUB_STATE/rover_args" 2>/dev/null)" "SCHEMA_UNCHANGED set: never calls rover"
cleanup_sandbox

# --- failure modes ----------------------------------------------------------

new_sandbox
export SCHEMA_HASH="$HASH"
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
run_script check_subgraph.sh
assert_eq 1 "$STATUS" "schema.graphql missing: exits non-zero"
assert_eq "" "$(cat "$STUB_STATE/rover_args" 2>/dev/null)" "schema.graphql missing: never calls rover"
cleanup_sandbox

new_sandbox
printf 'type Query { ping: String }\n' >schema.graphql
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
run_script check_subgraph.sh
assert_eq 1 "$STATUS" "SCHEMA_HASH unset: exits non-zero"
assert_not_contains "$(cat schema.graphql)" "SHA" "SCHEMA_HASH unset: appends no marker"
cleanup_sandbox

new_sandbox
seed_built_schema
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
echo 1 >"$STUB_STATE/rover_exit"
run_script check_subgraph.sh
assert_eq 1 "$STATUS" "rover check fails: propagates the failure"
cleanup_sandbox

finish
