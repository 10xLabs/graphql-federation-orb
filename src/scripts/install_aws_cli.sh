#!/bin/bash
# FEDERATION_SKIP comes from check_base_branch.sh via BASH_ENV.
set -eo pipefail

if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

# Unpacked into a temp dir, not the working directory. The working directory is
# the consumer's checkout, and the installer's payload is a directory named
# `aws` — cleaning that up in place would delete a repository directory of the
# same name along with it.
install_dir="$(mktemp -d)"
trap 'rm -rf "$install_dir"' EXIT

curl -sSL --fail --retry 3 "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$install_dir/awscliv2.zip"
unzip -q -o "$install_dir/awscliv2.zip" -d "$install_dir"
sudo "$install_dir/aws/install" --update
