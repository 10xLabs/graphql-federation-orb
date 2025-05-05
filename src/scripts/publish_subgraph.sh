#!/bin/bash
# shellcheck disable=SC2153
subgraph="$CIRCLE_PROJECT_REPONAME-$SUBGRAPH"
supergraph="$SUPERGRAPH@$ENVIRONMENT"

rover subgraph publish "$supergraph" \
    --name "$subgraph" \
    --schema schema.graphql \
    --routing-url "https://$SUBGRAPH-graphql-gateway.$DOMAIN_NAME/$CIRCLE_PROJECT_REPONAME/graphql"
    # --routing-url "https://$CIRCLE_PROJECT_REPONAME-$SUBGRAPH-api.$DOMAIN_NAME/graphql"
