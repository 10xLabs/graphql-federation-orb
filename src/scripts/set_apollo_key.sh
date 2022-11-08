#!/bin/bash
APOLLO_KEY_NAME="$(echo "$SUPERGRAPH" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_APOLLO_KEY"

echo "export APOLLO_KEY=${!APOLLO_KEY_NAME}" >>"$BASH_ENV"
