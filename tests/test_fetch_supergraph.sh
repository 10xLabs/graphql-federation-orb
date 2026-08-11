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
