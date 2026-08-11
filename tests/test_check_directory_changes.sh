#!/bin/bash
# shellcheck source=tests/helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

# --- non-PR builds diff HEAD~1..HEAD ---------------------------------------

new_sandbox
init_repo
export DIRECTORY="graphql/schema"
run_script check_directory_changes.sh
assert_eq 0 "$STATUS" "non-PR, no schema change: exits 0"
assert_halted "non-PR, no schema change: halts"
cleanup_sandbox

new_sandbox
init_repo
commit_schema_change
export DIRECTORY="graphql/schema"
run_script check_directory_changes.sh
assert_eq 0 "$STATUS" "non-PR, schema changed: exits 0"
assert_not_halted "non-PR, schema changed: does not halt"
cleanup_sandbox

# --- PR builds diff against the PR base branch ------------------------------

new_sandbox
init_repo
git checkout --quiet -b feature
commit_schema_change
git remote add origin .
git update-ref "refs/remotes/origin/main" main
github_pr_response "main"
export DIRECTORY="graphql/schema"
run_script check_directory_changes.sh
assert_eq 0 "$STATUS" "PR, schema changed: exits 0"
assert_not_halted "PR, schema changed: does not halt"
assert_contains "$(cat "$STUB_STATE/curl_args")" "api.github.com/repos/10xLabs/places-projector/pulls/42" \
    "PR: queries the pulls API for the base ref"
cleanup_sandbox

new_sandbox
init_repo
git checkout --quiet -b feature
echo "not a schema" >other.txt
git add -A
git commit --quiet -m "unrelated change"
git remote add origin .
git update-ref "refs/remotes/origin/main" main
github_pr_response "main"
export DIRECTORY="graphql/schema"
run_script check_directory_changes.sh
assert_eq 0 "$STATUS" "PR, no schema change: exits 0"
assert_halted "PR, no schema change: halts"
cleanup_sandbox

# --- failures must be loud, never a silent halt -----------------------------

new_sandbox
init_repo
git checkout --quiet -b feature
commit_schema_change
github_pr_response "main"
echo 22 >"$STUB_STATE/curl_exit" # curl --fail on an HTTP error
run_script check_directory_changes.sh
assert_eq 1 "$STATUS" "PR, GitHub API call fails: exits non-zero"
assert_not_halted "PR, GitHub API call fails: does not halt"
assert_contains "$STDERR" "GitHub" "PR, GitHub API call fails: explains why"
cleanup_sandbox

new_sandbox
init_repo
git checkout --quiet -b feature
commit_schema_change
github_pr_response "main"
echo '{"message":"Bad credentials"}' >"$STUB_STATE/curl_body" # jq -> null
run_script check_directory_changes.sh
assert_eq 1 "$STATUS" "PR, base ref missing from response: exits non-zero"
assert_not_halted "PR, base ref missing from response: does not halt"
cleanup_sandbox

new_sandbox
init_repo
export DIRECTORY="graphql/does-not-exist"
run_script check_directory_changes.sh
assert_not_contains "$STDERR" "fatal" "missing directory: no bare git fatal"
cleanup_sandbox

finish
