#!/bin/bash
# shellcheck disable=SC2153
subgraph="$CIRCLE_PROJECT_REPONAME"
supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"
routing_url="https://${SUPERGRAPH//@router/@gateway}.$DOMAIN_NAME/subgraph/$subgraph/graphql"
echo "Subgraph: $subgraph" 
echo "Supergraph: $supergraph" 
echo "Routing URL: $routing_url"

rover subgraph publish "$supergraph" \
    --name "$subgraph" \
    --schema schema.graphql \
    --routing-url "$routing_url"
    # --routing-url "https://$CIRCLE_PROJECT_REPONAME-$SUBGRAPH-api.$DOMAIN_NAME/graphql"

