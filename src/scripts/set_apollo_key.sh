#!/bin/bash
# SUPERGRAPH is supplied by the step's environment block. FEDERATION_SKIP comes
# from check_base_branch.sh via BASH_ENV.
# shellcheck disable=SC2153
set -eo pipefail

if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

if [ -z "$SUPERGRAPH" ]; then
    echo "SUPERGRAPH is empty. Pass the supergraph parameter to this command." >&2
    exit 1
fi

# Truncated to 27 chars to match the Apollo graph id used in the graph ref.
supergraph="${SUPERGRAPH:0:27}"
apollo_key_name="$(echo "$supergraph" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_APOLLO_KEY"

# ${!name} raises a bash "bad substitution" on anything that is not a valid
# shell identifier, which would surface as an internal error rather than as
# advice about the supergraph name.
if ! echo "$apollo_key_name" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
    echo "Supergraph '${SUPERGRAPH}' derives ${apollo_key_name}, which is not a usable environment variable name." >&2
    echo "Use a supergraph that starts with a letter and contains only letters, digits and dashes." >&2
    exit 1
fi

apollo_key="${!apollo_key_name}"
if [ -z "$apollo_key" ]; then
    echo "${apollo_key_name} is not set." >&2
    echo "Add it to the CircleCI context attached to this job." >&2
    exit 1
fi

# %q, because CircleCI sources BASH_ENV: an unquoted key containing a space, $,
# backtick, quote or # would be truncated or would run a substitution, and would
# only surface two steps later as an opaque Rover auth error.
printf 'export APOLLO_KEY=%q\n' "$apollo_key" >>"$BASH_ENV"
