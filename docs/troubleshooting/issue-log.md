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

## CI/CD interpretation
The latest successful EKSDeploy stage did not execute Helm. It verified EKS connectivity. Stage success must be interpreted from the commands actually executed.

Detailed incident record: [CI/CD Deploy Stage Not Running Helm](./issue-cicd-deploy-stage-not-running-helm.md)
