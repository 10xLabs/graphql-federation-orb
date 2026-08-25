#!/bin/bash
# DIRECTORY is supplied by the step's environment block. FEDERATION_SKIP comes
# from check_base_branch.sh via BASH_ENV.
# shellcheck disable=SC2153
set -eo pipefail

if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

if [ ! -d "$DIRECTORY" ]; then
    echo "Schema directory ${DIRECTORY} does not exist." >&2
    exit 1
fi

# Three things here are load-bearing for the hash below, which must depend only
# on the content of the schema files:
#   -L        follows symlinked schema files, which repos use to share types.
#   LC_ALL=C  pins the collation. find's traversal order is not stable across
#             machines, and a locale-aware sort orders punctuated names
#             differently from C, so the same files would hash differently on
#             two executors with different locales.
#   awk 1     copies each file with a guaranteed trailing newline. Plain cat
#             glues a file that lacks one onto the next file's first line, which
#             silently swallows a type when the join lands inside a comment.
find -L "$DIRECTORY" -name "*.graphql" -type f | LC_ALL=C sort | while IFS= read -r file; do
    awk 1 "$file"
done >schema.graphql

if [ ! -s schema.graphql ]; then
    echo "No non-empty *.graphql files found under ${DIRECTORY}." >&2
    exit 1
fi

# The hash covers the schema as authored, before the SHA marker is appended, so
# that two commits with identical schemas produce the same hash.
if command -v sha256sum >/dev/null 2>&1; then
    schema_hash="$(sha256sum schema.graphql | awk '{print $1}')"
else
    schema_hash="$(shasum -a 256 schema.graphql | awk '{print $1}')"
fi

echo "Schema hash: $schema_hash"
echo "export SCHEMA_HASH=${schema_hash}" >>"$BASH_ENV"
