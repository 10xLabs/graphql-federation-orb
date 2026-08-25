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

# No orb script halts any more: halting from inside a reusable command would
# also kill the steps a consumer put after it in their own job. The
# circleci-agent stub exists purely so this assertion can prove that.
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
    : >"$STUB_STATE/rover_stderr"

    # Environment the scripts read. Unset first so leakage cannot mask a bug.
    unset BASE_BRANCH DIRECTORY SUPERGRAPH SUBGRAPH ENVIRONMENT DOMAIN_NAME
    unset DEVOPS_CONFIG_BUCKET GITHUB_PAT CIRCLE_PULL_REQUEST SCHEMA_HASH
    unset FEDERATION_SKIP SCHEMA_UNCHANGED APOLLO_KEY GRAPHQL_FEDERATION_DISABLED
    # Apollo key variables are named after the supergraph under test, so clear
    # whatever a previous sandbox exported rather than an explicit list: a
    # leaked key would make the "missing context variable" assertions pass
    # against that value instead of against the script's guard.
    local leaked
    for leaked in $(compgen -A variable | grep '_APOLLO_KEY$'); do
        unset "$leaked"
    done
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
cat "$STUB_STATE/rover_stderr" >&2
exit "$(cat "$STUB_STATE/rover_exit")"
STUB

    cat >"$SANDBOX/bin/aws" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$STUB_STATE/aws_args"
exit "$(cat "$STUB_STATE/aws_exit")"
STUB

    # Unpacks a stand-in for the AWS installer payload into -d, or into the
    # working directory when -d is absent, the way real unzip does.
    cat >"$SANDBOX/bin/unzip" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$STUB_STATE/unzip_args"
dest="." prev=""
for arg in "$@"; do
    [ "$prev" = "-d" ] && dest="$arg"
    prev="$arg"
done
mkdir -p "$dest/aws"
printf '#!/bin/bash\nexit 0\n' >"$dest/aws/install"
chmod +x "$dest/aws/install"
STUB

    cat >"$SANDBOX/bin/sudo" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$STUB_STATE/sudo_args"
STUB

    # Keeps retry loops instant.
    cat >"$SANDBOX/bin/sleep" <<'STUB'
#!/bin/bash
exit 0
STUB

    chmod +x "$SANDBOX"/bin/*
}

# --- fixtures ---------------------------------------------------------------

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
    # Restore the caller's errexit rather than forcing it on. The test files run
    # under `set -uo pipefail` deliberately: with errexit left on, the first
    # failing assertion line kills the whole file, so every later assertion is
    # silently skipped and nothing prints a FAIL.
    local caller_flags="$-"
    set +e
    bash "$SCRIPTS_DIR/$script" >"$out" 2>"$err"
    STATUS=$?
    case "$caller_flags" in
    *e*) set -e ;;
    *) set +e ;;
    esac
    STDOUT="$(cat "$out")"
    STDERR="$(cat "$err")"
}

# bash_env_value reads back what a script exported into BASH_ENV, the way a
# later CircleCI step would see it after sourcing the file.
bash_env_value() {
    local line
    line="$(grep "^export $1=" "$BASH_ENV" | tail -1)"
    [ -n "$line" ] || return 0
    (
        set +u
        eval "$line"
        printf '%s' "${!1}"
    )
}
