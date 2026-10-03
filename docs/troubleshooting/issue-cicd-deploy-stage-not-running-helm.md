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

The deployment stage should call a version-controlled deployment script rather than putting a large Helm command directly into a complex buildspec.

Recommended structure:

```text
ott-platform/
|
+-- buildspec-deploy.yml
|
+-- scripts/
|    |
|    +-- deploy.sh
|
+-- Helm/
     |
     +-- ott/
```

The deployment flow should become:

```text
Deploy CodeBuild
      |
      v
buildspec-deploy.yml
      |
      v
scripts/deploy.sh
      |
      +--> aws eks update-kubeconfig
      |
      +--> verify EKS connectivity
      |
      +--> helm upgrade --install
      |
      +--> verify rollout/status
      |
      v
EKS application state
```

This also keeps deployment logic version-controlled and easier to test locally.

---

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
| Actual Helm execution in deploy stage | **Not yet implemented** |
| Frontend namespace reconciliation | **Pending actual Helm deployment** |
| `ott-secrets` | **Pending** |
| RDS/Redis application configuration | **Pending** |
| MinIO Pending investigation | **Pending** |

---

## 14. Next Action

The immediate implementation task is:

```text
Create scripts/deploy.sh
        |
        v
Update buildspec-deploy.yml
        |
        v
Run Helm from CodeBuild
        |
        v
Trigger CodePipeline
        |
        v
Verify actual EKS resource reconciliation
```

Only after this is working should we move to the `ott-secrets`, RDS/Redis, and MinIO issues.
