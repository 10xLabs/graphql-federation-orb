#!/bin/bash
# Runs first in both commands.
#
# $BASH_ENV lives for the whole job, not for one command, so the skip flags a
# command writes outlive it. A job running check/publish twice — two subgraphs,
# or a check followed by a publish — would otherwise have the second invocation
# inherit the first one's flags and no-op, silently leaving the second subgraph
# unpublished. Every command starts from a known state instead.
set -eo pipefail

{
    # GRAPHQL_FEDERATION_DISABLED is the one skip the orb reads but never
    # writes: a job-level opt-out that turns every step of the command into a
    # no-op without touching the workflow.
    if [ -n "${GRAPHQL_FEDERATION_DISABLED:-}" ]; then
        printf 'export FEDERATION_SKIP=%q\n' "GRAPHQL_FEDERATION_DISABLED is set"
    else
        printf 'export FEDERATION_SKIP=\n'
    fi
    printf 'export SCHEMA_UNCHANGED=\n'
} >>"$BASH_ENV"
