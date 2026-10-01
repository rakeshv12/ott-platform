# OTT Platform Documentation

This directory is the engineering record for the OTT platform.

## Current status

- Implemented: AWS VPC/networking, EKS, RDS PostgreSQL, ElastiCache Redis, ECR, AWS-native CodePipeline/CodeBuild, Kubernetes RBAC and Helm structure.
- Partially implemented: the deploy CodeBuild stage currently verifies EKS connectivity; the latest buildspec does not yet execute the Helm release.
- Current issues: missing Kubernetes Secret `ott-secrets` causes Auth/Catalog `CreateContainerConfigError`; MinIO is Pending; frontend namespace/service alignment needs reconciliation.
- Planned: portable External Secrets design, AWS Secrets Manager integration, Azure Key Vault and bare-metal Vault variants, production hardening, observability, HA/DR and cost optimization.

## Interview preparation

- [Complete Interview Preparation](interview/README.md)
- [Architecture Interview Questions](architecture/interview-questions.md)
- [Infrastructure Interview Questions](infrastructure/interview-questions.md)
- [CI/CD Interview Questions](cicd/interview-questions.md)
- [Kubernetes Interview Questions](kubernetes/interview-questions.md)
- [Security Interview Questions](security/interview-questions.md)
- [Scenario-Based Troubleshooting Questions](troubleshooting/scenario-based-questions.md)

## Core documents

- [Architecture Overview](architecture/overview.md)
- [AWS Network](architecture/aws-network.md)
- [Terraform](infrastructure/terraform.md)
- [EKS](infrastructure/eks.md)
- [RDS and Redis](infrastructure/data-services.md)
- [AWS CI/CD](cicd/aws-cicd.md)
- [Kubernetes Platform](kubernetes/platform.md)
- [Security and Secrets](security/secrets.md)
- [Issue and Resolution Log](troubleshooting/issue-log.md)
- [Architecture Decision Records](decisions/README.md)
- [Project History](project-history.md)

## Engineering rules

1. Avoid hardcoded environment-specific values.
2. Compare tools and record why a technology was selected.
3. Document implementation, verification, failure modes and rollback considerations.
4. Architecture diagrams must represent the actual implementation.
5. Keep application logic portable across AWS, Azure and bare-metal Kubernetes where practical.
6. Never commit credentials, passwords, tokens or secret values.

Each document separates Implemented, Observed, Decision, Planned and Follow-up items so the target architecture is not confused with the current state.
