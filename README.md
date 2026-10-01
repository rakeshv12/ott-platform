# OTT Platform

An engineering-focused OTT streaming platform for learning and demonstrating cloud infrastructure, Kubernetes, CI/CD, Terraform, Helm, security, troubleshooting and multi-cloud portability.

## Current platform

```text
Developer
   |
 GitHub
   |
 AWS CodeConnections
   |
 CodePipeline V2
   |
 CodeBuild
   |
 ECR
   |
 EKS
   |
 +-------------------------------+
 | Frontend | Auth | Catalog | Stream |
 +-------------------------------+
             |          |
          RDS PostgreSQL  Redis
             |
           MinIO / media
```

## Current AWS environment

- Region: `us-east-1`
- VPC: `10.0.0.0/16`
- Two public and two private subnets across two AZs
- EKS: `ott-platform-dev`, Kubernetes 1.33
- Worker nodes: private, `t3.medium`, desired 2
- RDS PostgreSQL 17
- ElastiCache Redis 7.1
- ECR for application images and shared private base images
- AWS CodePipeline V2 + CodeBuild for AWS-native CI/CD

## Repository structure

```text
backend/       Application services
frontend/      Frontend application
Helm/          Helm chart
k8s/           Kubernetes manifests/reference
terraform/     AWS infrastructure
docker/        Container assets
docs/          Engineering documentation
buildspec.yml  Build stage
buildspec-deploy.yml  Deploy-stage buildspec
```

## Documentation

Start with the [documentation index](docs/README.md).

### Architecture
- [Overview](docs/architecture/overview.md)
- [AWS Network](docs/architecture/aws-network.md)

### Infrastructure
- [Terraform](docs/infrastructure/terraform.md)
- [EKS](docs/infrastructure/eks.md)
- [RDS and Redis](docs/infrastructure/data-services.md)

### CI/CD and Kubernetes
- [AWS CI/CD](docs/cicd/aws-cicd.md)
- [Kubernetes Platform](docs/kubernetes/platform.md)

### Security and operations
- [Security and Secrets](docs/security/secrets.md)
- [Issue and Resolution Log](docs/troubleshooting/issue-log.md)
- [Architecture Decisions](docs/decisions/README.md)
- [Project History](docs/project-history.md)

## Important current limitations

1. The latest deploy CodeBuild stage verifies EKS connectivity but does not yet execute the Helm release.
2. Auth and Catalog currently reference a missing Kubernetes Secret named `ott-secrets`.
3. Auth and Catalog still contain legacy `postgres` and `redis` host configuration that must be aligned with managed AWS services.
4. MinIO is currently Pending and needs a separate storage/scheduling investigation.
5. Frontend namespace/service alignment needs final reconciliation.

These are intentionally documented as current issues rather than hidden behind a claim of a fully completed production deployment.

## Engineering rules

1. No hardcoded environment-specific values or credentials.
2. Compare tools and document why a tool was selected.
3. Document everything important: What, Why, How, Verification, Failure, Security, Cost and Rollback.
4. Architecture diagrams must represent reality.
5. Keep application interfaces portable across AWS, Azure and bare-metal Kubernetes where practical.
6. Never commit secrets.

## Target multi-cloud secret architecture

The planned portable interface is:

```text
Application
    |
Kubernetes Secret: ott-secrets
    |
External Secrets Operator
    +--> AWS Secrets Manager
    +--> Azure Key Vault
    +--> HashiCorp Vault
```

This design is planned and has **not** yet been implemented.
