# Security Interview Questions

## IAM
### 1. Why IAM Identity Center?
**Answer:** Centralized human authentication, MFA and temporary AWS credentials without long-lived access keys.

### 2. Why separate CodeBuild roles?
**Answer:** Build needs ECR publishing; deployment needs EKS/Kubernetes access. Separation reduces blast radius.

### 3. Why does CodeBuild need access to two ECR repositories?
**Answer:** It pushes application images to one and pulls private base images from another.

### 4. Does eks:DescribeCluster allow kubectl get nodes?
**Answer:** No. AWS IAM controls AWS authorization while Kubernetes RBAC controls Kubernetes resource authorization.

### 5. Why not let humans assume the deployment role?
**Answer:** The role is intended for CodeBuild. Broadening trust for interactive testing weakens the service boundary.

## Secrets
### 6. Why not put database passwords in Helm values?
**Answer:** Do not commit plaintext production credentials. The planned design uses External Secrets Operator with a provider-native secret store.

### 7. Why use a Kubernetes Secret as the application interface?
**Answer:** It keeps the application configuration portable across AWS, Azure and bare-metal Kubernetes.

### 8. What is the AWS secret architecture?
**Answer:** AWS Secrets Manager behind External Secrets Operator is planned.

### 9. What is the Azure architecture?
**Answer:** Azure Key Vault behind External Secrets Operator is planned.

### 10. What happened with ott-secrets?
**Answer:** Auth and Catalog reference it, but it is absent. Pods fail with CreateContainerConfigError.

## Network security
### 11. Why private EKS workers?
**Answer:** They do not need public IP addresses for normal operation, reducing direct exposure.

### 12. Why VPC endpoints?
**Answer:** Private connectivity to supported AWS services and less dependency on NAT for those service paths.

### 13. What is the current endpoint security limitation?
**Answer:** The endpoint security group currently allows HTTPS from the VPC CIDR. Production should narrow this to required workload security groups.

## Scenario-based
### 14. AWS credentials are committed to Git.
**Answer:** Treat them as compromised. Revoke/rotate, investigate usage, remove exposure appropriately and migrate to temporary credentials.

### 15. CodeBuild is compromised.
**Answer:** Identify its role and permissions, limit/revoke affected access, inspect activity and rebuild from trusted source. Role separation reduces blast radius.

### 16. Developer asks for AdministratorAccess because deployment fails.
**Answer:** Identify the exact denied action and resource and grant only the required permission to the correct identity.

### 17. A pod needs AWS access.
**Answer:** Never place AWS access keys in the container. Use EKS Pod Identity or IRSA on AWS and keep the application-facing architecture portable.

### 18. Secret is visible in Terraform state.
**Answer:** Treat state as sensitive. Protect the backend with restrictive access and encryption and avoid placing secret values in configuration when managed secret handling is available.

### 19. How do you perform a least-privilege review?
**Answer:** Start with the required action, identify principal/action/resource, remove unused permissions, test the real workflow and repeat after architecture changes.