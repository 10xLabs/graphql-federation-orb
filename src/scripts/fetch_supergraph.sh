#!/bin/bash
rover supergraph fetch "$SUPERGRAPH@$ENVIRONMENT" > supergraph.graphql

aws s3 cp supergraph.graphql "s3://$DEVOPS_CONFIG_BUCKET/$SUPERGRAPH/supergraph.graphql"
