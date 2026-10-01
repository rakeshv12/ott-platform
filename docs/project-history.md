# Project History

## Application foundation
Auth, Catalog, Stream and frontend services were developed. Stream processing uses Kubernetes Jobs and FFmpeg to produce HLS output, with MinIO used for media storage in the portable application design.

## Local Kubernetes
Namespaces, RBAC and Stream Job permissions were established and troubleshooting workflows were exercised.

## AWS Terraform
Reusable modules were introduced for networking, EKS, ECR, RDS, Redis, S3 and CI/CD.

## EKS
Private worker nodes were created across two AZs. NAT was added after worker connectivity issues.

## CI/CD
Jenkins was evaluated as a technology but AWS-native CI/CD was selected for the AWS path.

## Build troubleshooting
Private ECR base-image access was fixed with repository-scoped CodeBuild ECR read permissions.

## Deployment identity
A dedicated deploy CodeBuild role and Kubernetes RBAC mapping were introduced. Broad node-list verification was intentionally removed.

## Current phase
The next focus is secure runtime configuration. The portable target is:

```text
Application -> Kubernetes Secret -> External Secrets Operator -> provider-specific secret backend
```

The implementation remains pending.

## Operating rules
1. One meaningful change at a time.
2. Record why infrastructure choices were made.
3. Separate implemented architecture from target architecture.
4. Preserve troubleshooting lessons.
5. Never commit secrets.
