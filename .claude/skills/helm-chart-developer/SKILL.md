---
name: helm-chart-developer
description: Use when user need work on helm chart related tasks, analyze, implement, generate, render, verify, test helm chart templates, manage dependencies/subcharts and configure chart values.
---

# Verification / Testing

When executing commands below, and there are other value files in the chart folder,
When there are multiple files in chart folder, ask what file to use. values-ci.yaml is usually used for CI workflows.

```shell
# Linting
helm lint . [-f values-file.yaml]

# Verify rendering
helm template . [-f values-file.yaml]
```

## helm unittest

When helm chart implements `tests` folder, assume it's for `helm unittest` plugin and follow the below:

```shell
# Run integration snapshot test
helm unittest .

# Update snapshot after intentional changes
helm unittest . -u
```

When you set values in asserts, don't use dot-notation keys but use nested YAML structures.

### Adding new tests

Ask what should be tested and what type is preferred:
- type: snapshots | explicit inline assertions
- what to test: what exactly to test

# Documentation

Always keep relevant documentation in sync with all changes.

## values.yaml

Must always be in sync with templates implementation.
Add or update the corresponding section in `values.yaml` with commented examples showing all valid options and their effect.
Uncomment new fields as defaults where appropriate; leave optional/advanced fields commented out.

## README.md

Explains key features of helm chart with very brief example for end-user.

Ask if particular feature should be also described in README.md.

Full configuration examples are preferred to be maintained using unittest snapshots tests in files example_FEATURE_tests.yaml
to make sure they are testable and won't get out of sync. Value files are in tests/examples folder and linked by clickable links from README.md.

## DEVELOPMENT.md

Used by maintainer / developer.
Explains concepts, implementation details, decisions.

## Versioning

Use semantic versioning.

# Dependencies

## Adding new dependency

When adding new dependency, you know exact:
- repository
- version
- name
- alias (optional)

## Obtaining configuration/values options

Prefer the below to understand configuration options:

```shell
# get values.yaml
helm show values <REPO>/<CHART>
# get README.md
helm show readme <REPO>/<CHART>
```

When dependency repo is local reference `file://local-path`, use `/local-path` only instead in commands above.

# Tools

## helm unittest

https://github.com/helm-unittest/helm-unittest

```
helm plugin install https://github.com/helm-unittest/helm-unittest.git --version VERSION
```