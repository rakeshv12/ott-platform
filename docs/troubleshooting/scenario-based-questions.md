# Scenario-Based Interview Questions

## Scenario 1 — EKS nodes are NotReady
Check kubectl get nodes, describe the node, kubelet/runtime, route tables, NAT, security groups, DNS and VPC CNI. Project lesson: NAT was added because private workers lacked the required outbound path.

## Scenario 2 — CodeBuild gets ECR 403
The base image is in a different ECR repository. Add repository-scoped pull permissions and ECR authentication. This exact failure occurred.

## Scenario 3 — GitHub push does not trigger CodePipeline
Check CodeConnections, GitHub App installation, repository/branch, V2 trigger and source revision. The project required reconnecting/installing the AWS GitHub App.

## Scenario 4 — Deploy buildspec YAML error
Inspect the reported line, YAML indentation and command strings. Simplify the buildspec and validate before retrying.

## Scenario 5 — cluster-info works but get nodes is Forbidden
Authentication succeeded but Kubernetes RBAC does not allow cluster-wide Node listing. Do not grant broad permissions just for an unnecessary diagnostic command.

## Scenario 6 — Auth/Catalog CreateContainerConfigError
Describe the pod and inspect Events. Project root cause: secret ott-secrets not found.

## Scenario 7 — RDS healthy but application cannot connect
Check hostname, DNS, port 5432, security groups, routing and credentials. Project-specific issue: Auth/Catalog still use POSTGRES_HOST=postgres.

## Scenario 8 — Redis connection fails
Check REDIS_HOST, port 6379, DNS, ElastiCache security group and network path. Project-specific issue: legacy redis hostname remains.

## Scenario 9 — MinIO is Pending
Inspect pod events, PVC, StorageClass, node capacity and scheduling constraints before changing the StatefulSet.

## Scenario 10 — Pipeline says deployment succeeded but pods did not change
Inspect the actual CodeBuild commands. Current Deploy does not execute Helm; it verifies EKS connectivity.

## Scenario 11 — Terraform wants to replace EKS
Stop. Identify the replacement attribute, compare state/configuration/provider behavior and create a migration plan before applying.

## Scenario 12 — Helm namespace ownership conflict
Determine ownership. Do not have Terraform and Helm manage the same namespace. Project decision: Terraform owns namespaces; Helm owns application resources.

## Scenario 13 — New image pushed but old image runs
Check Deployment image tag, Helm values, rendered manifest and rollout history.

## Scenario 14 — Stream cannot create FFmpeg Jobs
Check Stream logs, ServiceAccount, RBAC, target namespace and Kubernetes API errors.

## Scenario 15 — One replica crashes while another works
Compare pod events, image, environment, node placement, resource usage and configuration. Do not assume both replicas are operationally identical.

## Scenario 16 — EKS pod is ImagePullBackOff
Verify image URI/tag, node IAM ECR permissions, repository/region and network path through ECR endpoints or NAT.

## Scenario 17 — Secret accidentally committed
Treat it as compromised. Rotate/revoke, investigate access, remove exposure appropriately and move to secret management.

## Scenario 18 — CodeBuild deployment returns Forbidden
Do not attach AdministratorAccess. Identify exact Kubernetes resource, verb and scope and change dedicated deployment RBAC only when required.

## Scenario 19 — NAT Gateway unavailable
Private workloads may lose general outbound connectivity. VPC endpoint paths to supported AWS services may remain available. Production should evaluate AZ-local NAT.

## Scenario 20 — RDS password must change
Use the managed secret mechanism rather than editing Terraform variables or committing a password.

## Scenario 21 — Identify the failing layer
Use this sequence: application logs -> pod events/status -> Service/RBAC -> node/CNI -> AWS network/IAM -> managed service. Move downward only as evidence requires.

## Scenario 22 — Production readiness review
Complete Helm deployment through CI/CD; implement External Secrets; fix RDS/Redis endpoints; resolve MinIO; reconcile frontend namespace ownership; tighten RBAC; remove unnecessary build-role EKS access; harden EKS API; tighten endpoint security groups; add monitoring, HA/DR, cost controls and rollback verification.

## Interview answering framework
1. Symptom
2. Evidence
3. Hypotheses
4. Verification command
5. Root cause
6. Minimal fix
7. Why the fix
8. Verification after fix
9. Rollback
10. Production hardening