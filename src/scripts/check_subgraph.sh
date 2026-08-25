#!/bin/bash
# SUPERGRAPH, SUBGRAPH and ENVIRONMENT are supplied by the step's environment
# block and the consumer's CircleCI context. SCHEMA_HASH comes from
# build_schema.sh, FEDERATION_SKIP from check_base_branch.sh and
# SCHEMA_UNCHANGED from compare_published_schema.sh, all via BASH_ENV.
# shellcheck disable=SC2153
set -eo pipefail

if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

if [ "${SCHEMA_UNCHANGED:-}" = true ]; then
    echo "Skipping: this schema is already published."
    exit 0
fi

subgraph="${SUBGRAPH:-$CIRCLE_PROJECT_REPONAME}"
supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"

if [ ! -s schema.graphql ]; then
    echo "schema.graphql is missing or empty. The build schema step must run first." >&2
    exit 1
fi

if [ -z "$SCHEMA_HASH" ]; then
    echo "SCHEMA_HASH is not set. The build schema step must run first." >&2
    exit 1
fi

# PascalCase the subgraph name for the marker type below. awk keeps this
# portable; GNU sed's \U is not available on every executor.
name="$(echo "$subgraph" | awk -F'-' '{for (i = 1; i <= NF; i++) printf "%s%s", toupper(substr($i, 1, 1)), substr($i, 2)}')"

# Two markers, both load-bearing. `value` carries CIRCLE_SHA1 into the composed
# supergraph, which is the only way fetch_supergraph.sh can tell this revision
# apart from an earlier one. `schemaHash` is what compare_published_schema.sh
# looks for on the next run to decide whether anything needs publishing.
cat >>schema.graphql <<EOL

input SHA${name}Input {
    value: String = "${CIRCLE_SHA1}"
    schemaHash: String = "${SCHEMA_HASH}"
}
EOL

echo "Subgraph: $subgraph"
echo "Supergraph: $supergraph"

rover subgraph check "$supergraph" \
    --name "$subgraph" \
    --schema schema.graphql
