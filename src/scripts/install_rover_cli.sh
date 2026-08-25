#!/bin/bash
# FEDERATION_SKIP comes from check_base_branch.sh via BASH_ENV.
set -eo pipefail

if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

curl -sSL --fail --retry 3 https://rover.apollo.dev/nix/latest | sh

sudo ln -sf ~/.rover/bin/rover /usr/local/bin/rover
