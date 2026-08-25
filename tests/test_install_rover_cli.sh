#!/bin/bash
# shellcheck source=helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

# The installer is `curl ... | sh`; an empty body is the stub's stand-in for an
# install script that succeeded.
new_sandbox
: >"$STUB_STATE/curl_body"
run_script install_rover_cli.sh
assert_eq 0 "$STATUS" "happy path: exits 0"
assert_contains "$(cat "$STUB_STATE/sudo_args")" "ln -sf" "symlinks rover onto PATH idempotently"
cleanup_sandbox

# The base branch guard runs before this step, so a PR against the wrong branch
# must not pay for the Rover install.
new_sandbox
export FEDERATION_SKIP="PR targets develop, not master"
run_script install_rover_cli.sh
assert_eq 0 "$STATUS" "FEDERATION_SKIP set: exits 0"
assert_eq "" "$(cat "$STUB_STATE/curl_args" 2>/dev/null)" "FEDERATION_SKIP set: downloads nothing"
cleanup_sandbox

finish
