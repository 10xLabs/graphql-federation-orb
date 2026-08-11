#!/bin/bash
# SUPERGRAPH, SUBGRAPH, ENVIRONMENT and DOMAIN_NAME are supplied by the step's
# environment block and the consumer's CircleCI context.
# shellcheck disable=SC2153
set -eo pipefail

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
