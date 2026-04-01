---
name: helm-chart-developer
description: Knows how to implement helm chart templates, to configure dependency/subchart values and verify/test templates/values. Use it when working on any helm chart related tasks.
---

# Verification

## helm lint

```
helm lint .
```

## helm template

Verify rendering
```
helm template .
```

## helm unittest

Only when helm chart implements `tests` folder, assume it's for `helm unittest` plugin and follow the below:

```sh
# Run integration snapshot test
helm unittest .

# Update snapshot after intentional changes
helm unittest . -u
```

## values.yaml Documentation

When implementing a new feature or updating an existing one in helm chart templates:

- Add or update the corresponding section in `values.yaml` with commented examples showing all valid options and their effect.
- Uncomment new fields as defaults where appropriate; leave optional/advanced fields commented out.

# Chart dependencies: obtaining configuration/values options

DO NOT read chart templates/implementation, but instead use commands below:

```shell
# get values.yaml
helm show values <REPO>/<CHART>
# get README.md
helm show readme <REPO>/<CHART>
```

When dependency repo is local reference `file://local-path`, use `/local-path` only instead for commands above.

