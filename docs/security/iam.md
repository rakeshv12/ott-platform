# AWS IAM and Access Management

## 1. Purpose

IAM controls who or what can access AWS resources and what actions are allowed.

For this OTT platform, IAM is separated by responsibility:
- Human administration: AWS IAM Identity Center
- EKS control plane: EKS cluster IAM role
- EKS worker nodes: EKS node IAM role
- CI build: CodeBuild build role
- CI deployment: dedicated CodeBuild deploy role
- Kubernetes workloads: Kubernetes ServiceAccounts and RBAC
- Application secrets: planned External Secrets Operator with a cloud-specific secret backend

## 2. Current IAM Architecture

```text
Human Administrator
       |
       v
AWS IAM Identity Center
       |
       v
OTT-AdminAccess permission set
       |
       v
AWS account
       |
       +----------------------+
       |                      |
       v                      v
Terraform / AWS APIs       AWS resources

CodePipeline
       |
       v
CodeBuild
   |             |
   |             +--> Deploy CodeBuild Role
   |                       |
   |                       v
   |                    EKS API
   |
   +--> Build CodeBuild Role
            |
            +--> ECR push
            +--> ECR base-image pull
            +--> CloudWatch Logs
```

EKS also uses separate IAM roles for the cluster control plane and worker nodes.

## 3. Human Access — IAM Identity Center

The project uses AWS IAM Identity Center rather than creating long-lived IAM access keys for the administrator.

Current setup:
- Identity source: IAM Identity Center directory
- Permission set: OTT-AdminAccess
- Permission: AdministratorAccess
- MFA: always enabled
- AWS CLI profile: ott-admin
- The current OTT development infrastructure is deployed in us-east-1

Typical CLI flow:

```powershell
$env:AWS_PROFILE="ott-admin"
aws sso login --profile ott-admin
aws sts get-caller-identity --profile ott-admin
```

Identity Center authenticates the human user. It does not automatically grant Kubernetes permissions inside EKS.

## 4. EKS IAM Roles

### 4.1 EKS Cluster Role

The cluster role is assumed by the Amazon EKS service and allows EKS to perform operations required by the Kubernetes control plane. Terraform creates the role and attaches AmazonEKSClusterPolicy.

```text
EKS service
    | AssumeRole
    v
EKS cluster IAM role
    |
    v
AWS APIs required by EKS
```

### 4.2 EKS Node Role

Worker nodes use a separate IAM role. Current policies include:
- AmazonEKSWorkerNodePolicy
- AmazonEC2ContainerRegistryPullOnly
- AmazonEKS_CNI_Policy

```text
EC2 worker node
      | IAM role
      v
EKS node role
      +--> EKS worker operations
      +--> ECR image pull
      +--> VPC CNI networking
```

The node IAM role is different from Kubernetes RBAC permissions.

## 5. Build Role vs Deploy Role

A major security decision was to separate the CodeBuild roles.

### Build role

The build role is used by the Docker image build project. Responsibilities include CloudWatch Logs, CodePipeline artifact access, ECR authentication, application image push, and private base-image pull.

### Deploy role

The deployment project uses a dedicated role for EKS deployment responsibilities, including EKS cluster discovery and authentication through AWS tooling.

## 6. Why Separate Build and Deploy Roles?

Using one role would give the build environment both image-publishing and Kubernetes deployment privileges. Separating the roles reduces blast radius and makes security review easier.

Decision: separate build and deploy roles.

Reason: least privilege, smaller blast radius, clearer ownership, and easier auditing.

## 7. ECR Permissions

The build role needs two different ECR capabilities.

Application repository: CodeBuild pushes application images into the OTT ECR repository.

Base-image repository: CodeBuild pulls the shared private base image from the dedicated base-images repository.

Required read actions for the base-image repository include:
- ecr:BatchCheckLayerAvailability
- ecr:GetDownloadUrlForLayer
- ecr:BatchGetImage

The role also needs ecr:GetAuthorizationToken for ECR authentication.

### Real issue encountered

The initial build failed with an ECR HTTP 403 while pulling the private base image. The role could push to the application repository but lacked read permissions for the base-images repository. The permission was corrected through Terraform.

Lesson: ECR permissions are repository-specific; push access to one private repository does not automatically provide pull access to another.

## 8. CodeBuild IAM Trust

The CodeBuild roles trust the CodeBuild service.

```text
AWS CodeBuild
      | sts:AssumeRole
      v
CodeBuild IAM role
```

The human SSO administrator is not allowed to manually assume the deployment role simply for testing. The trust relationship is intentionally scoped to CodeBuild.

## 9. EKS Authentication vs Kubernetes Authorization

This distinction is critical.

AWS IAM answers: Who are you in AWS?
Kubernetes RBAC answers: What are you allowed to do inside Kubernetes?

```text
CodeBuild
   |
   | AWS IAM role
   v
AWS authentication
   |
   v
EKS authentication
   |
   v
Kubernetes identity
   |
   v
Kubernetes RBAC
```

The project currently uses the EKS aws-auth ConfigMap to map IAM roles into Kubernetes identities.

## 10. EKS aws-auth Mapping

The Terraform-managed mapping includes the EKS worker node role and the deployment CodeBuild role.

Worker nodes map to system:bootstrappers and system:nodes.

The deployment CodeBuild role maps to the Kubernetes group ott-platform-deployer. A ClusterRoleBinding associates that group with deployment permissions.

```text
Deploy CodeBuild IAM role
        |
        v
aws-auth
        |
        v
ott-platform-deployer group
        |
        v
ClusterRole
        |
        v
Kubernetes deployment permissions
```

## 11. Kubernetes RBAC for Deployment

The deployment group currently has permissions over resources required by the OTT Helm deployment, including ConfigMaps, Secrets, Services, ServiceAccounts, PersistentVolumeClaims, Deployments, StatefulSets, Roles, RoleBindings, ClusterRoles, and ClusterRoleBindings.

Current verbs include get, list, watch, create, update, patch, and delete.

Security consideration: these permissions should be narrowed after the Helm deployment becomes stable and the exact resource operations are known.

## 12. Why IAM Alone Is Not Enough

For example, giving CodeBuild eks:DescribeCluster permission does not mean CodeBuild can run kubectl get nodes.

The AWS API permission allows the client to obtain cluster information. Kubernetes RBAC decides whether the authenticated Kubernetes identity can list Node resources.

During deployment testing:

```text
kubectl cluster-info
       |
       +--> succeeded

kubectl get nodes
       |
       +--> Forbidden
```

The deployment buildspec was changed to validate cluster connectivity without requiring unnecessary node-list permission.

## 13. Secret Access — Current and Planned

The application currently expects a Kubernetes Secret named ott-secrets. Auth and Catalog reference PostgreSQL credentials and the JWT secret from it.

The secret is currently missing from the cluster, which causes CreateContainerConfigError. This is a known application deployment issue.

Planned portable architecture:

```text
Application
    |
    v
Kubernetes Secret: ott-secrets
    ^
    |
External Secrets Operator
    ^
    |
Provider-specific secret backend
```

AWS will use AWS Secrets Manager. Azure will use Azure Key Vault. Other environments can use HashiCorp Vault.

This keeps the application-facing Kubernetes Secret interface portable while allowing provider-specific identity and secret mechanisms.

## 14. What Must Never Be Stored in Git

Never commit:
- AWS access keys
- AWS secret access keys
- SSO credentials
- Database passwords
- JWT signing secrets
- MinIO production passwords
- API tokens
- Private certificates
- Kubernetes service-account tokens

Terraform variables and Helm values should contain references or non-sensitive configuration rather than real production secrets.

## 15. Current IAM Security Gaps

### 15.1 Build role has an unnecessary EKS permission

The general build role currently contains an EKS DescribeCluster permission that is not required for image building.

Planned: remove it from the build role and keep EKS access only in the deployment role.

### 15.2 Deployment RBAC is broader than the final requirement

The current ClusterRole includes several resource types and verbs. Planned: reduce permissions after the Helm deployment becomes stable.

### 15.3 AdministratorAccess for human setup

The current human permission set uses AdministratorAccess. This is practical for the initial infrastructure build, but a production operating model should introduce narrower permission sets for normal operations.

## 16. IAM Design Rules

1. Prefer temporary credentials over long-lived access keys.
2. Use IAM Identity Center for human AWS access.
3. Separate human, infrastructure, build, deployment, and workload identities.
4. Use dedicated IAM roles for AWS services.
5. Scope ECR permissions to required repositories.
6. Do not give the build role unnecessary EKS permissions.
7. Use Kubernetes RBAC for Kubernetes authorization.
8. Never store application secrets in Git.
9. Use a portable Kubernetes Secret interface for applications.
10. Use provider-native secret stores behind External Secrets Operator.
11. Review permissions after every architecture change.
12. Treat least privilege as an iterative process.

## 17. Verification Commands

Verify the active AWS identity:

```powershell
aws sts get-caller-identity --profile ott-admin
```

List policies attached to a role:

```powershell
aws iam list-role-policies --role-name ott-platform-github-codebuild-role --profile ott-admin
```

Read an inline role policy:

```powershell
aws iam get-role-policy --role-name ott-platform-github-codebuild-role --policy-name ott-platform-github-codebuild-ecr --profile ott-admin
```

Verify Kubernetes authorization through the actual CI/CD identity rather than weakening the CodeBuild trust relationship for interactive testing.

## 18. IAM vs Kubernetes RBAC — Interview View

| Layer | Technology | Main question |
|---|---|---|
| Human authentication | IAM Identity Center | Who is the human? |
| AWS authorization | IAM | What AWS APIs can the identity call? |
| EKS authentication | EKS/IAM integration | Which Kubernetes identity does the AWS role map to? |
| Kubernetes authorization | RBAC | Which Kubernetes resources can the identity access? |
| Application secret delivery | ESO + provider backend | How does the workload receive secrets? |

## 19. Current vs Target

### Current
- IAM Identity Center for human access
- Separate EKS cluster and node roles
- Separate CodeBuild build and deploy roles
- ECR repository-scoped build permissions
- EKS aws-auth role mapping
- Kubernetes RBAC for deployment
- AWS Secrets Manager manages the RDS master password
- Application secret delivery is not yet completed

### Target
- Least-privilege human permission sets
- Least-privilege CodeBuild build role
- Least-privilege deployment role
- Narrow Kubernetes RBAC
- External Secrets Operator
- AWS Secrets Manager backend on AWS
- Azure Key Vault backend on Azure
- Provider-specific workload identity
- No secrets in Git
- Auditable identity and authorization boundaries

## 20. Related Documentation

- [Terraform](../infrastructure/terraform.md)
- [EKS](../infrastructure/eks.md)
- [AWS CI/CD](../cicd/aws-cicd.md)
- [Secrets Management](./secrets.md)
- [Troubleshooting](../troubleshooting/issue-log.md)
- [Project History](../project-history.md)