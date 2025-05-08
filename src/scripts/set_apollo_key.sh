#!/bin/bash
# shellcheck disable=SC2153
supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"
APOLLO_KEY_NAME="$(echo "$supergraph" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_APOLLO_KEY"

echo "export APOLLO_KEY=${!APOLLO_KEY_NAME}" >>"$BASH_ENV"
