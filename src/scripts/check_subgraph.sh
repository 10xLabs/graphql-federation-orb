#!/bin/bash
find "$DIRECTORY" -name "*.graphql" -exec cat {} \; > schema.graphql

rover subgraph check "$SUPERGRAPH@$ENVIRONMENT" \
    --schema schema.graphql \
    --name "$CIRCLE_PROJECT_REPONAME"
