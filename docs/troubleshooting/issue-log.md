# Issue and Resolution Log

## EKS workers lacked outbound connectivity
**Symptom:** private workers could not complete required outbound/bootstrap activity.

**Resolution:** NAT Gateway plus private-subnet default route.

**Result:** nodes became Ready.

## CodeBuild private ECR pull returned 403
**Cause:** CodeBuild had application ECR push permissions but lacked pull permissions on the separate base-image repository.

**Resolution:** add scoped ECR read permissions to the base-image repository.

**Result:** Build stage succeeded.

## GitHub source did not trigger automatically
**Cause:** the AWS GitHub App had not been installed/connected for the repository.

**Resolution:** reconnect the CodePipeline source and install/connect the GitHub App.

## Deploy buildspec YAML error
**Cause:** YAML parsed a command as a mapping/subkey.

**Resolution:** simplify the buildspec and validate command parsing.

## CodeBuild `kubectl get nodes` returned Forbidden
**Cause:** deployment identity lacked cluster-wide node-list permission.

**Resolution:** replace the unnecessary command with `kubectl cluster-info`.

**Lesson:** do not grant broad Kubernetes permissions simply to make a diagnostic command succeed.

## Auth/Catalog CreateContainerConfigError
**Evidence:** pod events reported `secret "ott-secrets" not found`.

**Cause:** application templates reference a Secret that is not currently created.

**Next design:** External Secrets Operator with provider-specific secret stores.

## MinIO Pending
**Status:** root cause not yet established. Inspect scheduling/PVC events before changing storage.

## Frontend namespace mismatch
**Status:** frontend resources have existed in different namespaces during the transition. Reconcile Deployment, Service and Helm namespace ownership before finalizing.

## ISSUE-1: CI/CD Deploy Stage Not Running Helm

**Symptom:** the EKSDeploy stage reported success, but the application was not being reconciled through Helm.

**Step-by-step investigation:**

1. Confirmed GitHub Source succeeded.
2. Confirmed DockerBuild succeeded and pushed application images to ECR.
3. Inspected EKSDeploy CodeBuild logs.
4. Confirmed AWS CLI, kubectl and Helm were available.
5. Confirmed `aws eks update-kubeconfig` succeeded.
6. Confirmed `kubectl cluster-info` succeeded.
7. Inspected `buildspec-deploy.yml`.
8. Found that the build phase only printed `Starting Helm deployment...` and did not execute Helm.
9. Checked Helm history and confirmed Revision 1 was failed.
10. Confirmed current application resources are associated with the `ott-platform` Helm release while namespaces are not managed by the chart.
11. Separated the CI/CD problem from application issues such as the missing `ott-secrets` Secret.

**Root cause:** the Deploy CodeBuild buildspec stopped at EKS connectivity verification and never invoked Helm.

**Resolution:** `buildspec-deploy.yml` now executes `helm upgrade --install` using the version-controlled chart and environment values. Image tags are overridden from the current CodePipeline source revision, and Helm uses `--wait --timeout 10m` followed by `helm status`.

**Design decision:** a separate `deploy.sh` was considered but rejected because the deployment logic is small enough to remain directly in `buildspec-deploy.yml`.

**Next verification:** run the CodePipeline and confirm the EKSDeploy logs contain the actual Helm operation. If Helm fails, troubleshoot that concrete failure next.

Detailed incident record: [ISSUE-1: CI/CD Deploy Stage Not Running Helm](./issue-cicd-deploy-stage-not-running-helm.md)

## Auth/Catalog CreateContainerConfigError

**Evidence:** pod events reported `secret "ott-secrets" not found`.

**Cause:** application templates reference a Secret that is not currently created.

**Next design:** External Secrets Operator with provider-specific secret stores.

## MinIO Pending

**Status:** root cause not yet established. Inspect scheduling/PVC events before changing storage.

## Frontend namespace mismatch

**Status:** frontend resources have existed in different namespaces during the transition. The corrected Helm chart targets `ott-frontend`; reconciliation must be verified through the CI/CD Helm deployment.

## RDS/Redis application configuration

**Status:** managed AWS PostgreSQL and Redis exist, but application configuration still needs to be switched from in-cluster hostnames to the managed service endpoints.

## CI/CD interpretation

A successful pipeline stage must be interpreted from the commands actually executed and the resulting application state. A stage named EKSDeploy is not evidence of deployment unless Helm/Kubernetes deployment and rollout verification actually occur.
