#!/bin/bash
# SUPERGRAPH, SUBGRAPH, ENVIRONMENT and SCHEMA_HASH are supplied by the step's
# environment block, the consumer's CircleCI context and build_schema.sh.
# FEDERATION_SKIP comes from check_base_branch.sh via BASH_ENV.
# shellcheck disable=SC2153
set -eo pipefail

if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

subgraph="${SUBGRAPH:-$CIRCLE_PROJECT_REPONAME}"
supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"

if [ -z "$SCHEMA_HASH" ]; then
    echo "SCHEMA_HASH is not set. The build schema step must run first." >&2
    exit 1
fi

# A missing subgraph or variant is the normal first-publish case, and an
# unreachable graph will fail loudly at the publish step anyway. Either way,
# proceed rather than skip: publishing a schema that is already published is
# harmless, skipping one that is not leaves the gateway stale.
if ! rover subgraph fetch "$supergraph" --name "$subgraph" >published.graphql 2>fetch_error.log; then
    echo "Could not fetch the published subgraph ${subgraph} from ${supergraph}:"
    cat fetch_error.log
    echo "Assuming the schema needs publishing."
    exit 0
fi

# Matching the bare hash rather than the surrounding GraphQL keeps this immune to
# any reformatting Apollo applies to the SDL it hands back.
#
# A flag rather than `circleci-agent step halt`, for two reasons. Halting kills
# the consumer's own steps when this command is used inside their job. And it
# would also skip the supergraph upload, so a run whose publish succeeded but
# whose upload failed could never heal on a re-run — the hash would match, the
# job would go green, and S3 would keep serving the pre-publish supergraph.
if grep -qF "$SCHEMA_HASH" published.graphql; then
    echo "${supergraph} already publishes this schema (${SCHEMA_HASH})."
    echo "Skipping the check and publish steps; the supergraph upload still runs."
    echo "export SCHEMA_UNCHANGED=true" >>"$BASH_ENV"
    exit 0
fi

echo "Published schema for ${subgraph} differs from ${SCHEMA_HASH}. Continuing."
