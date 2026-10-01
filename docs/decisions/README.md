# Architecture Decision Records

## ADR-001 — AWS-native CI/CD
**Decision:** GitHub -> CodeConnections -> CodePipeline -> CodeBuild -> ECR -> EKS.

**Alternative considered:** Jenkins/CloudBees Jenkins.

**Status:** Implemented, with actual Helm execution still pending.

## ADR-002 — Managed PostgreSQL and Redis
**Decision:** use RDS PostgreSQL and ElastiCache Redis for AWS instead of running those databases inside EKS.

**Status:** Implemented.

## ADR-003 — Portable secret interface
**Decision:** applications consume Kubernetes Secret `ott-secrets`; provider-specific secret backends remain outside application code.

**Providers planned:** AWS Secrets Manager, Azure Key Vault, HashiCorp Vault.

**Status:** Planned.

## ADR-004 — Private EKS workers
**Decision:** keep EKS workers in private subnets.

**Reason:** reduce direct exposure and use controlled egress.

**Status:** Implemented.

## ADR-005 — One NAT Gateway in development
**Decision:** one NAT Gateway for current development.

**Reason:** lower development cost while providing outbound connectivity.

**Production consideration:** multi-AZ NAT may be appropriate where availability requirements justify additional cost.
