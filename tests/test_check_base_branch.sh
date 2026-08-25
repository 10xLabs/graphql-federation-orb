#!/bin/bash
# shellcheck source=helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

# --- no PR, or no configured base branch, means nothing to check ------------

new_sandbox
export BASE_BRANCH="master"
run_script check_base_branch.sh
assert_eq 0 "$STATUS" "no PR: exits 0"
assert_not_halted "no PR: does not halt"
cleanup_sandbox

new_sandbox
github_pr_response "master"
export BASE_BRANCH=""
run_script check_base_branch.sh
assert_eq 0 "$STATUS" "no base_branch parameter: exits 0"
assert_not_halted "no base_branch parameter: does not halt"
cleanup_sandbox

# --- base branch match / mismatch ------------------------------------------

new_sandbox
github_pr_response "master"
export BASE_BRANCH="master"
run_script check_base_branch.sh
assert_eq 0 "$STATUS" "base branch matches: exits 0"
assert_not_halted "base branch matches: does not halt"
cleanup_sandbox

# A mismatch skips the rest of the command through BASH_ENV rather than halting
# the job, so a consumer running this command inside their own job keeps their
# own steps.
new_sandbox
github_pr_response "develop"
export BASE_BRANCH="master"
run_script check_base_branch.sh
assert_eq 0 "$STATUS" "base branch differs: exits 0"
assert_not_halted "base branch differs: does not halt the job"
assert_eq "PR targets develop, not master" "$(bash_env_value FEDERATION_SKIP)" \
    "base branch differs: exports a quoted FEDERATION_SKIP reason"
cleanup_sandbox

new_sandbox
github_pr_response "master"
export BASE_BRANCH="master"
run_script check_base_branch.sh
assert_eq "" "$(bash_env_value FEDERATION_SKIP)" "base branch matches: exports no skip flag"
cleanup_sandbox

# --- skipped from outside the orb -------------------------------------------

new_sandbox
github_pr_response "develop"
export BASE_BRANCH="master"
export FEDERATION_SKIP="orb-command-smoke"
run_script check_base_branch.sh
assert_eq 0 "$STATUS" "FEDERATION_SKIP set: exits 0"
assert_eq "" "$(cat "$STUB_STATE/curl_args" 2>/dev/null)" "FEDERATION_SKIP set: never queries GitHub"
cleanup_sandbox

# --- failures must be loud, never a silent halt -----------------------------

new_sandbox
github_pr_response "master"
export BASE_BRANCH="master"
echo 22 >"$STUB_STATE/curl_exit"
run_script check_base_branch.sh
assert_eq 1 "$STATUS" "GitHub API call fails: exits non-zero"
assert_not_halted "GitHub API call fails: does not halt"
assert_contains "$STDERR" "GitHub" "GitHub API call fails: explains why"
cleanup_sandbox

new_sandbox
github_pr_response "master"
export BASE_BRANCH="master"
echo '{"message":"Not Found"}' >"$STUB_STATE/curl_body"
run_script check_base_branch.sh
assert_eq 1 "$STATUS" "base ref missing from response: exits non-zero"
assert_not_halted "base ref missing from response: does not halt"
cleanup_sandbox

finish
