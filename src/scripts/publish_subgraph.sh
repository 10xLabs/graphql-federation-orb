#!/bin/bash
rover subgraph publish "$SUPERGRAPH@$ENVIRONMENT" \
    --schema schema.graphql \
    --name "$CIRCLE_PROJECT_REPONAME" \
    --routing-url "https://$CIRCLE_PROJECT_REPONAME-api.$DOMAIN_NAME/graphql"
