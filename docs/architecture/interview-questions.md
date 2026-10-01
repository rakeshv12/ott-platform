# Architecture Interview Questions

These questions are based on the documented OTT platform architecture.

## 1. Explain the OTT platform architecture.
**Answer:** Developer -> GitHub -> AWS CodeConnections -> CodePipeline V2 -> CodeBuild -> ECR -> EKS. Inside EKS, Frontend, Auth, Catalog and Stream run as Kubernetes workloads. RDS PostgreSQL and ElastiCache Redis are managed AWS services. Stream uses MinIO for media storage and processing.

## 2. Why separate frontend, backend and media namespaces?
**Answer:** The intended boundaries are ott-frontend, ott-backend and ott-media. Separation improves organization, RBAC boundaries and operational visibility.

## 3. What is implemented versus planned?
**Answer:** AWS networking, EKS, managed data services, ECR, CodePipeline, CodeBuild, Kubernetes RBAC and Helm structure are implemented. The deploy stage currently verifies EKS connectivity but does not execute Helm. External Secrets, production hardening, observability and HA/DR are planned.

## 4. Why use managed RDS and Redis?
**Answer:** The project separates database lifecycle and service operations from Kubernetes application scheduling. In-cluster PostgreSQL and Redis are disabled for the AWS development environment.

## 5. How would you make the design portable to Azure?
**Answer:** Keep application interfaces Kubernetes-native and put provider-specific infrastructure below them. AWS can use RDS, ElastiCache and Secrets Manager; Azure can use Azure PostgreSQL, Azure Cache for Redis and Key Vault.

## 6. Traffic increases 10x. What do you inspect?
**Answer:** Identify the bottleneck first: ingress, frontend, APIs, database, Redis, node capacity or media processing. Check request rate, latency, pod resources, HPA, nodes and database connections before changing capacity.

## 7. One AZ becomes unavailable. What happens?
**Answer:** EKS workers span two AZs, so workloads may continue if sufficient replicas and capacity remain. The single development NAT Gateway is an AZ dependency for general outbound traffic; production should evaluate one NAT per AZ.

## 8. API works internally but users cannot reach it. How do you troubleshoot?
**Answer:** Trace client -> public entry point -> load balancer/ingress -> Service -> Pod. Verify DNS, routes, security groups, target health, selectors and readiness.

## 9. Pods start but cannot reach RDS. What do you check?
**Answer:** Check the actual database hostname first. The current application still uses POSTGRES_HOST=postgres while AWS RDS is the target. Then verify DNS, security groups, routing, port 5432 and credentials.

## 10. How would you design DR?
**Answer:** Define RTO/RPO, then address Terraform recreation, database recovery, image availability, media durability, secrets recovery and DNS/traffic recovery. A complete DR implementation is not yet present.

## Scenario-based

### 11. Pipeline says deployment succeeded but application did not change.
**Answer:** Inspect the actual deploy CodeBuild log. A stage name does not prove Helm executed. The current deploy buildspec installs Helm and verifies EKS connectivity but the build phase only echoes the deployment step.

### 12. Terraform proposes EKS replacement.
**Answer:** Stop. Identify the exact replacement attribute, compare state and configuration, understand provider behavior and create a migration plan before applying. Never casually replace a live cluster.

### 13. New image exists in ECR but old image runs.
**Answer:** Check Deployment image tag, Helm values, rendered manifests and rollout history. An ECR push does not automatically change a Kubernetes Deployment.

### 14. What is the current biggest architecture gap?
**Answer:** The application deployment path is incomplete: Helm is not yet executed by CI/CD, ott-secrets is missing, legacy database/cache hostnames remain, and MinIO is Pending.

### 15. How do you explain any architecture decision?
**Answer:** Use What -> Why -> Alternatives -> Trade-off -> Implementation -> Verification -> Failure scenario -> Production improvement.