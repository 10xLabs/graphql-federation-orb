#!/bin/bash
# shellcheck disable=SC2153
subgraph="$CIRCLE_PROJECT_REPONAME"
supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"

find "$DIRECTORY" -name "*.graphql" -exec cat {} \; >schema.graphql

name="$(echo "$subgraph" | sed -r 's/(^|-)([a-z])/\U\2/g')"

cat >>schema.graphql <<EOL

input SHA${name}Input {
    value: String = "${CIRCLE_SHA1}"
}
EOL

echo "Subgraph: $subgraph"
echo "Supergraph: $supergraph"

rover subgraph check "$supergraph" \
    --name "$subgraph" \
    --schema schema.graphql
