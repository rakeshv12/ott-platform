# Infrastructure Interview Questions

## Terraform
### 1. Why Terraform?
**Answer:** Repeatable, reviewable infrastructure-as-code with version control and dependency management.

### 2. Why modules?
**Answer:** Reusable infrastructure logic is separated from environment-specific inputs. This project has network, EKS, ECR, RDS, Redis and CI/CD modules.

### 3. Why remote state?
**Answer:** Terraform state is centralized in S3 instead of depending on one developer's local state.

### 4. Why separate bootstrap?
**Answer:** The state bucket must exist before the environment can initialize against it.

### 5. Why use targeted apply during troubleshooting?
**Answer:** It can focus a known change, but it should not replace a full plan because targeted operations can hide unrelated changes.

### 6. Terraform wants to replace EKS. What do you do?
**Answer:** Stop, identify the exact attribute causing replacement, compare state/configuration/provider behavior and determine whether migration is required. Do not apply blindly.

## VPC
### 7. Explain the VPC CIDR.
**Answer:** 10.0.0.0/16, split into four /20 subnets across two AZs: two public and two private.

### 8. Why private EKS nodes?
**Answer:** Workers do not need public IPs for normal operation, reducing direct internet exposure.

### 9. NAT Gateway versus VPC endpoint?
**Answer:** NAT provides general outbound internet access. VPC endpoints provide private access to supported AWS services such as S3, ECR and Secrets Manager.

### 10. Why one NAT in development?
**Answer:** Cost reduction. The trade-off is lower AZ-level resilience.

## EKS
### 11. Why two worker nodes across two AZs?
**Answer:** Basic failure tolerance and distribution of worker capacity.

### 12. What caused the initial node connectivity issue?
**Answer:** Private workers lacked a general outbound path. Adding NAT and the private default route allowed required outbound/bootstrap activity.

## ECR
### 13. Why did CodeBuild get ECR 403?
**Answer:** It could push application images but could not pull the private base image from a separate repository.

### 14. What IAM lesson does this show?
**Answer:** Evaluate principal + action + resource. ECR access is not one universal permission.

## Data services
### 15. Why RDS?
**Answer:** PostgreSQL lifecycle is separated from Kubernetes application scheduling. The master password is AWS-managed.

### 16. Why ElastiCache?
**Answer:** Redis is provided as a managed service rather than an application pod dependency.

### 17. What is the current data-service integration issue?
**Answer:** Application templates still use postgres and redis hostnames instead of the managed AWS endpoints.

## Scenario-based
### 18. Private EKS nodes become NotReady after a network change.
**Answer:** Check node conditions, route tables, NAT, security groups, VPC endpoints, DNS and CNI health. Compare with the known-good route path.

### 19. Terraform apply fails halfway.
**Answer:** Inspect the error, run plan, inspect state and actual resource status, then make the smallest corrective change. Do not manually recreate resources without understanding state.

### 20. RDS is healthy but application cannot connect.
**Answer:** Verify hostname, DNS, port 5432, security groups, subnet routing and credentials. In this project, first check the obsolete postgres hostname.

### 21. ECR image pull fails from EKS.
**Answer:** Check node IAM ECR pull permissions, image URI/tag, repository/region and network connectivity through ECR endpoints or NAT.