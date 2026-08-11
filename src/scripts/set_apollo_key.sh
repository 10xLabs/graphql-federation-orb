#!/bin/bash
# SUPERGRAPH is supplied by the step's environment block.
# shellcheck disable=SC2153
set -eo pipefail

if [ -z "$SUPERGRAPH" ]; then
    echo "SUPERGRAPH is empty. Pass the supergraph parameter to this command." >&2
    exit 1
fi

# Truncated to 27 chars to match the Apollo graph id used in the graph ref.
supergraph="${SUPERGRAPH:0:27}"
apollo_key_name="$(echo "$supergraph" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_APOLLO_KEY"

if [ -z "${!apollo_key_name}" ]; then
    echo "${apollo_key_name} is not set." >&2
    echo "Add it to the CircleCI context attached to this job." >&2
    exit 1
fi

echo "export APOLLO_KEY=${!apollo_key_name}" >>"$BASH_ENV"
