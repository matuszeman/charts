---
name: helm-chart-developer
description: >
   Use when user need work on helm chart related tasks, analyze, implement, generate, render, verify,
   test helm chart templates, manage dependencies/subcharts and configure chart values.
   ALWAYS invoke this skill automatically (without waiting to be asked) at the very start of any task
   that will involve creating or modifying helm chart files (Chart.yaml, values.yaml, templates/,
   Chart.lock, charts/) — even if the user did not explicitly mention helm or this skill.
allowed-tools: Bash(helm lint *) Bash(helm template *) Bash(helm show *) Bash(helm unittest *) Bash(helm dep *)
---

# Verification / Testing

**NEVER skip local testing after making changes.** Always run lint + template render before considering the work done.

## Resolving value files for testing

When the chart is deployed via ArgoCD, read the ArgoCD Application or `argocd-app.yaml` generator
file to discover all `valueFiles` and `valuesObject` entries. Reconstruct the equivalent `-f` /
`--set` flags for local commands.

### Path resolution rules

| Path format | Resolves to |
|---|---|
| `/some/path.yaml` | `<repo-root>/some/path.yaml` (absolute within repo) |
| `./relative/path.yaml` | relative to the `argocd-app.yaml` file's directory |
| `$values/some/path.yaml` | multi-source: path in the designated values repo |

### Building the local command

1. For each entry in `valueFiles`, resolve it using the rules above and add a `-f` flag.
2. For each key in `valuesObject`, add a `--set key=value` flag (see AppSet-injected values below).
3. Run from the chart directory:

```shell
helm template . \
  -f <resolved-value-file-1> \
  -f <resolved-value-file-2> \
  --set <injected-key>=<injected-value>
```

### AppSet-injected values (`valuesObject`)

When the AppSet injects values via `valuesObject` or `templatePatch`, those keys are not present
in any file. Before running locally you must:

1. Read the AppSet manifest and find all keys set under `valuesObject` or inside `templatePatch`.
2. For each key, evaluate the Go template expression manually using the concrete app path.
   Common functions: `base`, `dir`, `trimPrefix`, `hasPrefix` — same semantics as Go `path` package.
3. Pass each resolved key via `--set key=value`.

Example: an AppSet with
`valuesObject.global.env: '{{ .path.path | dir | dir | base }}'`
for app path `project/env/dev/cluster/app` resolves to `--set global.env=dev`.

## Environment testing order

1. Test the **current environment** first (the one being changed).
2. After confirming it passes, ask the user whether to test additional environments.

When there are multiple value files in the chart folder, ask which to use.
`values-ci.yaml` is usually used for CI workflows.

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

# Umbrella chart templates — using dependency helpers

**ALWAYS use dependency chart helpers for resource names and labels when adding extra templates
to an umbrella chart.** Never write plain hardcoded names or labels.
Ask User if and why you want to bypass this requirement.

## Choosing which dependency to use helpers from

When there are multiple dependencies in `Chart.yaml`, pick the one whose helpers match the
resource being created:

1. Read `Chart.yaml` — note each dependency's `name` and `alias`.
2. Helper template names are prefixed with the chart **name** (not alias), e.g. `idp-app.fullname`.
3. Inspect available helpers
4. Use helpers from the dependency that owns the workload the extra resource belongs to.
   - The `alias` determines which key to use for `Values` in the scoped context (see below).

## Scoped context — calling helpers with aliased Values

Dependency values are namespaced under the alias key (e.g. `.Values.app`). Pass the real
Helm context deep-copied with `Values` swapped to the alias scope so that helpers — including
those using `tpl` — receive everything they need:

```yaml
{{- $ctx := set (mustDeepCopy .) "Values" .Values.<alias> -}}
```

Then call any helper with `$ctx`:

```yaml
metadata:
   name: {{ include "<chart>.fullname" $ctx }}-suffix
   labels:
      {{- include "<chart>.labels" $ctx | nindent 4 }}
```

## Keeping value references in sync with template names

Whenever a value field supports `tpl`, use the helper expression there too — never hardcode
a resource name as a plain string. This ensures the name is always derived from the same
source of truth regardless of release name.

```yaml
# values.yaml — under the dependency alias key
someField:
   name: '{{ include "<chart>.fullname" . }}-suffix'
```

Inside a dependency's template, `tpl ... $` is called with the subchart's root context,
so `.` inside the tpl string resolves to that subchart's context (same as `$ctx` in the
umbrella template).

# Dependencies

**NEVER run `helm repo add` or `helm repo update`** — do not add or update repos locally.

Use the full repo URL directly in all helm commands:

```shell
# get values.yaml
helm show values <REPO-URL>/<CHART> --version <VERSION>

# search for versions
helm search repo <REPO-URL>/<CHART> --versions
```

When dependency repo is local reference `file://local-path`, use `/local-path` only instead in commands above.

## Upgrading dependency version

1. Check latest version
2. Update version in `Chart.yaml`
3. Run `helm dep update .`
4. Lint and template to verify

## Adding new dependency

When adding new dependency, you MUST know:
- repository
- version
- name
- alias (optional)

## Obtaining configuration/values options

If a dependency chart is already downloaded as a `.tgz` in the `charts/` folder, use the local file directly — do NOT fetch from the remote URL:

```shell
# preferred: use local .tgz if available
helm show values ./charts/<CHART>-<VERSION>.tgz
helm show readme ./charts/<CHART>-<VERSION>.tgz

# fallback: use full repo URL when no local .tgz exists
helm show values <REPO-URL>/<CHART> --version <VERSION>
helm show readme <REPO-URL>/<CHART> --version <VERSION>
```

**Prefer values and README documentation only.** Rely on `helm show values` and `helm show readme` as the primary source of truth for understanding a dependency chart's configuration.

If values/README are insufficient to figure out the task (e.g. undocumented behaviour, complex template logic), MUST ask the user for permission to scan the full template implementation:

> "I can't determine X from the values/README alone. Can I scan the full template sources of the `<CHART>` dependency to better understand the implementation?"

# Tools

## helm unittest

https://github.com/helm-unittest/helm-unittest

```
helm plugin install https://github.com/helm-unittest/helm-unittest.git --version VERSION
```