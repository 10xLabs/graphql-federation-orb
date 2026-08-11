#!/bin/bash
# SUPERGRAPH, ENVIRONMENT and DEVOPS_CONFIG_BUCKET are supplied by the step's
# environment block and the consumer's CircleCI context.
# shellcheck disable=SC2153
set -eo pipefail

supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"
found=false

for i in {1..8}; do
    sleep 5
    echo "checking for supergraph attempt $i"
    if ! rover supergraph fetch "$supergraph" >supergraph.graphql; then
        echo "rover supergraph fetch failed on attempt $i" >&2
        continue
    fi
    if grep -q "$CIRCLE_SHA1" supergraph.graphql; then
        found=true
        break
    fi
done

if [ "$found" != true ]; then
    echo "Failed to find $CIRCLE_SHA1 in the composed supergraph after 8 attempts" >&2
    exit 1
fi

echo "Found supergraph with $CIRCLE_SHA1"

# set -e makes a failed upload fail the job; the step must not report success
# while the gateway is still serving the previous supergraph.
aws s3 cp supergraph.graphql "s3://$DEVOPS_CONFIG_BUCKET/$supergraph/supergraph.graphql"
