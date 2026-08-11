#!/bin/bash
# Shared helpers for the script test suite.
#
# Each tests/test_*.sh file sources this, defines assertions, and calls
# `finish` as its last statement. Scripts under src/scripts are executed
# verbatim (they are what gets inlined into the orb at pack time), with
# external binaries replaced by recording stubs.

TESTS_PASSED=0
TESTS_FAILED=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/src/scripts"
ORIGINAL_PATH="$PATH"

# --- assertions -------------------------------------------------------------

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ok   $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL $1"
    [ -n "${2:-}" ] && echo "       $2"
    return 0
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$label"
    else
        fail "$label" "expected: [$expected]  actual: [$actual]"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        fail "$label" "[$needle] not found in: $haystack"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" label="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$label"
    else
        fail "$label" "[$needle] unexpectedly found in: $haystack"
    fi
}

assert_halted() {
    if [ -f "$STUB_STATE/halted" ]; then
        pass "$1"
    else
        fail "$1" "expected 'circleci-agent step halt' to have been called"
    fi
}

assert_not_halted() {
    if [ ! -f "$STUB_STATE/halted" ]; then
        pass "$1"
    else
        fail "$1" "'circleci-agent step halt' was called but should not have been"
    fi
}

finish() {
    echo "  ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
    [ "$TESTS_FAILED" -eq 0 ]
}

# --- sandbox ----------------------------------------------------------------

# new_sandbox creates an isolated temp dir with stub binaries on PATH and
# resets every environment variable the orb scripts read.
new_sandbox() {
    SANDBOX="$(mktemp -d)"
    STUB_STATE="$SANDBOX/state"
    mkdir -p "$SANDBOX/bin" "$STUB_STATE" "$SANDBOX/work"

    write_stubs

    PATH="$SANDBOX/bin:$ORIGINAL_PATH"
    export PATH STUB_STATE

    # Defaults for stub behaviour.
    echo 0 >"$STUB_STATE/curl_exit"
    echo '{}' >"$STUB_STATE/curl_body"
    echo 0 >"$STUB_STATE/rover_exit"
    echo 0 >"$STUB_STATE/aws_exit"
    : >"$STUB_STATE/rover_stdout"

    # Environment the scripts read. Unset first so leakage cannot mask a bug.
    unset BASE_BRANCH DIRECTORY SUPERGRAPH SUBGRAPH ENVIRONMENT DOMAIN_NAME
    unset DEVOPS_CONFIG_BUCKET GITHUB_PAT CIRCLE_PULL_REQUEST
    export CIRCLE_SHA1="0123456789abcdef0123456789abcdef01234567"
    export CIRCLE_PROJECT_REPONAME="places-projector"
    export BASH_ENV="$SANDBOX/bash_env"
    : >"$BASH_ENV"

    cd "$SANDBOX/work" || return 1
}

cleanup_sandbox() {
    cd "$REPO_ROOT" || return 0
    PATH="$ORIGINAL_PATH"
    export PATH
    [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}

write_stubs() {
    cat >"$SANDBOX/bin/circleci-agent" <<'STUB'
#!/bin/bash
echo "$@" >>"$STUB_STATE/halted"
STUB

    # Serves a canned body/exit code, and records the URL and headers it saw.
    cat >"$SANDBOX/bin/curl" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$STUB_STATE/curl_args"
cat "$STUB_STATE/curl_body"
exit "$(cat "$STUB_STATE/curl_exit")"
STUB

    cat >"$SANDBOX/bin/rover" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$STUB_STATE/rover_args"
cat "$STUB_STATE/rover_stdout"
exit "$(cat "$STUB_STATE/rover_exit")"
STUB

    cat >"$SANDBOX/bin/aws" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$STUB_STATE/aws_args"
exit "$(cat "$STUB_STATE/aws_exit")"
STUB

    # Keeps retry loops instant.
    cat >"$SANDBOX/bin/sleep" <<'STUB'
#!/bin/bash
exit 0
STUB

    chmod +x "$SANDBOX"/bin/*
}

# --- fixtures ---------------------------------------------------------------

# init_repo builds a git repo with one commit so HEAD~1 resolves.
init_repo() {
    git init --quiet --initial-branch=main .
    git config user.email test@example.com
    git config user.name test
    mkdir -p graphql/schema
    echo "type Query { ping: String }" >graphql/schema/base.graphql
    git add -A
    git commit --quiet -m "initial"
    echo "unrelated" >README.md
    git add -A
    git commit --quiet -m "second"
}

commit_schema_change() {
    echo "type Query { ping: String, pong: String }" >graphql/schema/base.graphql
    git add -A
    git commit --quiet -m "schema change"
}

# github_pr_response points CIRCLE_PULL_REQUEST at a PR and makes the curl
# stub answer with the given base ref.
github_pr_response() {
    export CIRCLE_PULL_REQUEST="https://github.com/10xLabs/places-projector/pull/42"
    export GITHUB_PAT="fake-token"
    printf '{"base":{"ref":"%s"}}' "$1" >"$STUB_STATE/curl_body"
}

# run_script executes an orb script and captures status, stdout and stderr.
# Sets STATUS, STDOUT and STDERR for the calling test file to assert on.
# shellcheck disable=SC2034
run_script() {
    local script="$1"
    local out="$SANDBOX/stdout" err="$SANDBOX/stderr"
    set +e
    bash "$SCRIPTS_DIR/$script" >"$out" 2>"$err"
    STATUS=$?
    set -e
    STDOUT="$(cat "$out")"
    STDERR="$(cat "$err")"
}
