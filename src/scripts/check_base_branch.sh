#!/bin/bash
set -eo pipefail

# This step is the one that normally *sets* FEDERATION_SKIP, so it only sees the
# variable when something outside the orb set it — a job that wants the whole
# command to no-op. Honour it here too, or this step still reaches for the
# GitHub API and fails on a PR build with no GITHUB_PAT.
if [ -n "${FEDERATION_SKIP:-}" ]; then
    echo "Skipping (${FEDERATION_SKIP})."
    exit 0
fi

# Nothing to gate on a non-PR build, or when no base branch was configured.
if [ -z "$CIRCLE_PULL_REQUEST" ] || [ -z "$BASE_BRANCH" ]; then
    exit 0
fi

# CIRCLE_PULL_REQUEST is https://github.com/<org>/<repo>/pull/<number>
pull_request="${CIRCLE_PULL_REQUEST:19}"
api_url="https://api.github.com/repos/${pull_request%/pull/*}/pulls/${pull_request##*/}"

if ! response=$(curl -sS --fail --retry 3 -H "Authorization: token ${GITHUB_PAT}" "$api_url"); then
    echo "Failed to query the GitHub API at ${api_url}." >&2
    echo "Check that GITHUB_PAT is set in this job's context and can read the repository." >&2
    exit 1
fi

base_branch=$(echo "$response" | jq -r '.base.ref')
if [ -z "$base_branch" ] || [ "$base_branch" = "null" ]; then
    echo "The GitHub API response for ${api_url} contained no .base.ref." >&2
    exit 1
fi

# A flag rather than `circleci-agent step halt`: this runs inside a reusable
# command, and halting would also kill whatever steps the consumer put after it
# in their own job. Every later step in this command reads the flag and no-ops.
# shellcheck disable=SC2153
if [ "$base_branch" != "$BASE_BRANCH" ]; then
    reason="PR targets ${base_branch}, not ${BASE_BRANCH}"
    echo "${reason}. Skipping the rest of this command."
    # Quoted, because CircleCI sources BASH_ENV and the reason contains spaces.
    printf "export FEDERATION_SKIP='%s'\n" "$reason" >>"$BASH_ENV"
    exit 0
fi
