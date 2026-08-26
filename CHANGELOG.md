# Changelog

All notable changes to this orb are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the orb follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.4.0] - 2026-08-26

Shipped as a minor despite removing a parameter: `skip_check_directory` had no
known users, so no consumer config is expected to break. Upgrading is still not
a no-op — read the two notes below before you bump.

### Removed

- **Action required** — the `skip_check_directory` parameter is gone from the
  `publish` job and command. A consumer config still passing it fails to compile
  with `Unexpected argument(s): skip_check_directory`. Remove it before
  upgrading; there is no replacement, because the new change detection has
  nothing to skip.
- The git-diff change check (`check_directory_changes.sh`). `publish` no longer
  reads `GITHUB_PAT`; the `check` job still needs it for the `base_branch` guard.

### Added

- Change detection now compares against Apollo instead of git. `publish` and
  `check` build the schema, hash it, fetch the published subgraph and skip the
  check and publish steps if that hash is already published. This is idempotent —
  re-running a pipeline or triggering one manually behaves the same as the
  original run — and it self-heals drift: a failed publish or a manual `rover`
  run no longer leaves the gateway permanently stale behind a "no changes" skip.
- On the unchanged path `publish` still fetches and uploads the composed
  supergraph, skipping only the wait for `CIRCLE_SHA1` to appear. Without this,
  a run that published its subgraph and then died before the upload could never
  recover: the next run would match the hash, skip, and go green while S3 kept
  serving the pre-publish supergraph.
- The SHA marker type carries a second field, `schemaHash`, alongside the
  existing `value` (`CIRCLE_SHA1`).
- `tests/` — a dependency-free script test suite, run in CI by the `script-tests`
  job, which gates the dev publish.

### Fixed

- A failed `aws s3 cp` in the supergraph upload no longer exits 0. The job used
  to report success while the gateway kept serving the previous supergraph.
- A failed `rover supergraph fetch` is no longer treated as a successful poll.
- An unset `<SUPERGRAPH>_APOLLO_KEY` now fails at the "Set Apollo API key" step,
  naming the variable, instead of exporting an empty `APOLLO_KEY` and surfacing
  as an opaque Rover auth error two steps later.
- A missing schema directory, or one with no non-empty `*.graphql` files, now
  fails instead of running `rover subgraph check` against a schema containing
  only the marker type.
- All scripts run under `set -eo pipefail`, and `curl` calls use
  `--fail --retry 3`.
- The PascalCase marker name is derived with `awk` rather than GNU-only
  `sed -r`/`\U`, so it is correct on non-GNU executors.
- `*.graphql` files are concatenated in sorted path order, so the schema hash
  does not depend on `find` traversal order. The sort runs under `LC_ALL=C` and
  the traversal uses `find -L`, so the hash depends on neither the executor's
  locale nor whether a schema file is a symlink.
- Schema files are concatenated with `awk 1` rather than `cat`, so a file with no
  trailing newline can no longer be glued onto the next file's first line — a
  join landing inside a comment used to drop the following type silently.
- `install_aws_cli.sh` unpacks into a temp directory. It used to unzip into the
  working directory and then `rm -rf aws`, which deleted a consumer repository's
  own `aws/` directory when the command ran inside their job.
- `APOLLO_KEY` is written to `$BASH_ENV` with `printf %q`, so a key containing a
  space, `$`, backtick, quote or `#` survives CircleCI sourcing that file. A
  supergraph whose name derives an invalid variable name now reports that,
  instead of dying on a bash "bad substitution".

### Changed

- Both commands start with a "Reset federation state" step. `$BASH_ENV` lives
  for the whole job, so a job running check/publish twice used to have the second
  invocation inherit the first one's skip flags and no-op, silently leaving the
  second subgraph unpublished.
- `GRAPHQL_FEDERATION_DISABLED` — set it in a job's environment to no-op every
  step of the command. Read by the orb, never written by it.
- **Action required for direct command users** — neither command calls
  `circleci-agent step halt` any more. Skipping is carried between the orb's own
  steps through `$BASH_ENV` (`FEDERATION_SKIP`, `SCHEMA_UNCHANGED`), so a
  consumer running `check`/`publish` inside their own job keeps the steps they
  put after it. Previously a skip terminated the whole job, silently dropping
  their tests and artifacts. The `check` and `publish` *jobs* behave as before.
- The AWS CLI is installed after the publish step rather than before the change
  check. It is still installed on the unchanged path, because that path uploads.
- `install_rover_cli.sh` uses `ln -sf`, and `install_aws_cli.sh` uses
  `--update`, so both are idempotent across re-runs.

## [2.3.0] and earlier

See the [GitHub releases](https://github.com/10xLabs/graphql-federation-orb/releases).
