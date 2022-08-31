#!/bin/bash
files=$(git diff --name-only HEAD~1..HEAD "$DIRECTORY")

if [ -z "$files" ]; then
    circleci-agent step halt
    exit 0
fi
