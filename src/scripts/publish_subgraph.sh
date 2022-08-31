#!/bin/bash
find "$DIRECTORY" -name "*.graphql" -exec cat {} \; > schema.graphql

rover subgraph publish "$SUPERGRAPH@$ENVIRONMENT" \
    --name "$CIRCLE_PROJECT_REPONAME" --schema schema.graphql \
    --routing-url "https://$CIRCLE_PROJECT_REPONAME.$DOMAIN_NAME/graphql"
