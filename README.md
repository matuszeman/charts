# Helm Repository

## Get started

Add this repository to Helm.

```
helm repo add matuszeman https://matuszeman.github.io/charts/
```

Update repositories
```
helm repo update
```

List charts
```
helm search repo matuszeman
```

---

## idp-app

A general-purpose Helm chart for deploying any Kubernetes workload — Deployment, StatefulSet, Job, or CronJob — without writing boilerplate. It is designed to be used directly or as a dependency inside an umbrella chart.

### Why idp-app?

Most Kubernetes apps need the same set of resources: a Deployment, a Service, ConfigMaps, Secrets, Ingress, HPA, PDB, ServiceMonitor, ServiceAccount. Writing and maintaining all of these per-app is repetitive and error-prone. idp-app provides a single, well-tested chart that covers all of these resources behind a clean values interface.

Key benefits:

- **[One chart for all workload types](charts/idp-app/tests/values/examples/workload-types.yaml)** — flip `deployment.enabled`, `job.enabled`, or `cronjob.enabled` to change the workload kind without touching templates.
- **[Multi-cluster aware](charts/idp-app/tests/values/examples/multi-cluster.yaml)** — global cluster config (`global.idpAppConfig`) centralises registry URLs, domain suffixes, node pools, and gateway definitions so individual charts stay cluster-agnostic.
- **[Shared defaults](charts/idp-app/tests/values/examples/shared-defaults.yaml)** — `global.idpAppConfig.defaults` sets chart-wide defaults (image registry, pull policy, ingress config, security context, …) that every chart instance inherits and can override.
- **[Config management built in](charts/idp-app/tests/values/examples/config-management.yaml)** — the `configs` block creates ConfigMaps, Secrets, ExternalSecrets (AWS Secrets Manager), and SealedSecrets, then mounts them into containers via `configDirs`, `configFiles`, or `env` — all validated at template time.
- **[Multiple deployments from one release](charts/idp-app/tests/values/examples/multi-deployment.yaml)** — `deployment.multi` spins up several Deployments or StatefulSets from a single Helm release, each with its own container overrides, so related workloads (API, worker, scheduler) share config without duplicating charts.
- **[Automatic rolling restarts on config changes](charts/idp-app/tests/values/examples/rolling-restarts.yaml)** — set `restartPodOnUpdate: PodAnnotation` or `NameSuffix` on any config to have pods restart automatically when content changes, without manual annotation management.

### Built-in reliability features

| Feature                       | Value key                   |
|-------------------------------|-----------------------------|
| Pod Disruption Budget         | `podDisruptionBudget`       |
| Horizontal Pod Autoscaler     | `autoscaling`               |
| Topology spread (zone + node) | `topologySpreadConstraints` |
| Prometheus ServiceMonitor     | `prometheus.serviceMonitor` |

### Example

```yaml
appName: my-app
appVersion: "1.0.0"

deployment:
  enabled: true

service:
  enabled: true
  port: 80

containers:
  app:
    image: my-app
    imageTag: "1.0.0"
    containerPort: 8080
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
```

For more complete examples see [`charts/idp-app/tests/values/examples/`](charts/idp-app/tests/values/examples/).
