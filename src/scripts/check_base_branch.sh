#!/bin/bash
set -eo pipefail

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

# shellcheck disable=SC2153
if [ "$base_branch" != "$BASE_BRANCH" ]; then
    echo "PR targets ${base_branch}, not ${BASE_BRANCH}. Halting."
    circleci-agent step halt
    exit 0
fi
