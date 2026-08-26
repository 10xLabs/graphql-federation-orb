# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

CircleCI orb published as **`nexbus/graphql-federation`** (repo name has the `-orb` suffix, the orb name does not). It wraps Apollo Rover to check and publish GraphQL subgraph schemas into a federated supergraph, then uploads the composed supergraph to S3 for the gateway to consume. Consumers are the 10xLabs `-handler` / `-projector` repos.

## Commands

```bash
circleci orb pack src/ > orb.yml            # pack unpacked source into the single orb.yml that ships
circleci orb pack src/ | circleci orb validate -   # validate the packed orb
circleci config validate .circleci/config.yml
shellcheck src/scripts/*.sh tests/*.sh      # CI runs circleci/shellcheck orb over both trees
yamllint .                                  # config in .yamllint (relaxed, 200 col)
circleci orb list nexbus | grep graphql-federation   # latest published version
```

```bash
bash tests/run.sh                           # script test suite (no deps beyond bash/git/jq)
```

Verification is: `tests/run.sh` + shellcheck + yamllint + `orb-tools/review`, plus `install-tests`, `orb-render-check` and `orb-command-smoke` in `.circleci/test-deploy.yml`. `orb-command-smoke` is the only job that runs the *packed* orb — it sets `FEDERATION_SKIP` so every step no-ops, which keeps it hermetic while still proving the inlined scripts parse and run.

CI's `shellcheck/check` job passes no flags and fails on SC1091, so `.shellcheckrc` sets `external-sources=true` and `source-path=SCRIPTDIR`. Run `shellcheck` with no flags to reproduce CI exactly — `-x` on the command line hides the difference.

`tests/` runs `src/scripts/*.sh` directly — the same bytes that get inlined at pack time — with `curl`, `rover`, `aws`, `circleci-agent` and `sleep` replaced by recording stubs on `PATH` (`tests/helpers.bash`). It runs on macOS and Linux, so keep the scripts portable: no GNU-only `sed -r`/`\U`, and pick between `sha256sum` and `shasum -a 256`.

## Release

Publishing is tag-driven, not merge-driven. Merge to `master`, then create a GitHub Release with a semver tag `vX.Y.Z`. Only that tag pattern matches the production `orb-tools/publish` filter in `.circleci/test-deploy.yml`.

## Architecture

### Packed vs unpacked source

`src/` is the unpacked orb tree; directory names become orb keys — `src/commands/publish.yml` → `commands.publish`, `src/jobs/`, `src/executors/`, `src/examples/`. `src/@orb.yml` is the tree root (version/description/display). Never hand-edit a packed `orb.yml`; edit `src/` and repack.

Bash lives in `src/scripts/*.sh` and is inlined at pack time via `<<include(scripts/x.sh)>>`. **Scripts take no arguments** — orb parameters are passed by declaring them in the step's `environment:` block, so every script reads env vars (`DIRECTORY`, `SUPERGRAPH`, `SUBGRAPH`, `BASE_BRANCH`). Adding a parameter means wiring it in both the job and the command, and reading it as an env var in the script.

Jobs are thin: `checkout` + call the matching command. Real logic belongs in the command + scripts so consumers can also use the commands inside their own jobs.

### Two-pipeline dev kit

1. `.circleci/config.yml` (`setup: true`) — lint, review, pack, shellcheck, then publish a **dev** version `dev:<pipeline.git.revision>`, then `orb-tools/continue` triggers pipeline 2.
2. `.circleci/test-deploy.yml` — imports `nexbus/graphql-federation@dev:<<pipeline.git.revision>>` (the version just published), runs integration jobs, and promotes to production only on a `vX.Y.Z` tag.

So an integration test always exercises the freshly packed orb, never a stale registry version.

### Runtime flow (`publish` job)

1. Install Rover CLI.
2. **Set Apollo API key** — derives the env var name from the supergraph: truncate to 27 chars, `-`→`_`, uppercase, suffix `_APOLLO_KEY`; exports its value as `APOLLO_KEY` into `$BASH_ENV`. Fails if that variable is not in the context.
3. **Build subgraph schema** — concatenates every `*.graphql` under `directory` (`find -L`, `LC_ALL=C sort`, `awk 1`) into one `schema.graphql`, then exports `SCHEMA_HASH` (sha256 of that file) into `$BASH_ENV`.
4. **Compare published subgraph** — `rover subgraph fetch`, then exports `SCHEMA_UNCHANGED=true` if the published SDL already contains `$SCHEMA_HASH`. A failed fetch (unpublished subgraph, missing variant) proceeds rather than skipping.
5. **Check subgraph** — appends the marker type, then runs `rover subgraph check`. No-op when `SCHEMA_UNCHANGED`.
6. **Publish subgraph** — `rover subgraph publish` with routing URL `https://<supergraph with "router"→"gateway">.$DOMAIN_NAME/subgraph/<subgraph>/graphql`. No-op when `SCHEMA_UNCHANGED`.
7. Install AWS CLI.
8. **Fetch supergraph** — polls `rover supergraph fetch` up to 8× (5s apart) until the composed supergraph contains `$CIRCLE_SHA1`, then `aws s3 cp` it to `s3://$DEVOPS_CONFIG_BUCKET/<supergraph>@<env>/supergraph.graphql`. Fails if the SHA never appears or the upload fails.

The `check` job is steps 1–5, plus an upfront guard for the PR base branch.

### Skipping is a flag, never a halt

No script calls `circleci-agent step halt`. Both skip paths write a variable to `$BASH_ENV` and every later step in the command reads it and no-ops:

- `FEDERATION_SKIP=<reason>` — set by `check_base_branch.sh` when the PR does not target `base_branch`. Everything after it, installs included, is a no-op.
- `SCHEMA_UNCHANGED=true` — set by `compare_published_schema.sh`. Skips **only** steps 5 and 6.

`$BASH_ENV` lives for the whole job, not for one command, so both flags outlive the command that wrote them. **Step 0 of both commands is `reset_state.sh`**, which clears them. Without it a job running check/publish twice — two subgraphs, or a check followed by a publish — has the second invocation inherit the first one's flags and no-op, silently leaving the second subgraph unpublished. That is the same class of silent skip this whole design exists to remove, so do not drop the reset step, and do not add a flag that `reset_state.sh` does not clear.

`GRAPHQL_FEDERATION_DISABLED` is the one skip the orb reads but never writes: a job-level opt-out that `reset_state.sh` translates into `FEDERATION_SKIP`. It is what makes `orb-command-smoke` hermetic.

Two reasons, both load-bearing. A halt terminates the whole job, and the commands are documented as usable inside a consumer's own job, so a skip would silently drop their tests and artifacts. And step 8 must still run on the unchanged path: the hash is compared against *Apollo*, never against S3, so a run that published its subgraph and then died before the upload would otherwise match the hash on every later run, go green, and leave the gateway on the pre-publish supergraph forever. On that path `fetch_supergraph.sh` skips the `CIRCLE_SHA1` wait — nothing new is being composed — and uploads what Apollo currently serves.

`tests/helpers.bash` keeps a `circleci-agent` stub purely so `assert_not_halted` can prove this.

### The marker type, and why change detection works this way

Step 5 appends a marker to `schema.graphql` carrying two load-bearing values:

```graphql
input SHA<PascalCaseSubgraph>Input {
    value: String = "$CIRCLE_SHA1"
    schemaHash: String = "$SCHEMA_HASH"
}
```

- `value` is what step 8 greps for. It is the only way to tell whether Apollo has finished composing *this* revision rather than a previous one.
- `schemaHash` is what step 4 greps for on the *next* run. Step 4 matches the bare 64-hex string, not the surrounding GraphQL, so it survives any reformatting Apollo applies to a fetched subgraph — the docs do not promise `rover subgraph fetch` returns byte-verbatim SDL.

Don't remove either field.

Because the hash is computed before the marker is appended, it depends on schema content alone — two commits with identical schemas produce the same hash and the second one skips. Four details in `build_schema.sh` exist to keep that true, and all four are load-bearing:

- `LC_ALL=C sort` — `find` traversal order is not stable across machines, and locale-aware collation orders mixed-case and punctuated file names differently, so an unpinned sort would make two executors hash the same schema differently and republish on every build.
- `find -L` — follows symlinked schema files, which repos use to share types. `-type f` alone drops them, silently shrinking the published schema.
- `awk 1` instead of `cat` — guarantees a trailing newline per file. Plain `cat` glues a file that lacks one onto the next file's first line, and when the join lands inside a `#` comment or a `"""` description the following type disappears with no error.
- The hash is taken before the marker is appended.

This replaced a git-diff check (removed in 2.4.0). The comparison is against *Apollo*, not against git, which makes it idempotent — re-runs and manual triggers behave identically — and self-healing: if a publish failed or someone ran `rover` by hand, git would say "no change" while the gateway stayed stale, whereas the hash comparison notices and republishes. The unconditional S3 upload described above covers the one drift the hash comparison cannot see, since S3 is not what the hash is compared against.

Known gap: a change that alters only the routing URL (i.e. `DOMAIN_NAME`) does not republish, because the hash covers schema content only. Folding the routing URL in is not viable — the `check` command has no `DOMAIN_NAME`, so its hash would permanently disagree with `publish`'s.

### Naming conventions baked into the scripts

- Supergraph graph id is always truncated to 27 chars (`${SUPERGRAPH:0:27}`) — Apollo graph-id limit. Both the Apollo key lookup and the graph ref use the same truncation, so they must stay in sync.
- Graph ref is `<truncated-supergraph>@$ENVIRONMENT` — the variant is the deploy environment, injected by the consumer's CircleCI context.
- Subgraph defaults to `$CIRCLE_PROJECT_REPONAME` when the `subgraph` parameter is empty.

### Env vars supplied by the consuming project's CircleCI context

`ENVIRONMENT`, `DOMAIN_NAME`, `DEVOPS_CONFIG_BUCKET`, `<SUPERGRAPH>_APOLLO_KEY`, plus AWS credentials for the S3 upload. `GITHUB_PAT` is needed only by the `check` job, for the `base_branch` guard — `publish` stopped using it in 2.4.0. These are *not* orb parameters — adding a new one is a breaking change for consumers.

`GRAPHQL_FEDERATION_DISABLED` is an optional job-level opt-out, read but never written by the orb.

`SCHEMA_HASH`, `SCHEMA_UNCHANGED` and `FEDERATION_SKIP` are not context variables: the scripts write them to `$BASH_ENV` for later steps in the same job. `APOLLO_KEY` is written there too, with `printf %q` — CircleCI sources that file, so an unquoted key containing a space, `$`, backtick or `#` would be truncated or would run a substitution.
