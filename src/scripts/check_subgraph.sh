#!/bin/bash
# SUPERGRAPH, SUBGRAPH, DIRECTORY and ENVIRONMENT are supplied by the step's
# environment block and the consumer's CircleCI context.
# shellcheck disable=SC2153
set -eo pipefail

subgraph="${SUBGRAPH:-$CIRCLE_PROJECT_REPONAME}"
supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"

if [ ! -d "$DIRECTORY" ]; then
    echo "Schema directory ${DIRECTORY} does not exist." >&2
    exit 1
fi

find "$DIRECTORY" -name "*.graphql" -exec cat {} \; >schema.graphql

if [ ! -s schema.graphql ]; then
    echo "No non-empty *.graphql files found under ${DIRECTORY}." >&2
    exit 1
fi

# PascalCase the subgraph name for the marker type below. awk keeps this
# portable; GNU sed's \U is not available on every executor.
name="$(echo "$subgraph" | awk -F'-' '{for (i = 1; i <= NF; i++) printf "%s%s", toupper(substr($i, 1, 1)), substr($i, 2)}')"

# The marker carries CIRCLE_SHA1 into the composed supergraph, which is the
# only way fetch_supergraph.sh can tell this revision apart from an earlier one.
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
