#!/bin/bash
# shellcheck source=tests/helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

composed_supergraph() {
    printf 'schema { query: Query }\ninput SHAPlacesProjectorInput { value: String = "%s" }\n' "$1"
}

new_sandbox
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DEVOPS_CONFIG_BUCKET="devops-config"
composed_supergraph "$CIRCLE_SHA1" >"$STUB_STATE/rover_stdout"
run_script fetch_supergraph.sh
assert_eq 0 "$STATUS" "SHA present in composed supergraph: exits 0"
assert_contains "$(cat "$STUB_STATE/rover_args")" "supergraph fetch nexbus-router@stag" \
    "fetches <supergraph>@<environment>"
assert_eq "s3 cp supergraph.graphql s3://devops-config/nexbus-router@stag/supergraph.graphql" \
    "$(cat "$STUB_STATE/aws_args")" "uploads to the environment-scoped S3 key"
cleanup_sandbox

new_sandbox
export SUPERGRAPH="nexbus-router-abcdefghijklmnop"
export ENVIRONMENT="prod"
export DEVOPS_CONFIG_BUCKET="devops-config"
composed_supergraph "$CIRCLE_SHA1" >"$STUB_STATE/rover_stdout"
run_script fetch_supergraph.sh
assert_contains "$(cat "$STUB_STATE/aws_args")" "s3://devops-config/nexbus-router-abcdefghijklm@prod/" \
    "truncates the supergraph graph id to 27 chars"
cleanup_sandbox

# --- the unchanged-schema path ----------------------------------------------

# Nothing was published, so no CIRCLE_SHA1 is being composed and there is
# nothing to wait for. The upload still has to run: it is what lets a re-run
# heal a gateway left stale by a run that published and then died before the
# upload, which the schema hash comparison alone can never notice.
new_sandbox
export SCHEMA_UNCHANGED=true
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DEVOPS_CONFIG_BUCKET="devops-config"
composed_supergraph "some-older-sha" >"$STUB_STATE/rover_stdout"
run_script fetch_supergraph.sh
assert_eq 0 "$STATUS" "schema unchanged: exits 0 without waiting for CIRCLE_SHA1"
assert_eq 1 "$(wc -l <"$STUB_STATE/rover_args" | tr -d ' ')" "schema unchanged: fetches once, does not poll"
assert_eq "s3 cp supergraph.graphql s3://devops-config/nexbus-router@stag/supergraph.graphql" \
    "$(cat "$STUB_STATE/aws_args")" "schema unchanged: still uploads the composed supergraph"
cleanup_sandbox

new_sandbox
export SCHEMA_UNCHANGED=true
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DEVOPS_CONFIG_BUCKET="devops-config"
echo 1 >"$STUB_STATE/rover_exit"
run_script fetch_supergraph.sh
assert_eq 1 "$STATUS" "schema unchanged and every fetch fails: exits non-zero"
assert_eq "" "$(cat "$STUB_STATE/aws_args" 2>/dev/null)" "schema unchanged and every fetch fails: uploads nothing"
cleanup_sandbox

# --- skipped by an earlier step ---------------------------------------------

new_sandbox
export FEDERATION_SKIP="PR targets develop, not master"
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DEVOPS_CONFIG_BUCKET="devops-config"
run_script fetch_supergraph.sh
assert_eq 0 "$STATUS" "FEDERATION_SKIP set: exits 0"
assert_eq "" "$(cat "$STUB_STATE/rover_args" 2>/dev/null)" "FEDERATION_SKIP set: never calls rover"
assert_eq "" "$(cat "$STUB_STATE/aws_args" 2>/dev/null)" "FEDERATION_SKIP set: uploads nothing"
cleanup_sandbox

# --- failure modes ----------------------------------------------------------

new_sandbox
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DEVOPS_CONFIG_BUCKET="devops-config"
composed_supergraph "aaaaaaaabbbbbbbbccccccccdddddddd" >"$STUB_STATE/rover_stdout"
run_script fetch_supergraph.sh
assert_eq 1 "$STATUS" "SHA never composed: exits non-zero"
assert_eq "" "$(cat "$STUB_STATE/aws_args" 2>/dev/null)" "SHA never composed: uploads nothing"
assert_eq 8 "$(wc -l <"$STUB_STATE/rover_args" | tr -d ' ')" "SHA never composed: retries 8 times"
cleanup_sandbox

new_sandbox
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DEVOPS_CONFIG_BUCKET="devops-config"
composed_supergraph "$CIRCLE_SHA1" >"$STUB_STATE/rover_stdout"
echo 1 >"$STUB_STATE/aws_exit"
run_script fetch_supergraph.sh
assert_eq 1 "$STATUS" "S3 upload fails: exits non-zero instead of reporting success"
cleanup_sandbox

new_sandbox
export SUPERGRAPH="nexbus-router"
export ENVIRONMENT="stag"
export DEVOPS_CONFIG_BUCKET="devops-config"
echo 1 >"$STUB_STATE/rover_exit"
run_script fetch_supergraph.sh
assert_eq 1 "$STATUS" "rover fetch fails every attempt: exits non-zero"
assert_eq "" "$(cat "$STUB_STATE/aws_args" 2>/dev/null)" "rover fetch fails every attempt: uploads nothing"
cleanup_sandbox

finish
