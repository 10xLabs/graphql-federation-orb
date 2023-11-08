#!/bin/bash
if [ -n "$CIRCLE_PULL_REQUEST" ] && [ -n "$BASE_BRANCH" ]; then
    pull_request=$(echo "https://api.github.com/repos/${CIRCLE_PULL_REQUEST:19}" | sed "s/\/pull\//\/pulls\//")
    base_branch=$(curl -s -H "Authorization: token ${GITHUB_PAT}" "$pull_request" | jq -r '.base.ref')

    # shellcheck disable=SC2153
    if [ "$base_branch" != "$BASE_BRANCH" ]; then
        circleci-agent step halt
        exit 0
    fi
fi
