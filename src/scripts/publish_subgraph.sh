#!/bin/bash
find "$DIRECTORY" -name "*.graphql" -exec cat {} \; >schema.graphql

rover subgraph publish "$SUPERGRAPH@$ENVIRONMENT" \
    --schema schema.graphql \
    --name "$CIRCLE_PROJECT_REPONAME" \
    --routing-url "https://$CIRCLE_PROJECT_REPONAME-api.$DOMAIN_NAME/graphql"
