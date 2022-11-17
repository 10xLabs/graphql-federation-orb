#!/bin/bash
find "$DIRECTORY" -name "*.graphql" -exec cat {} \; >schema.graphql

subgraph="$(echo "$CIRCLE_PROJECT_REPONAME" | sed -r 's/(^|-)([a-z])/\U\2/g')"

cat >>schema.graphql <<EOL

input SHA${subgraph}Input {
    value: String = "${CIRCLE_SHA1}"
}
EOL

rover subgraph check "$SUPERGRAPH@$ENVIRONMENT" \
    --schema schema.graphql \
    --name "$CIRCLE_PROJECT_REPONAME"
