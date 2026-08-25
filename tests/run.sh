#!/bin/bash
# Runs every tests/test_*.sh file and reports an aggregate result.
set -uo pipefail

cd "$(dirname "$0")" || exit 1

failed=0
for test_file in test_*.sh; do
    echo "== $test_file"
    if bash "$test_file"; then
        :
    else
        failed=$((failed + 1))
    fi
done

echo
if [ "$failed" -eq 0 ]; then
    echo "All test files passed."
    exit 0
fi

echo "$failed test file(s) failed."
exit 1
