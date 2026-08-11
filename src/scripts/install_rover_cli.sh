#!/bin/bash
set -eo pipefail
curl -sSL --fail --retry 3 https://rover.apollo.dev/nix/latest | sh

sudo ln -sf ~/.rover/bin/rover /usr/local/bin/rover
