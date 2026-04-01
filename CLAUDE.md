# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Testing / verification

```
cd charts/idp-app
```

### helm template using values-ci.yaml

```sh
helm template . -f values-ci.yaml
```

### helm unit test

Run tests for a chart (from within the chart directory):
```sh
helm unittest .
```

Update snapshots after intentional changes:
```sh
helm unittest . -u
```

Run a single test file:
```sh
helm unittest . -f tests/deployment_test.yaml
```

### Integration testing

In `/tests/test` folder:


## values.yaml Documentation

When implementing a new feature or updating an existing one in helm chart:

- Add or update the corresponding section in `values.yaml` with commented examples showing all valid options and their effect.
- Uncomment new fields as defaults where appropriate; leave optional/advanced fields commented out.
- Keep `values-ci.yaml` as the authoritative functional example — it should exercise all features that have tests.

## Versioning

Use semantic versioning.

Always bump the version when:
* major version - after breaking changes - incompatible with previous version, when user must update their values.yaml to get same behaviour, or when removing some features.
* minor version - after implementing new feature
* patch version - after fixing a bug

## Architecture

### Charts

**`charts/idp-app`** — General-purpose base Helm chart for deploying any Kubernetes workload (Deployment, StatefulSet, Job, CronJob). Intended to be used as a dependency or directly.

### idp-app Template Structure

The chart is composed of composable named templates in `templates/_*.tpl`:

- `_helpers.tpl` — Name/label helpers; `idp-app.clusterConfig` and `idp-app.clusterConfigMapValue` resolve cluster-specific values from `global.idpAppConfig.clusters`
- `_pod.tpl` — `idp-app.podTemplate` builds the pod spec; assembles volumes from `configs` and `volumes`, applies `nodePool`, `topologySpreadConstraints`, etc.
- `_container.tpl` — `idp-app.container` builds individual container specs; resolves image repos from `global.idpAppConfig.imageRepositories`, handles `configDirs`/`configFiles`/`volumeMounts`/`volumeFiles`
- `_configs.tpl` — Config name/hash logic; controls how config changes trigger pod restarts (`PodAnnotation` or `NameSuffix` strategy via `restartPodOnUpdate`)

### Key Values Patterns

**Global cluster config** (`global.idpAppConfig`) is shared across all chart instances in a release. It defines:
- `imageRepositories` — named aliases (e.g. `private`, `public`) resolved to actual registry URLs
- `clusters.<name>` — per-cluster config for domains, nodePools, httpGateways, app-specific settings
- `defaults` — chart-wide defaults for ingress, httpRoute, configs, imagePullPolicy

**`configs`** — manages ConfigMaps/Secrets. Sources: `content` (inline), `fromConfigMap`/`fromSecret` (existing resources), `awsSecret` (External Secrets), `sealedSecret`. Referenced in containers via `configDirs` (whole dir mount) or `configFiles` (individual file mounts).

**`volumes`** — mounts arbitrary volumes. PVCs without `claimName` are auto-created by `pvc.yaml` (one per deployment in `deployment.multi`). PVCs with `claimName` reference an existing PVC.

**`deployment.multi`** — creates multiple Deployments/StatefulSets from one chart release. Each key becomes a name suffix; `containers` at the multi level merges/overrides the top-level `containers`.

**`resourceNameSuffix`** — used when deploying multiple `idp-app` instances in the same Helm release to avoid resource name collisions.

### Testing Conventions

- `values-ci.yaml` is the primary comprehensive test fixture; all snapshot tests reference it
- Test files in `tests/` use `values/minimum.yaml` as a base and override with specific `values/*.yaml` or inline `set:`
- Snapshot files in `tests/__snapshot__/` must be updated (`-u` flag) after intentional template changes
