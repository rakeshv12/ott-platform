# ISSUE-1: CI/CD Deploy Stage Not Running Helm

## 1. Problem Statement

The AWS-native OTT deployment pipeline reached a successful **EKSDeploy** stage, but the application was not actually being reconciled by Helm.

The deployment stage was successfully:

- installing/using AWS CLI, kubectl and Helm;
- configuring kubectl for the EKS cluster;
- running `kubectl cluster-info`.

However, it was **not executing a Helm deployment command**.

Therefore:

`CodePipeline = Succeeded` did not mean `Application deployment = Completed`.

This distinction is important for both troubleshooting and production CI/CD design.

---

## 2. Architecture at the Point of Failure

```text
Developer
   |
   v
GitHub
   |
   v
AWS CodePipeline
   |
   +--> Build CodeBuild
   |       |
   |       +--> Docker build
   |       +--> Push images to ECR
   |
   +--> Deploy CodeBuild
           |
           +--> Configure kubectl
           |
           +--> kubectl cluster-info       [executed]
           |
           +--> Helm deployment             [NOT executed]
```

The intended flow is:

```text
GitHub
   |
   v
CodePipeline
   |
   v
Build CodeBuild
   |
   v
ECR
   |
   v
Deploy CodeBuild
   |
   v
Helm
   |
   v
EKS
```

---

## 3. Evidence

The deployment buildspec contained:

```yaml
build:
  commands:
    - echo "Starting Helm deployment..."
```

The command only printed a message. It did not invoke Helm.

The preceding phase executed:

```bash
aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name $EKS_CLUSTER_NAME
kubectl cluster-info
```

Consequently, CodeBuild could complete successfully even though no Kubernetes resources were changed by Helm.

---

## 4. Why the Pipeline Was Green

CodeBuild determines phase success from the commands it actually executes.

The effective sequence was:

1. Install tools.
2. Configure kubectl.
3. Connect to EKS.
4. Print a Helm deployment message.
5. Exit successfully.

There was no failing Helm command because there was no Helm deployment command.

### Important lesson

A successful CI/CD stage validates only the work represented by its executed commands.

A stage called **EKSDeploy** is not evidence of an application deployment unless it actually performs the deployment operation and verifies the resulting state.

---

## 5. Related Frontend Namespace Observation

The intended namespace architecture is:

```text
EKS
|
+-- ott-frontend
|     +-- Frontend
|
+-- ott-backend
|     +-- Auth
|     +-- Catalog
|     +-- Stream
|
+-- ott-media
      +-- MinIO
```

The Helm frontend Deployment template already specifies:

```yaml
metadata:
  namespace: ott-frontend
```

The cluster, however, still showed older frontend pods under `ott-backend`.

This is consistent with an older deployment remaining in the cluster while the updated Helm source has not yet been reconciled through the actual deployment process.

The correct approach is to reconcile the application through Helm rather than manually moving or deleting individual pods.

---

## 6. Other Application Issues Found During Investigation

The Helm deployment issue is not the only outstanding application problem.

### Auth and Catalog

Both services were observed in:

```text
CreateContainerConfigError
```

Pod events identified:

```text
secret "ott-secrets" not found
```

The application templates reference this Kubernetes Secret, but it is not currently created.

### Planned secret architecture

The portable application interface is:

```text
External Secrets Operator
          |
          v
Kubernetes Secret: ott-secrets
          |
          +--> Auth
          |
          +--> Catalog
```

Provider backends are planned as:

- AWS: AWS Secrets Manager
- Azure: Azure Key Vault
- Bare metal: HashiCorp Vault

The provider-specific identity mechanism can vary while the application continues to consume the same Kubernetes Secret interface.

### RDS and Redis

The AWS environment contains managed PostgreSQL and Redis services, while the current application configuration still references the in-cluster hostnames:

```text
postgres
redis
```

The in-cluster PostgreSQL and Redis Helm resources are disabled for the AWS development environment.

This must be reconciled after the deployment path is functioning.

### MinIO

MinIO was observed in `Pending`.

Its scheduling/storage root cause was not yet established. The correct next investigation is pod/PVC scheduling events rather than changing storage configuration blindly.

---

## 7. Root Cause

### Primary root cause

The deploy CodeBuild buildspec stopped at EKS connectivity verification and did not execute Helm.

### Contributing condition

The project had already changed the Helm source for the desired frontend namespace, but the updated application state had not been reconciled through the actual Helm deployment path.

### Separate application configuration issue

Auth and Catalog depend on `ott-secrets`, which is currently absent.

These should be treated as separate issues rather than mixing secret management into the CI/CD deployment diagnosis.

---

## 8. Correct Resolution Design

The immediate fix is to execute Helm directly from the Deploy CodeBuild buildspec. A separate deploy.sh script was considered, but the deployment logic is small enough to remain directly in buildspec-deploy.yml.

```text
Deploy CodeBuild
      |
      v
buildspec-deploy.yml
      |
      v
Helm
      |
      v
EKS
```

The buildspec now:

1. Configures kubectl for EKS.
2. Verifies EKS connectivity.
3. Executes `helm upgrade --install`.
4. Uses the environment values file.
5. Overrides the four application image tags with the current CodePipeline source revision.
6. Waits up to ten minutes for Helm to complete.
7. Reports the Helm release status.

The deployment command is:

```bash
helm upgrade --install $HELM_RELEASE_NAME $HELM_CHART_PATH \
  --namespace $BACKEND_NAMESPACE \
  --values $HELM_VALUES_FILE \
  --set auth.image.tag=auth-$CODEBUILD_RESOLVED_SOURCE_VERSION \
  --set catalog.image.tag=catalog-$CODEBUILD_RESOLVED_SOURCE_VERSION \
  --set stream.image.tag=stream-$CODEBUILD_RESOLVED_SOURCE_VERSION \
  --set frontend.image.tag=frontend-$CODEBUILD_RESOLVED_SOURCE_VERSION \
  --wait \
  --timeout 10m
```

This is important because values-dev.yaml contains historical image tags. The deploy stage now derives image tags from the same source revision that triggered the pipeline, so the EKS deployment uses the images produced by that pipeline execution.

Manual Helm deployment from the developer workstation is not part of the target architecture.

## 9. Deployment Verification

A deployment should not be considered complete merely because Helm returned successfully.

Verification should include:

```bash
helm status ott-platform
kubectl get deployments -A
kubectl get pods -A
kubectl get services -A
```

For application rollouts, verify the expected namespaces:

```text
ott-frontend  -> frontend
ott-backend   -> auth, catalog, stream
ott-media     -> minio
```

For failures, inspect:

```bash
kubectl describe pod <pod> -n <namespace>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

---

## 10. Why We Are Not Using Manual kubectl Deployment

Manual commands such as:

```bash
kubectl apply ...
kubectl delete ...
```

can temporarily change the cluster but create configuration drift from Git.

The project design is:

```text
Git
 |
 v
CI/CD
 |
 v
Helm
 |
 v
EKS
```

Therefore Git and Helm remain the desired source of application deployment state.

---

## 11. Engineering Lesson

This incident demonstrates an important DevOps principle:

> **Pipeline success and application success are different verification levels.**

A mature deployment pipeline should verify:

1. Source retrieval.
2. Image build.
3. Image push.
4. Cluster authentication.
5. Helm execution.
6. Kubernetes rollout.
7. Application readiness.
8. Service connectivity.

Only then should the deployment stage report successful application deployment.

---

## 12. Interview Scenario

### Question

**Your CodePipeline EKS deployment stage is green, but the Kubernetes application has not changed. How would you troubleshoot it?**

### Expected investigation

1. Inspect the CodeBuild logs.
2. Identify the exact commands executed.
3. Check whether Helm was actually invoked.
4. Check the Helm release status.
5. Compare the deployed resources with the Git version.
6. Check Kubernetes Deployments and ReplicaSets.
7. Inspect pod events.
8. Verify namespace placement.
9. Verify image tags.
10. Verify application secrets/configuration.
11. Verify rollout status.

### Key answer

Do not assume that a stage named `EKSDeploy` performed a deployment. Confirm the actual deployment command and its result in the CodeBuild logs.

---

## 13. Status

| Item | Status |
|---|---|
| GitHub source | Implemented |
| CodePipeline | Implemented |
| Build CodeBuild | Implemented |
| ECR image build/push | Implemented |
| Deploy CodeBuild | Implemented |
| EKS authentication | Implemented |
| EKS connectivity verification | Implemented |
| Actual Helm execution in deploy stage | **Implemented** |
| Helm wait/status verification | **Implemented** |
| Frontend namespace reconciliation | **Pending pipeline verification** |
| `ott-secrets` | **Pending** |
| RDS/Redis application configuration | **Pending** |
| MinIO Pending investigation | **Pending** |

## 14. Next Action

Run the AWS CodePipeline and inspect the EKSDeploy CodeBuild logs.

```powershell
aws codepipeline start-pipeline-execution `
  --name ott-platform-dev-pipeline `
  --region us-east-1 `
  --profile ott-admin
```

The critical verification is that the EKSDeploy logs now contain an actual `helm upgrade --install` operation.

If Helm fails, that failure becomes the next concrete troubleshooting issue. The pipeline should not be made artificially green by removing deployment verification.
