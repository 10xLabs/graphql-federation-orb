#!/bin/bash
# shellcheck source=tests/helpers.bash
set -uo pipefail
source "$(dirname "$0")/helpers.bash"

# exported_hash reads back what the script put into BASH_ENV, the way a later
# CircleCI step would see it.
exported_hash() {
    grep '^export SCHEMA_HASH=' "$BASH_ENV" | cut -d= -f2
}

new_sandbox
mkdir -p graphql/schema/nested
echo "type Query { ping: String }" >graphql/schema/query.graphql
echo "type Place { id: ID! }" >graphql/schema/nested/place.graphql
echo "not a schema" >graphql/schema/README.md
export DIRECTORY="graphql/schema"
run_script build_schema.sh
assert_eq 0 "$STATUS" "happy path: exits 0"
schema="$(cat schema.graphql)"
assert_contains "$schema" "type Query { ping: String }" "concatenates top-level schema files"
assert_contains "$schema" "type Place { id: ID! }" "concatenates nested schema files"
assert_not_contains "$schema" "not a schema" "ignores non-graphql files"
assert_not_contains "$schema" "SHA" "does not append the SHA marker (that is check_subgraph's job)"
hash_one="$(exported_hash)"
assert_eq 64 "${#hash_one}" "exports a 64-char sha256 to BASH_ENV"
cleanup_sandbox

# find's traversal order is not stable across machines, so the concatenation is
# sorted. Creating the same files in the opposite order must produce byte-identical
# output, otherwise the hash churns and every build republishes.
new_sandbox
mkdir -p graphql/schema
echo "type A { a: String }" >graphql/schema/aaa.graphql
echo "type Z { z: String }" >graphql/schema/zzz.graphql
export DIRECTORY="graphql/schema"
run_script build_schema.sh
forward_schema="$(cat schema.graphql)"
forward_hash="$(exported_hash)"
cleanup_sandbox

new_sandbox
mkdir -p graphql/schema
echo "type Z { z: String }" >graphql/schema/zzz.graphql
echo "type A { a: String }" >graphql/schema/aaa.graphql
export DIRECTORY="graphql/schema"
run_script build_schema.sh
assert_eq "$forward_schema" "$(cat schema.graphql)" "file creation order does not affect the concatenation"
assert_eq "$forward_hash" "$(exported_hash)" "file creation order does not affect the hash"
assert_eq "type A { a: String }
type Z { z: String }" "$(cat schema.graphql)" "concatenates in sorted path order"
cleanup_sandbox

# The hash must depend on schema content only — not on the commit it was built
# from — or a re-publish would be triggered by every new commit.
new_sandbox
mkdir -p graphql/schema
echo "type Query { ping: String }" >graphql/schema/query.graphql
export DIRECTORY="graphql/schema"
export CIRCLE_SHA1="1111111111111111111111111111111111111111"
run_script build_schema.sh
sha_one_hash="$(exported_hash)"
cleanup_sandbox

new_sandbox
mkdir -p graphql/schema
echo "type Query { ping: String }" >graphql/schema/query.graphql
export DIRECTORY="graphql/schema"
export CIRCLE_SHA1="2222222222222222222222222222222222222222"
run_script build_schema.sh
assert_eq "$sha_one_hash" "$(exported_hash)" "same schema under a different CIRCLE_SHA1: same hash"
cleanup_sandbox

new_sandbox
mkdir -p graphql/schema
echo "type Query { ping: String, pong: String }" >graphql/schema/query.graphql
export DIRECTORY="graphql/schema"
run_script build_schema.sh
if [ "$sha_one_hash" != "$(exported_hash)" ]; then
    pass "changed schema content: different hash"
else
    fail "changed schema content: different hash" "hash did not change"
fi
cleanup_sandbox

# A file with no trailing newline must not swallow the next file's first line.
# With plain cat the two files join mid-line, and when the join lands inside a
# comment the following type disappears from the published subgraph silently.
new_sandbox
mkdir -p graphql/schema
printf 'type A { a: String }\n# a trailing comment' >graphql/schema/aaa.graphql
printf 'type Z { z: String }\n' >graphql/schema/zzz.graphql
export DIRECTORY="graphql/schema"
run_script build_schema.sh
assert_eq 0 "$STATUS" "file without a trailing newline: exits 0"
assert_contains "$(cat schema.graphql)" "# a trailing comment
type Z { z: String }" "file without a trailing newline: does not glue onto the next file"
cleanup_sandbox

# Schema files are commonly symlinked in from a shared/vendored directory.
new_sandbox
mkdir -p graphql/schema shared
echo "type Shared { s: String }" >shared/shared.graphql
ln -s ../../shared/shared.graphql graphql/schema/shared.graphql
echo "type Query { ping: String }" >graphql/schema/query.graphql
export DIRECTORY="graphql/schema"
run_script build_schema.sh
assert_contains "$(cat schema.graphql)" "type Shared { s: String }" "follows symlinked schema files"
cleanup_sandbox

# The sort has to be locale-independent, or two executors with different locales
# hash the same schema differently: publish then republishes on every run and
# check never skips. C sorts uppercase before lowercase, en_US does not, so
# these two file names collate in opposite orders.
seed_mixed_case_schema() {
    mkdir -p graphql/schema
    echo "type Zebra { id: ID! }" >graphql/schema/Zebra.graphql
    echo "type Apple { id: ID! }" >graphql/schema/apple.graphql
    export DIRECTORY="graphql/schema"
}

new_sandbox
seed_mixed_case_schema
LC_ALL=C run_script build_schema.sh
c_hash="$(exported_hash)"
cleanup_sandbox

new_sandbox
seed_mixed_case_schema
LC_ALL=en_US.UTF-8 run_script build_schema.sh
assert_eq "$c_hash" "$(exported_hash)" "mixed-case file names hash the same under any locale"
cleanup_sandbox

# --- skipped by an earlier step ---------------------------------------------

new_sandbox
mkdir -p graphql/schema
echo "type Query { ping: String }" >graphql/schema/query.graphql
export FEDERATION_SKIP="PR targets develop, not master"
export DIRECTORY="graphql/schema"
run_script build_schema.sh
assert_eq 0 "$STATUS" "FEDERATION_SKIP set: exits 0"
assert_eq "" "$(cat "$BASH_ENV")" "FEDERATION_SKIP set: exports nothing"
assert_eq 0 "$([ -f schema.graphql ] && echo 1 || echo 0)" "FEDERATION_SKIP set: builds no schema"
cleanup_sandbox

# --- failure modes ----------------------------------------------------------

new_sandbox
export DIRECTORY="graphql/missing"
run_script build_schema.sh
assert_eq 1 "$STATUS" "missing directory: exits non-zero"
assert_contains "$STDERR" "graphql/missing" "missing directory: names the directory"
assert_eq "" "$(cat "$BASH_ENV")" "missing directory: exports nothing"
cleanup_sandbox

new_sandbox
mkdir -p graphql/schema
export DIRECTORY="graphql/schema"
run_script build_schema.sh
assert_eq 1 "$STATUS" "no .graphql files: exits non-zero"
assert_contains "$STDERR" "graphql/schema" "no .graphql files: names the directory"
cleanup_sandbox

new_sandbox
mkdir -p graphql/schema
: >graphql/schema/empty.graphql
export DIRECTORY="graphql/schema"
run_script build_schema.sh
assert_eq 1 "$STATUS" "only empty .graphql files: exits non-zero"
cleanup_sandbox

finish
