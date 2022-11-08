#!/bin/bash
files=$(git diff --name-only HEAD~1..HEAD "$DIRECTORY")
if [ -n "$CIRCLE_PULL_REQUEST" ]; then
    pull_request=$(echo "https://api.github.com/repos/${CIRCLE_PULL_REQUEST:19}" | sed "s/\/pull\//\/pulls\//")
    base_branch=$(curl -s -H "Authorization: token ${GITHUB_PAT}" "$pull_request" | jq -r '.base.ref')
    files=$(git diff --name-only "HEAD..origin/$base_branch" "$DIRECTORY")
fi

if [ -z "$files" ]; then
    circleci-agent step halt
    exit 0
fi
