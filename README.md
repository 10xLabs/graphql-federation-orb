# graphql-federation orb

[![CircleCI Build Status](https://circleci.com/gh/10xLabs/graphql-federation-orb.svg?style=shield "CircleCI Build Status")](https://circleci.com/gh/10xLabs/graphql-federation-orb) [![CircleCI Orb Version](https://badges.circleci.com/orbs/nexbus/graphql-federation.svg)](https://circleci.com/orbs/registry/orb/nexbus/graphql-federation) [![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/10xLabs/graphql-federation-orb/master/LICENSE)

A CircleCI orb, published as **`nexbus/graphql-federation`**, that wraps [Apollo
Rover](https://www.apollographql.com/docs/rover/) to check and publish GraphQL
subgraph schemas into a federated supergraph, then uploads the composed
supergraph to S3 for the gateway to consume.

## Usage

```yaml
version: 2.1

orbs:
  graphql-federation: nexbus/graphql-federation@3.0.0

workflows:
  federation:
    jobs:
      - graphql-federation/check:
          base_branch: master
          supergraph: nexbus-router
          directory: internal/api/admin/graphql/schema
          context: [my-context]
          filters:
            branches:
              ignore: master
      - graphql-federation/publish:
          supergraph: nexbus-router
          directory: internal/api/admin/graphql/schema
          context: [my-context]
          filters:
            branches:
              only: master
```

`subgraph` defaults to `$CIRCLE_PROJECT_REPONAME`, and `directory` to
`graphql/schema`. The `check` and `publish` commands are also usable directly
inside your own jobs.

### Environment

These come from the CircleCI context attached to the job, not from orb
parameters:

| Variable | Used by | Purpose |
| --- | --- | --- |
| `<SUPERGRAPH>_APOLLO_KEY` | both | Apollo API key. The name is the supergraph truncated to 27 chars, `-`→`_`, uppercased. |
| `ENVIRONMENT` | both | The Apollo variant, e.g. `stag` / `prod`. |
| `DOMAIN_NAME` | `publish` | Host suffix for the subgraph routing URL. |
| `DEVOPS_CONFIG_BUCKET` | `publish` | S3 bucket the composed supergraph is uploaded to. |
| AWS credentials | `publish` | For that upload. |
| `GITHUB_PAT` | `check` | Reads the PR's base branch for the `base_branch` guard. |

### Change detection

Both jobs hash the concatenated schema files and compare that hash against the
subgraph Apollo currently publishes. An unchanged schema skips the check and
publish steps — but `publish` still uploads the composed supergraph, so a run
that published and then failed before the upload heals on a re-run instead of
leaving the gateway stale.

Skipping is scoped to the orb's own steps. Neither command halts the job, so
steps you put around them in your own job always run.

## Development

```bash
bash tests/run.sh                                  # script test suite
shellcheck src/scripts/*.sh
circleci orb pack src/ | circleci orb validate -
```

Edit `src/`, never a packed `orb.yml`. See [CLAUDE.md](CLAUDE.md) for the
architecture and [CHANGELOG.md](CHANGELOG.md) for what changed.

## Releasing

Publishing is tag-driven. Merge to `master`, then create a [GitHub
Release](https://github.com/10xLabs/graphql-federation-orb/releases/new) with a
semver tag `vX.Y.Z` — only that tag pattern matches the production publish
filter. `circleci orb list nexbus | grep graphql-federation` shows the current
version.

## Contributing

[Issues](https://github.com/10xLabs/graphql-federation-orb/issues) and [pull
requests](https://github.com/10xLabs/graphql-federation-orb/pulls) welcome.
