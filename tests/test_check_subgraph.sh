#!/bin/bash
# shellcheck source=tests/helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

seed_schema() {
    mkdir -p graphql/schema/nested
    echo "type Query { ping: String }" >graphql/schema/query.graphql
    echo "type Place { id: ID! }" >graphql/schema/nested/place.graphql
    echo "not a schema" >graphql/schema/README.md
}

new_sandbox
seed_schema
export DIRECTORY="graphql/schema"
export SUPERGRAPH="nexbus-router"
export SUBGRAPH="places-projector"
export ENVIRONMENT="stag"
run_script check_subgraph.sh
assert_eq 0 "$STATUS" "happy path: exits 0"
schema="$(cat schema.graphql)"
assert_contains "$schema" "type Query { ping: String }" "concatenates top-level schema files"
assert_contains "$schema" "type Place { id: ID! }" "concatenates nested schema files"
assert_not_contains "$schema" "not a schema" "ignores non-graphql files"
assert_contains "$schema" "input SHAPlacesProjectorInput {" "appends the PascalCase SHA marker type"
assert_contains "$schema" "value: String = \"$CIRCLE_SHA1\"" "SHA marker carries CIRCLE_SHA1"
assert_contains "$(cat "$STUB_STATE/rover_args")" "subgraph check nexbus-router@stag" \
    "passes <supergraph>@<environment> as the graph ref"
assert_contains "$(cat "$STUB_STATE/rover_args")" "--name places-projector" "passes the subgraph name"
assert_contains "$(cat "$STUB_STATE/rover_args")" "--schema schema.graphql" "passes the generated schema"
cleanup_sandbox

new_sandbox
seed_schema
export DIRECTORY="graphql/schema"
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
seed_schema
export DIRECTORY="graphql/schema"
export SUPERGRAPH="nexbus-router-abcdefghijklmnop"
export SUBGRAPH="places-projector"
export ENVIRONMENT="prod"
run_script check_subgraph.sh
assert_contains "$(cat "$STUB_STATE/rover_args")" "subgraph check nexbus-router-abcdefghijklm@prod" \
    "truncates the supergraph graph id to 27 chars"
cleanup_sandbox

# --- failure modes ----------------------------------------------------------

new_sandbox
mkdir -p graphql/schema
export DIRECTORY="graphql/schema"
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
run_script check_subgraph.sh
assert_eq 1 "$STATUS" "directory has no .graphql files: exits non-zero"
assert_contains "$STDERR" "graphql/schema" "directory has no .graphql files: names the directory"
assert_eq "" "$(cat "$STUB_STATE/rover_args" 2>/dev/null)" \
    "directory has no .graphql files: never calls rover"
cleanup_sandbox

new_sandbox
export DIRECTORY="graphql/missing"
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
run_script check_subgraph.sh
assert_eq 1 "$STATUS" "missing directory: exits non-zero"
cleanup_sandbox

new_sandbox
seed_schema
export DIRECTORY="graphql/schema"
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
echo 1 >"$STUB_STATE/rover_exit"
run_script check_subgraph.sh
assert_eq 1 "$STATUS" "rover check fails: propagates the failure"
cleanup_sandbox

finish
