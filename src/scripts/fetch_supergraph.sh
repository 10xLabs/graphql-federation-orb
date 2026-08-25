#!/bin/bash
# SUPERGRAPH, ENVIRONMENT and DEVOPS_CONFIG_BUCKET are supplied by the step's
# environment block and the consumer's CircleCI context. FEDERATION_SKIP comes
# from check_base_branch.sh and SCHEMA_UNCHANGED from
# compare_published_schema.sh, both via BASH_ENV.
# shellcheck disable=SC2153
set -eo pipefail

if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"

# The upload runs even when nothing was published. That is what makes a re-run
# heal the gateway: if a previous run published the subgraph and then died
# before the upload, S3 still holds the pre-publish supergraph, and the schema
# hash comparison alone would never notice. Nothing new is being composed on
# that path, though, so there is no CIRCLE_SHA1 to wait for.
if [ "${SCHEMA_UNCHANGED:-}" = true ]; then
    echo "Schema unchanged; uploading the currently composed supergraph."
    require_sha=false
else
    require_sha=true
fi

found=false

for i in {1..8}; do
    if [ "$require_sha" = true ]; then
        sleep 5
    fi
    echo "checking for supergraph attempt $i"
    if ! rover supergraph fetch "$supergraph" >supergraph.graphql; then
        echo "rover supergraph fetch failed on attempt $i" >&2
        continue
    fi
    if [ "$require_sha" != true ] || grep -q "$CIRCLE_SHA1" supergraph.graphql; then
        found=true
        break
    fi
done

if [ "$found" != true ]; then
    if [ "$require_sha" = true ]; then
        echo "Failed to find $CIRCLE_SHA1 in the composed supergraph after 8 attempts" >&2
    else
        echo "Failed to fetch the composed supergraph after 8 attempts" >&2
    fi
    exit 1
fi

if [ "$require_sha" = true ]; then
    echo "Found supergraph with $CIRCLE_SHA1"
fi

# set -e makes a failed upload fail the job; the step must not report success
# while the gateway is still serving the previous supergraph.
aws s3 cp supergraph.graphql "s3://$DEVOPS_CONFIG_BUCKET/$supergraph/supergraph.graphql"
