#!/bin/bash
# SUPERGRAPH, SUBGRAPH, ENVIRONMENT and DOMAIN_NAME are supplied by the step's
# environment block and the consumer's CircleCI context. FEDERATION_SKIP comes
# from check_base_branch.sh and SCHEMA_UNCHANGED from
# compare_published_schema.sh, both via BASH_ENV.
# shellcheck disable=SC2153
set -eo pipefail

if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

if [ "${SCHEMA_UNCHANGED:-}" = true ]; then
    echo "Skipping: this schema is already published."
    exit 0
fi

subgraph="${SUBGRAPH:-$CIRCLE_PROJECT_REPONAME}"
supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"
routing_url="https://${SUPERGRAPH//router/gateway}.$DOMAIN_NAME/subgraph/$subgraph/graphql"

if [ ! -s schema.graphql ]; then
    echo "schema.graphql is missing or empty. The check subgraph step must run first." >&2
    exit 1
fi

echo "Subgraph: $subgraph"
echo "Supergraph: $supergraph"
echo "Routing URL: $routing_url"

rover subgraph publish "$supergraph" \
    --name "$subgraph" \
    --schema schema.graphql \
    --routing-url "$routing_url"
