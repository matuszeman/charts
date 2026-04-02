# Testing

Make sure to keep also integration tests in folder [examples](../../examples) which has idp-app as dependency in sync.

# Template Structure

The chart is composed of composable named templates in `templates/_*.tpl`:

- `_helpers.tpl` — Name/label helpers; `idp-app.clusterConfig` and `idp-app.clusterConfigMapValue` resolve cluster-specific values from `global.idpAppConfig.clusters`
- `_pod.tpl` — `idp-app.podTemplate` builds the pod spec; assembles volumes from `configs` and `volumes`, applies `nodePool`, `topologySpreadConstraints`, etc.
- `_container.tpl` — `idp-app.container` builds individual container specs; resolves image repos from `global.idpAppConfig.imageRepositories`, handles `configDirs`/`configFiles`/`volumeMounts`/`volumeFiles` and `env` config references (auto-detects ConfigMap vs Secret type)
- `_configs.tpl` — Four helpers:
  - `idp-app.configName` — computes the final resource name (appends hash suffix for `NameSuffix` strategy)
  - `idp-app.configHash` — computes a content hash from `content`, `awsSecret.arn`+`versionId`, `sealedSecret.encryptedData`, or manual `valuesHash`
  - `idp-app.configsPodAnnotations` — emits pod annotations for `PodAnnotation` restart strategy
  - `idp-app.isConfigUsedInContainersVolumeMounts` — checks whether a config key is referenced by any container's `configDirs`/`configFiles` (controls whether a volume is emitted in the pod spec)

# Key Values Patterns

**Global cluster config** (`global.idpAppConfig`) is shared across all chart instances in a release. It defines:
- `imageRepositories` — named aliases (e.g. `private`, `public`) resolved to actual registry URLs
- `clusters.<name>` — per-cluster config for domains, nodePools, httpGateways, app-specific settings
- `defaults` — chart-wide defaults for `imageRepository`, `imagePullPolicy`, `securityContext`, ingress, httpRoute, configs

**`imagePullPolicy` precedence** — `global.idpAppConfig.defaults.imagePullPolicy` takes priority over the per-container `imagePullPolicy` field. The global default is `IfNotPresent` when not set. To use a different policy on a specific container, do not set the global default.

**`configs`** — manages ConfigMaps/Secrets. Sources: `content` (inline), `fromConfigMap`/`fromSecret` (existing resources), `awsSecret` (External Secrets Operator), `sealedSecret`. Referenced in containers via:
- `configDirs` — mount whole config as a directory
- `configFiles` — mount individual files from a config
- `env.<VAR>.config` — inject a single key as an environment variable; the type (ConfigMap or Secret) is resolved automatically

Set `templated: true` on a config to enable Go template rendering of its `content` values.

When any config uses `awsSecret`, a `SecretStore` resource is automatically created (one per release, named `<fullname>-config-secretsmanager`). It uses the `aws_region` from the active cluster config and authenticates via the chart's `ServiceAccount` using IRSA.

**`restartPodOnUpdate`** — controls how config content changes trigger pod restarts:
- `PodAnnotation` — adds a `config-hash-<key>` annotation to the pod template; triggers rolling restart when content changes
- `NameSuffix` — appends a short content hash to the ConfigMap/Secret name; any name change forces Kubernetes to re-mount and restart pods
- `fromConfigMap`/`fromSecret` sources require a manual `valuesHash` for either strategy to work

**`volumes`** — mounts arbitrary volumes. PVCs without `claimName` are auto-created by `pvc.yaml` (one per Deployment in `deployment.multi`). PVCs with `claimName` reference an existing PVC.

**`deployment.kind`** — `Deployment` (default) or `StatefulSet`. StatefulSet is intended for workloads that need stable network identities or ordered rolling updates. Pair with `headlessService` for DNS-based pod discovery (`pod-0.<svc>`, `pod-1.<svc>`, …).

**`deployment.strategy`** — applies to Deployments only. `type: RollingUpdate` (default) supports `rollingUpdate.maxUnavailable`/`maxSurge`. `type: Recreate` terminates all pods before starting new ones (useful when `ReadWriteOnce` PVCs are in use).

**`deployment.staticIps`** — when set, skips creating a Deployment and instead creates an `EndpointSlice` pointing to the listed IPs. Useful for routing Kubernetes Service traffic to off-cluster backends.

**`deployment.multi`** — creates multiple Deployments/StatefulSets from one chart release. Each key becomes a name suffix; `containers` at the multi level deep-merges over the top-level `containers`.

**`resourceNameSuffix`** — used when deploying multiple `idp-app` instances in the same Helm release to avoid resource name collisions.

**`headlessService`** — creates a headless Service (`clusterIP: None`). Required for StatefulSet pod DNS (`pod-0.<svc>.<ns>.svc.cluster.local`).

**`enableServiceLinks`** — defaults to `false` to suppress the automatic injection of environment variables for every Service in the namespace, which reduces startup noise and avoids variable name conflicts in larger clusters.

**`debug`** — when `true`, all template output is suppressed. Useful for inspecting resolved values via `helm template --debug` without rendering any Kubernetes resources.
