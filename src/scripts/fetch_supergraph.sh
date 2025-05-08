#!/bin/bash
found=false
supergraph="${SUPERGRAPH:0:27}@$ENVIRONMENT"
for i in {1..8}; do
    sleep 5
    echo "checking for supergraph attempt $i"
    rover supergraph fetch "$supergraph" >supergraph.graphql
    if grep -q "$CIRCLE_SHA1" supergraph.graphql; then
        found=true
        break
    fi
done

if [ "$found" = true ]; then
    echo "Found supergraph with $CIRCLE_SHA1"
    aws s3 cp supergraph.graphql "s3://$DEVOPS_CONFIG_BUCKET/$supergraph/supergraph.graphql"
    exit 0
fi

echo "Failed to find $CIRCLE_SHA1 in supergraph.graphql"
exit 1
