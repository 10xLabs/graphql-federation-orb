#!/bin/bash
# shellcheck source=tests/helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

# The installer's payload is a directory named `aws`. The working directory is
# the consumer's checkout, so unpacking and then cleaning up in place would
# delete a repository directory of the same name — terraform modules, IAM
# policy json, fixtures — along with the installer.
new_sandbox
mkdir -p aws
echo "terraform" >aws/main.tf
run_script install_aws_cli.sh
assert_eq 0 "$STATUS" "happy path: exits 0"
assert_eq "terraform" "$(cat aws/main.tf 2>/dev/null)" "leaves a repo directory named aws untouched"
assert_eq "main.tf" "$(ls aws)" "does not unpack the installer payload into the working directory"
assert_contains "$(cat "$STUB_STATE/sudo_args")" "/aws/install --update" "runs the installer it unpacked"
assert_not_contains "$(cat "$STUB_STATE/sudo_args")" "$PWD/aws/install" "runs the installer from outside the checkout"
cleanup_sandbox

new_sandbox
export FEDERATION_SKIP="PR targets develop, not master"
run_script install_aws_cli.sh
assert_eq 0 "$STATUS" "FEDERATION_SKIP set: exits 0"
assert_eq "" "$(cat "$STUB_STATE/sudo_args" 2>/dev/null)" "FEDERATION_SKIP set: installs nothing"
cleanup_sandbox

finish
