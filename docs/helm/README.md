# Helm command guide — OTT platform

This guide targets Helm 3, used by our deployment buildspec. Run examples separately in PowerShell. Examples are a reference, not a script to execute from top to bottom.

## Terms before commands

- **Helm:** a tool that packages and deploys Kubernetes applications.
- **Chart:** the application package: templates, default settings and metadata.
- **Release:** one installed instance of a chart. Our application release is `ott-platform`; ESO uses `external-secrets`.
- **Repository:** a location from which Helm downloads charts.
- **Values:** settings used to generate Kubernetes YAML.
- **Template/render:** replace chart expressions with values to produce YAML.
- **Namespace:** a Kubernetes scope for namespaced resources.
- **Revision:** a numbered record of a release installation or update.
- **CRD:** Custom Resource Definition; introduces a Kubernetes resource type.
- **Hook:** a task attached to a release lifecycle event.
- **Dependency:** another chart required by a chart.
- **OCI registry:** a service storing packaged charts and container artifacts.
- **Plugin:** an extension that adds Helm capabilities.
- **Provenance:** signing information used to verify a chart's origin.
- **Dry run:** preview an operation without applying its release changes.

## Project paths

Run local chart examples from `D:\Kubernetes-Practice\ott-platform`.

| Item | Path/name |
|---|---|
| Application chart | `Helm/ott` |
| Default values | `Helm/ott/values.yaml` |
| AWS dev overrides | `Helm/ott/values-dev.yaml` |
| Application release | `ott-platform` |
| Release namespace | `ott-backend` |
| ESO release, namespace, ServiceAccount | `external-secrets` |

## Discover commands for your installed version

```powershell
helm version
helm help
helm upgrade --help
helm repo --help
```

`helm help` is the complete command list for your binary. Command availability can differ between Helm versions and plugins.

## Command reference

| Command | Explanation/example |
|---|---|
| `helm version` | Check client version. |
| `helm env` | Inspect Helm configuration locations. |
| `helm completion powershell` | Generate shell completion code. |
| `helm create demo-chart` | Start a new chart. |
| `helm lint .\Helm\ott -f .\Helm\ott\values-dev.yaml` | Check chart structure and rendering issues. |
| `helm template ott-platform .\Helm\ott -f .\Helm\ott\values-dev.yaml` | Render application YAML locally. |
| `helm install RELEASE CHART -n NAMESPACE` | Create a release. |
| `helm upgrade RELEASE CHART -n NAMESPACE` | Update a release. |
| `helm upgrade --install RELEASE CHART -n NAMESPACE` | Update, or install if absent. |
| `helm list -A` | Find releases across namespaces. |
| `helm status ott-platform -n ott-backend` | Inspect release status. |
| `helm history ott-platform -n ott-backend` | Find revision numbers. |
| `helm rollback ott-platform REVISION -n ott-backend` | Restore a selected revision; changes cluster resources. |
| `helm uninstall RELEASE -n NAMESPACE` | Remove a release and its managed resources; not a diagnostic command. |
| `helm test RELEASE -n NAMESPACE` | Run tests defined by the chart. |
| `helm package .\Helm\ott` | Build a chart archive. |
| `helm pull REPO/CHART --version VERSION --untar` | Download and unpack a chart. |
| `helm push CHART.tgz oci://REGISTRY/PATH` | Publish a packaged chart to an OCI registry. |
| `helm verify CHART.tgz` | Verify chart signing information. |

Replace uppercase placeholders; they are not literal project values.

## Repository, search and chart inspection

| Command | Purpose |
|---|---|
| `helm repo add external-secrets https://charts.external-secrets.io` | Register ESO's chart source. |
| `helm repo update external-secrets` | Refresh its local chart index. |
| `helm repo list` | Show registered sources. |
| `helm repo remove NAME` | Remove a local repository entry. |
| `helm repo index DIRECTORY` | Generate an index for packaged charts. |
| `helm search repo external-secrets/external-secrets --versions` | List chart versions. |
| `helm search hub KEYWORD` | Search Artifact Hub. |
| `helm show chart REPO/CHART` | Read chart metadata. |
| `helm show values REPO/CHART` | Read default settings. |
| `helm show readme REPO/CHART` | Read chart instructions. |
| `helm show crds REPO/CHART` | Inspect packaged CRDs. |
| `helm show all REPO/CHART` | Read combined chart information. |

Add `--version 2.12.0` when inspecting the ESO version selected in this project.

## Installed release inspection

| Command | Purpose |
|---|---|
| `helm get values ott-platform -n ott-backend` | Inspect supplied settings. |
| `helm get values ott-platform -n ott-backend --all` | Include computed settings. |
| `helm get manifest ott-platform -n ott-backend` | Inspect stored rendered resources. |
| `helm get hooks ott-platform -n ott-backend` | Inspect lifecycle tasks. |
| `helm get notes ott-platform -n ott-backend` | Read installation notes. |
| `helm get metadata ott-platform -n ott-backend` | Read release metadata. |
| `helm get all ott-platform -n ott-backend` | Collect release details. |

These outputs can contain secrets; do not commit or publish them without review.

## Dependencies, registries and plugins

| Command | Purpose |
|---|---|
| `helm dependency list .\Helm\ott` | Inspect required charts. |
| `helm dependency update .\Helm\ott` | Resolve dependencies and update the lock file. |
| `helm dependency build .\Helm\ott` | Rebuild dependencies from the lock file. |
| `helm registry login REGISTRY` | Authenticate to a registry. |
| `helm registry logout REGISTRY` | Remove its saved login. |
| `helm plugin list` | Inspect extensions. |
| `helm plugin install URL` | Install an extension. |
| `helm plugin update NAME` | Update an extension. |
| `helm plugin uninstall NAME` | Remove an extension. |

## Important flags

| Flag | Meaning |
|---|---|
| `-n` / `--namespace` | Select release namespace; chart templates can explicitly target other namespaces. |
| `-f` / `--values` | Load a values file. |
| `--set` | Override a value on the command line. |
| `--set-string` | Preserve an override as text. |
| `--version` | Select chart version, not an application image tag. |
| `--create-namespace` | Create the release namespace during installation. |
| `--wait` | Wait for supported resource readiness checks. |
| `--timeout 5m` | Bound waiting/operations. |
| `--dry-run` | Preview an install/upgrade. Output can expose secrets. |
| `--debug` | Print diagnostic detail. |
| `--atomic` | On upgrade failure, attempt rollback; implies waiting. |
| `--kube-context` | Select the Kubernetes cluster context. |

## OTT validation workflow

```powershell
helm lint .\Helm\ott -f .\Helm\ott\values-dev.yaml
helm template ott-platform .\Helm\ott -f .\Helm\ott\values-dev.yaml
helm status ott-platform -n ott-backend
helm history ott-platform -n ott-backend
```

Application deployments are owned by CodePipeline. Its buildspec supplies image tags matching the Build stage. Avoid manually deploying the historical fallback tags in values-dev.yaml.

## ESO installation selected for this project

```powershell
helm upgrade --install external-secrets external-secrets/external-secrets --version 2.12.0 --namespace external-secrets --create-namespace --set serviceAccount.create=true --set serviceAccount.name=external-secrets --set installCRDs=true --wait --timeout 5m
```

The first `external-secrets` is the release name. The second argument identifies the repository/chart. The ServiceAccount name matches the Terraform Pod Identity association. This installs ESO; SecretStore and ExternalSecret configuration are still required to create ott-secrets.

Verify separately:

```powershell
helm status external-secrets -n external-secrets
kubectl get pods -n external-secrets
kubectl get serviceaccount external-secrets -n external-secrets
kubectl get crd externalsecrets.external-secrets.io secretstores.external-secrets.io
```

## Learning order

Start with version, repo add/update, search repo, show values, lint, template, upgrade --install, list and status. Learn history/rollback after release management is clear.

## Official references

- [Helm 3 command reference](https://helm.sh/docs/v3/helm/helm/)
- [Upgrade and flags](https://helm.sh/docs/v3/helm/helm_upgrade/)
- [Release inspection](https://helm.sh/docs/v3/helm/helm_get/)
- [Current command catalogue](https://helm.sh/docs/helm/)
