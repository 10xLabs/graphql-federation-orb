#!/bin/bash
# shellcheck disable=SC2153
subgraph="$CIRCLE_PROJECT_REPONAME-$SUBGRAPH"
supergraph="$SUPERGRAPH@$ENVIRONMENT"

find "$DIRECTORY" -name "*.graphql" -exec cat {} \; >schema.graphql

name="$(echo "$subgraph" | sed -r 's/(^|-)([a-z])/\U\2/g')"

cat >>schema.graphql <<EOL

input SHA${name}Input {
    value: String = "${CIRCLE_SHA1}"
}
EOL

rover subgraph check "$supergraph" \
    --name "$subgraph" \
    --schema schema.graphql
