#!/bin/bash
set -eo pipefail

if [ -n "$CIRCLE_PULL_REQUEST" ]; then
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

    git fetch --quiet origin "$base_branch" 2>/dev/null || true
    if ! git rev-parse --verify --quiet "origin/${base_branch}" >/dev/null; then
        echo "Base branch origin/${base_branch} is not available in this checkout." >&2
        exit 1
    fi

    files=$(git diff --name-only "HEAD..origin/${base_branch}" -- "$DIRECTORY")
elif git rev-parse --verify --quiet HEAD~1 >/dev/null; then
    files=$(git diff --name-only HEAD~1..HEAD -- "$DIRECTORY")
else
    # First commit on the branch: nothing to diff against, treat it as changed.
    files="$DIRECTORY"
fi

if [ -z "$files" ]; then
    echo "No changes under ${DIRECTORY}. Halting."
    circleci-agent step halt
    exit 0
fi

echo "Changed files under ${DIRECTORY}:"
echo "$files"
