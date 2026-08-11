#!/bin/bash
# shellcheck source=tests/helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

new_sandbox
echo "type Query { ping: String }" >schema.graphql
export SUPERGRAPH="nexbus-router"
export SUBGRAPH="places-projector"
export ENVIRONMENT="stag"
export DOMAIN_NAME="stag.kolors.com.mx"
run_script publish_subgraph.sh
assert_eq 0 "$STATUS" "happy path: exits 0"
rover_args="$(cat "$STUB_STATE/rover_args")"
assert_contains "$rover_args" "subgraph publish nexbus-router@stag" "passes <supergraph>@<environment>"
assert_contains "$rover_args" "--name places-projector" "passes the subgraph name"
assert_contains "$rover_args" "--schema schema.graphql" "publishes the schema built by check_subgraph"
assert_contains "$rover_args" \
    "--routing-url https://nexbus-gateway.stag.kolors.com.mx/subgraph/places-projector/graphql" \
    "rewrites router -> gateway in the routing URL"
cleanup_sandbox

new_sandbox
echo "type Query { ping: String }" >schema.graphql
export SUPERGRAPH="nexbus-router"
export SUBGRAPH=""
export ENVIRONMENT="stag"
export DOMAIN_NAME="stag.kolors.com.mx"
run_script publish_subgraph.sh
assert_contains "$(cat "$STUB_STATE/rover_args")" "--name places-projector" \
    "empty subgraph parameter: falls back to CIRCLE_PROJECT_REPONAME"
cleanup_sandbox

# The full, untruncated supergraph is used for the routing host, while the
# graph ref is truncated to 27 chars.
new_sandbox
echo "type Query { ping: String }" >schema.graphql
export SUPERGRAPH="nexbus-router-abcdefghijklmnop"
export SUBGRAPH="places-projector"
export ENVIRONMENT="prod"
export DOMAIN_NAME="kolors.com.mx"
run_script publish_subgraph.sh
rover_args="$(cat "$STUB_STATE/rover_args")"
assert_contains "$rover_args" "subgraph publish nexbus-router-abcdefghijklm@prod" \
    "truncates the supergraph graph id to 27 chars"
assert_contains "$rover_args" "--routing-url https://nexbus-gateway-abcdefghijklmnop.kolors.com.mx/" \
    "routing URL keeps the untruncated supergraph"
cleanup_sandbox

# --- failure modes ----------------------------------------------------------

new_sandbox
echo "type Query { ping: String }" >schema.graphql
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DOMAIN_NAME="stag.kolors.com.mx"
echo 1 >"$STUB_STATE/rover_exit"
run_script publish_subgraph.sh
assert_eq 1 "$STATUS" "rover publish fails: propagates the failure"
cleanup_sandbox

new_sandbox
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DOMAIN_NAME="stag.kolors.com.mx"
run_script publish_subgraph.sh
assert_eq 1 "$STATUS" "schema.graphql missing: exits non-zero"
assert_eq "" "$(cat "$STUB_STATE/rover_args" 2>/dev/null)" "schema.graphql missing: never calls rover"
cleanup_sandbox

finish
