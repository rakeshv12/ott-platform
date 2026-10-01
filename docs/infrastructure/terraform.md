
# Terraform Infrastructure — Pin-to-Pin Engineering Record

> This document records how Terraform is actually used in the OTT platform, how the modules connect, what was created, the commands used, the errors encountered, the fixes applied, and the reasoning behind the architecture.
>
> It is an implementation record, not a generic Terraform tutorial. Target architecture is explicitly marked Planned.

## 1. Terraform's role

Terraform is the infrastructure-as-code layer for the AWS environment.

~~~text
Terraform
  |
  +-- AWS networking
  +-- EKS
  +-- IAM
  +-- ECR
  +-- RDS PostgreSQL
  +-- ElastiCache Redis
  +-- S3 / CI-CD artifacts
  +-- CodeConnections
  +-- CodePipeline
  +-- CodeBuild
  |
  +-- Selected Kubernetes platform objects
       +-- aws-auth mapping
       +-- namespaces
       +-- deployment RBAC
~~~

Terraform does not contain application source code and does not replace Helm. Helm remains the application packaging/deployment mechanism.

## 2. Repository architecture

~~~text
terraform/
├── bootstrap/
│   └── Creates the Terraform state bucket
├── environments/
│   └── aws/
│       └── dev/
│           ├── main.tf
│           ├── providers.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars
└── modules/
    ├── CICD/
    ├── ecr/
    ├── eks/
    ├── iam/
    ├── network/
    ├── rds/
    ├── redis/
    └── s3/
~~~

The separation is:

~~~text
Reusable implementation
        |
        v
terraform/modules/*
        ^
        |
Environment-specific inputs
        |
        v
terraform/environments/aws/dev/*
~~~

The development environment supplies region, CIDR, AZs, sizing and names. Reusable modules contain infrastructure logic.

## 3. Bootstrap and remote state

Remote state cannot depend on a state bucket that does not exist yet.

~~~text
First-time setup
      |
      v
Terraform Bootstrap
      |
      v
S3 Terraform State Bucket
      |
      v
Dev Terraform initialization
      |
      v
Remote Terraform State
~~~

Current state bucket:

- Bucket: ott-platform-terraform-state-use1-dev
- Region: us-east-1
- Key: aws/dev/terraform.tfstate

The Terraform state bucket is separate from the CodePipeline artifact bucket.

### Why separate the buckets?

Terraform state and CI/CD artifacts have different security and lifecycle requirements. Keeping them separate avoids giving CI/CD roles unnecessary access to infrastructure state.

### Current limitation

Terraform 1.16 S3 native locking using use_lockfile = true should be evaluated. It is not currently documented as implemented.

## 4. Provider architecture

The environment uses two providers:

~~~text
Terraform
  |
  +--> AWS Provider
  |
  +--> Kubernetes Provider
~~~

AWS creates and reads AWS infrastructure.

The Kubernetes provider manages selected Kubernetes platform resources after EKS exists.

Authentication flow:

~~~text
Terraform
   |
   +--> aws_eks_cluster
   |       +--> API endpoint
   |       +--> CA certificate
   |
   +--> aws_eks_cluster_auth
           +--> temporary authentication token
~~~

The Kubernetes provider uses the EKS endpoint, decoded cluster CA and temporary EKS authentication token. No permanent Kubernetes password is placed in the provider configuration.

## 5. AWS authentication and SSO

The current development provider uses the AWS CLI profile ott-admin.

~~~hcl
provider "aws" {
  region  = var.aws_region
  profile = "ott-admin"
}
~~~

Development authentication flow:

~~~text
IAM Identity Center
      |
aws sso login --profile ott-admin
      |
temporary AWS credentials
      |
Terraform AWS provider
~~~

Verification:

~~~powershell
aws sts get-caller-identity --profile ott-admin
~~~

No AWS access keys are stored in Terraform files.

## 6. Variable flow

The development values flow through the environment layer into modules:

~~~text
terraform.tfvars
      |
      v
variables.tf
      |
      v
environments/aws/dev/main.tf
      |
      +------------------+
      |                  |
      v                  v
network module       EKS module
      |
      v
module outputs
      |
      v
dependent modules
~~~

Current important values include:

- Region: us-east-1
- VPC: 10.0.0.0/16
- AZs: us-east-1a, us-east-1b
- Project: ott-platform
- Environment: dev
- EKS: ott-platform-dev
- Kubernetes: 1.33
- Worker type: t3.medium
- Desired nodes: 2
- Maximum nodes: 4
- PostgreSQL database: ottdb
- Redis: 7.1
- CI/CD resource names
- Kubernetes namespace names

The design goal is to avoid putting environment-specific values inside reusable modules.

## 7. Module dependency architecture

~~~text
                    +--> ECR
                    |
Network -----------> EKS
   |                  |
   |                  +--> Kubernetes provider resources
   |
   +--> RDS
   |
   +--> Redis

ECR + EKS + GitHub configuration
              |
              v
             CICD
              |
              +--> CodeConnections
              +--> CodePipeline
              +--> Build CodeBuild
              +--> Deploy CodeBuild
              +--> artifact S3
~~~

Terraform creates dependencies from references such as module.network.vpc_id and module.network.private_subnet_ids.

## 8. Network module

Implemented VPC architecture:

~~~text
VPC 10.0.0.0/16
|
+-- us-east-1a
|   +-- Public:  10.0.0.0/20
|   +-- Private: 10.0.32.0/20
|
+-- us-east-1b
    +-- Public:  10.0.16.0/20
    +-- Private: 10.0.48.0/20
~~~

The subnet module uses Terraform cidrsubnet.

Public subnet calculation uses newbits 4 and indexes 0 and 1.

Private subnet calculation uses newbits 4 and indexes 2 and 3.

A /16 VPC split with four /20 subnets provides 4096 IPv4 addresses per subnet CIDR before AWS-reserved addresses.

## 9. Public routing

The network module creates:

- Internet Gateway
- Public route table
- Default route 0.0.0.0/0 through the Internet Gateway
- Public subnet associations

Flow:

~~~text
Public subnet
     |
Public Route Table
     |
0.0.0.0/0
     |
Internet Gateway
     |
Internet
~~~

Public subnets enable public IP assignment on launch.

## 10. Private routing and NAT

Private subnets do not assign public IP addresses on launch.

The development environment uses one NAT Gateway in the first public subnet.

Flow:

~~~text
Private EKS node
      |
Private Route Table
      |
NAT Gateway
      |
Internet Gateway
      |
Internet
~~~

### Important EKS troubleshooting event

The EKS worker nodes initially could not complete required outbound/bootstrap activity because the private subnet did not have a general outbound path.

The infrastructure was changed to create:

1. Elastic IP
2. NAT Gateway
3. Private default route through NAT

After the NAT path was established, the EKS nodes became Ready.

### Development decision

One NAT Gateway is currently used to reduce development cost.

### Production consideration

Production should evaluate one NAT Gateway per AZ for higher availability, balanced against cost.

## 11. VPC endpoints

The network module creates:

- S3 Gateway endpoint
- ECR API Interface endpoint
- ECR DKR Interface endpoint
- Secrets Manager Interface endpoint

Flow:

~~~text
Private workload
      |
      +--> S3 endpoint --------> S3
      +--> ECR API endpoint ---> ECR API
      +--> ECR DKR endpoint ---> ECR registry
      +--> Secrets endpoint ---> Secrets Manager
~~~

VPC endpoints reduce unnecessary NAT dependency for supported AWS services.

### Current security limitation

The endpoint security group currently permits HTTPS from the VPC CIDR. Production should narrow this to the required workload security groups.

## 12. EKS Terraform architecture

The EKS module creates:

- EKS cluster
- EKS cluster IAM role
- EKS node IAM role
- Managed node group
- Required IAM policy attachments

Current cluster:

~~~text
Name: ott-platform-dev
Kubernetes: 1.33
Worker subnets: private
Worker type: t3.medium
Min: 2
Desired: 2
Max: 4
~~~

Architecture:

~~~text
EKS Control Plane
        |
        | Kubernetes API
        |
Private Worker Nodes
   +-------------+
   |             |
Node AZ-a     Node AZ-b
~~~

Managed node group updates use max_unavailable = 1.

## 13. EKS IAM

Two major IAM roles are separated:

### Cluster role

Used by the EKS control plane.

### Node role

Used by worker EC2 instances.

Node role currently includes:

- AmazonEKSWorkerNodePolicy
- AmazonEC2ContainerRegistryPullOnly
- AmazonEKS_CNI_Policy

Flow:

~~~text
EKS Control Plane
      |
Cluster IAM Role

EC2 Worker
      |
Node IAM Role
      +--> EKS worker operations
      +--> ECR image pulls
      +--> VPC CNI
~~~

## 14. EKS endpoint decision

Current configuration enables both public and private endpoint access.

Why:

- workstation administration is required during development
- VPC resources can use private API access

Production should evaluate private-only access or tightly restricted public CIDRs.

An EKS replacement shown in a Terraform plan is considered a high-risk change and must be investigated before apply.

## 15. EKS authentication and aws-auth

The cluster currently uses CONFIG_MAP authentication.

Terraform manages aws-auth mappings for:

1. EKS node role
2. Dedicated deployment CodeBuild role

The deployment identity flow is:

~~~text
CodeBuild IAM Role
       |
       v
aws-auth
       |
       v
Kubernetes group: ott-platform-deployer
       |
       v
ClusterRoleBinding
       |
       v
ClusterRole: ott-platform-deployer
~~~

## 16. Kubernetes provider dependency

The environment reads:

~~~hcl
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}
~~~

The Kubernetes provider then consumes the endpoint, CA certificate and temporary token.

The aws-auth resource depends on the EKS and CI/CD modules so that the required AWS-side resources exist first.

## 17. Kubernetes namespaces

Terraform manages:

- ott-frontend
- ott-backend
- ott-media

Ownership model:

~~~text
Terraform
   |
   +--> namespaces

Helm
   |
   +--> application resources inside namespaces
~~~

This was intentionally chosen to prevent Terraform and Helm from both trying to own the same namespace.

## 18. Helm namespace ownership error

An earlier manual Helm deployment encountered a namespace ownership conflict because a namespace already existed and was not owned by the Helm release.

The project therefore adopted:

~~~text
Terraform owns namespaces
Helm owns application resources
~~~

This is a resource ownership decision. The same Kubernetes object should not be independently managed by two tools.

## 19. Kubernetes deployment RBAC

Terraform creates the deployment ClusterRole and ClusterRoleBinding.

The role includes resources required by the current Helm deployment such as:

- ConfigMaps
- Secrets
- Services
- ServiceAccounts
- PersistentVolumeClaims
- Deployments
- StatefulSets
- Roles
- RoleBindings
- ClusterRoles
- ClusterRoleBindings

The permissions are currently broader than ideal for production and should be narrowed after the exact Helm resource set is finalized.

## 20. RBAC error: kubectl get nodes

The deploy identity was tested with:

~~~bash
kubectl get nodes
~~~

and received:

~~~text
Error from server (Forbidden):
nodes is forbidden:
User "ott-platform-codebuild" cannot list resource "nodes"
at the cluster scope
~~~

### Root cause

The deployment identity could authenticate to the cluster but was not authorized to list nodes at cluster scope.

### Fix

The unnecessary node-list verification was removed.

The deploy stage now uses:

~~~bash
kubectl cluster-info
~~~

This verifies Kubernetes API connectivity without granting broad cluster-wide node-list permission.

### Lesson

Authentication and authorization are separate:

~~~text
Authentication success
        !=
Authorization for every Kubernetes resource
~~~

Do not expand RBAC merely to make an unnecessary diagnostic command succeed.

## 21. ECR Terraform architecture

The project uses separate ECR repositories conceptually:

~~~text
ECR
|
+-- ott-platform-dev
|     +-- auth:<commit>
|     +-- catalog:<commit>
|     +-- stream:<commit>
|     +-- frontend:<commit>
|
+-- ott-platform-base-images
      +-- trusted shared base images
~~~

The application repository needs push permissions.

The base-image repository needs pull permissions for CodeBuild.

## 22. ECR 403 error

The Build CodeBuild project initially failed while pulling the private base image.

The important distinction was:

~~~text
GetAuthorizationToken
+
Application ECR push permissions
        !=
Base-image ECR pull permissions
~~~

### Root cause

The base image was stored in a different ECR repository from the application images.

### Fix

Terraform added the base image repository ARN to the CICD module and granted CodeBuild:

- ecr:BatchCheckLayerAvailability
- ecr:GetDownloadUrlForLayer
- ecr:BatchGetImage

against the base-image repository.

### Result

The Build stage subsequently succeeded.

### Lesson

IAM must be evaluated as Principal + Action + Resource, not simply "does this role have ECR access?"

## 23. RDS Terraform architecture

Terraform provisions PostgreSQL through the RDS module.

Current development configuration:

- Database: ottdb
- Username: ottadmin
- PostgreSQL: 17
- Instance: db.t3.micro
- Port: 5432

The resource uses AWS-managed master-password management:

~~~hcl
manage_master_user_password = true
~~~

Therefore the password is not placed into terraform.tfvars or committed to Git.

Flow:

~~~text
Private EKS workload
       |
       | TCP 5432
       v
RDS PostgreSQL
~~~

### Application integration gap

Some application templates still use POSTGRES_HOST=postgres, while PostgreSQL is now an AWS managed service.

That is an application configuration issue to fix next; it is not evidence that the RDS Terraform module failed.

## 24. Redis Terraform architecture

ElastiCache Redis is provisioned by Terraform.

Current development configuration:

- Redis 7.1
- cache.t3.micro
- Port 6379

Flow:

~~~text
Auth/Catalog
     |
 TCP 6379
     |
ElastiCache Redis
~~~

The application still contains legacy REDIS_HOST=redis configuration and must be aligned with the managed AWS endpoint.

## 25. CI/CD Terraform architecture

Terraform creates:

~~~text
GitHub
   |
CodeConnections
   |
CodePipeline V2
   |
   +--> Build CodeBuild
   |       |
   |       +--> Docker images
   |       +--> ECR
   |
   +--> Deploy CodeBuild
           |
           +--> kubectl
           +--> Helm
           +--> EKS
~~~

Terraform manages the CodeConnections connection, pipeline, CodeBuild projects, IAM roles/policies, artifact bucket and related configuration.

## 26. Why separate Build and Deploy roles?

Build:

~~~text
Build Role
   +--> Docker build
   +--> ECR push
~~~

Deploy:

~~~text
Deploy Role
   +--> EKS deployment
   +--> kubectl/Helm
~~~

This reduces the privilege boundary of the Docker build process.

## 27. CodePipeline V2 decision

The pipeline was changed to V2 with a Git-based CodeConnections trigger.

Flow:

~~~text
git push main
     |
     v
GitHub App / CodeConnections
     |
     v
CodePipeline V2
~~~

No manually created GitHub webhook was required.

## 28. GitHub CodeConnections error

The AWS connection existed, but the expected automatic GitHub source triggering did not initially work.

### Root cause

The AWS Connector for GitHub had been authorized but had not been installed/connected for the required repository.

### Fix

The CodePipeline source connection was re-established and the AWS GitHub App was installed/connected for rakeshv12/ott-platform.

### Lesson

Terraform creating an AWS CodeConnections resource is only the AWS-side part. External GitHub App authorization/installation must also be completed.

## 29. CodeBuild deploy YAML error

The Deploy CodeBuild project initially failed during source/buildspec processing with a YAML type error similar to:

~~~text
Expected Commands[...] to be of string type:
found subkeys instead
~~~

### Root cause

A command was parsed by YAML as a mapping/subkey rather than as a command string.

### Fix

The buildspec was simplified into explicit command strings.

The Deploy stage then progressed through source download and all CodeBuild phases.

## 30. Current Deploy stage limitation

The latest deploy buildspec:

1. Installs/validates tools.
2. Runs aws eks update-kubeconfig.
3. Runs kubectl cluster-info.
4. Does not currently execute the Helm upgrade/install command.

Therefore a successful EKSDeploy stage currently proves:

~~~text
CodeBuild started
+
source downloaded
+
AWS CLI works
+
kubectl configured
+
EKS API reachable
~~~

It does not yet prove a successful Helm release.

This distinction is intentionally documented.

## 31. PowerShell targeted Terraform error

Targeted applies were used for narrowly scoped troubleshooting changes.

A PowerShell parsing issue occurred when the Terraform target was not quoted.

Working pattern:

~~~powershell
terraform -chdir=terraform/environments/aws/dev apply '-target=module.cicd.aws_iam_role_policy.codebuild_ecr'
~~~

### Lesson

When PowerShell parses a complex Terraform target unexpectedly, quote the complete -target argument.

Targeted apply should be an intentional exception rather than the normal infrastructure workflow.

## 32. Terraform provider typo

Early Terraform initialization contained an incorrect provider source similar to:

~~~text
hashicrop/aws
~~~

instead of:

~~~text
hashicorp/aws
~~~

### Fix

The provider source was corrected to hashicorp/aws and Terraform was initialized again.

### Lesson

Provider registry addresses are exact identifiers.

## 33. SSO expiration error

Terraform depends on the AWS CLI SSO session when using the ott-admin profile.

When the SSO session expired, Terraform could no longer authenticate to AWS.

Recovery:

~~~powershell
aws sso login --profile ott-admin
aws sts get-caller-identity --profile ott-admin
~~~

### Lesson

An expired SSO session can look like a Terraform/provider failure even when the Terraform code is correct.

## 34. EKS access configuration replacement risk

An EKS access configuration change using API_AND_CONFIG_MAP was tested.

Terraform indicated that the existing cluster would require replacement.

The change was removed instead of applying a destructive replacement.

### Decision

The existing CONFIG_MAP authentication model was retained.

### Lesson

When Terraform proposes replacement of an existing EKS cluster, stop and understand the migration path before applying.

## 35. State inspection

Useful commands:

~~~powershell
terraform -chdir=terraform/environments/aws/dev state list
~~~

Specific resource:

~~~powershell
terraform -chdir=terraform/environments/aws/dev state show module.rds.aws_db_instance.database
~~~

Redis:

~~~powershell
terraform -chdir=terraform/environments/aws/dev state show module.redis.aws_elasticache_replication_group.redis
~~~

EKS:

~~~powershell
terraform -chdir=terraform/environments/aws/dev state list | Select-String "eks"
~~~

Important lesson:

~~~text
terraform output
       !=
complete Terraform state
~~~

RDS and Redis existed in state even though their child-module outputs were not exposed at the root.

## 36. Standard Terraform command sequence

~~~powershell
terraform -chdir=terraform/environments/aws/dev init

terraform -chdir=terraform/environments/aws/dev fmt -recursive

terraform -chdir=terraform/environments/aws/dev validate

terraform -chdir=terraform/environments/aws/dev plan

terraform -chdir=terraform/environments/aws/dev apply
~~~

The normal lifecycle is:

~~~text
init
 |
fmt
 |
validate
 |
plan
 |
review
 |
apply
 |
verify
 |
document
~~~

## 37. Targeted apply strategy

Targeted apply was used when one narrowly scoped change needed to be isolated during troubleshooting.

Example:

~~~powershell
terraform -chdir=terraform/environments/aws/dev apply '-target=module.cicd.aws_iam_role_policy.codebuild_ecr'
~~~

After targeted work, a full plan should be reviewed to detect remaining changes or drift.

## 38. Terraform troubleshooting methodology

The project follows:

~~~text
Observe
  |
  v
Identify exact resource
  |
  v
Inspect Terraform state
  |
  v
Inspect AWS/Kubernetes object
  |
  v
Find root cause
  |
  v
Change Terraform source
  |
  v
fmt
  |
  v
validate
  |
  v
plan
  |
  v
apply
  |
  v
verify
  |
  v
document
~~~

This avoids solving infrastructure issues through random manual changes.

## 39. Terraform versus manual changes

Terraform is intended to be the infrastructure source of truth.

Manual AWS Console work was required for external authorization workflows such as the GitHub App installation for CodeConnections.

If a resource is Terraform-managed, future infrastructure changes should normally be made in Terraform.

## 40. Terraform versus CloudFormation

| Area | Terraform | CloudFormation |
|---|---|---|
| AWS resources | Strong | Strong |
| Multi-cloud | Strong | AWS-focused |
| Current AWS + Azure goal | Fits | Less suitable |
| Kubernetes provider model | Available | Different model |
| Selected for this project | Yes | No |

Terraform was selected because the same OTT application architecture will later be reproduced on Azure.

## 41. Terraform versus manual CLI/Console

| Method | Repeatability | Reviewability | Drift control |
|---|---|---|---|
| Console | Low | Low | Low |
| CLI scripts | Medium | Medium | Medium |
| Terraform | High | High | High |

The project uses Terraform for repeatable infrastructure.

## 42. Current resource ownership

| Resource | Owner |
|---|---|
| AWS VPC | Terraform |
| Subnets | Terraform |
| Route tables | Terraform |
| Internet Gateway | Terraform |
| NAT Gateway | Terraform |
| VPC endpoints | Terraform |
| EKS | Terraform |
| EKS node group | Terraform |
| IAM | Terraform |
| ECR | Terraform |
| RDS | Terraform |
| Redis | Terraform |
| CodeConnections | Terraform |
| CodePipeline | Terraform |
| CodeBuild | Terraform |
| CI/CD artifact bucket | Terraform |
| Kubernetes namespaces | Terraform |
| EKS aws-auth | Terraform |
| Deployment RBAC | Terraform |
| Application resources | Helm |
| Application source | GitHub |

This ownership boundary prevents two tools from independently managing the same resource.

## 43. Current known gaps

### Gap 1 — State locking
Evaluate S3 native Terraform locking.

### Gap 2 — EKS public endpoint
Production should restrict or remove public API access where appropriate.

### Gap 3 — NAT availability
Development uses one NAT Gateway. Production may require multi-AZ NAT.

### Gap 4 — Endpoint security group
Current VPC endpoint HTTPS access is broad to the VPC CIDR.

### Gap 5 — General CodeBuild EKS permission
The general build role still has eks:DescribeCluster and should be reviewed for removal when no longer required.

### Gap 6 — Deployment RBAC
The deployment ClusterRole is broader than an ideal production least-privilege role.

### Gap 7 — Application secrets
ott-secrets is missing. External Secrets Operator is planned but not yet implemented.

### Gap 8 — Database/cache application endpoints
Auth/Catalog still contain legacy postgres and redis hostnames.

### Gap 9 — Helm execution
The current CI/CD deploy stage verifies EKS connectivity but does not yet execute Helm.

## 44. Production Terraform target

~~~text
Git
 |
Terraform
 |
+-----------------------------+
| Multi-AZ AWS infrastructure |
+-----------------------------+
 |
+--> VPC
|    +--> private subnets
|    +--> ingress/public subnets
|    +--> VPC endpoints
|    +--> HA NAT
|
+--> EKS
|    +--> private nodes
|    +--> restricted API access
|    +--> least-privilege IAM/RBAC
|
+--> RDS
|    +--> HA/backup strategy
|
+--> Redis
|
+--> ECR
|
+--> CI/CD
|
+--> Secrets Manager
~~~

This is a target design. It is not claimed as fully implemented.

## 45. Project-specific Terraform interview questions

### How does Terraform know this is DEV?
The dev environment supplies values through terraform.tfvars and passes them into reusable modules.

### How does EKS know which subnets to use?
The EKS module receives module.network.private_subnet_ids.

### How does Terraform determine creation order?
Resource and module references create dependency relationships; explicit depends_on is used where the dependency is not represented naturally.

### Why use an S3 backend?
To keep state remote rather than tied to one workstation.

### Why separate bootstrap?
The state bucket must exist before it can be used as the backend.

### Why private worker nodes?
To reduce direct exposure and use controlled ingress/egress.

### Why NAT?
Private workers needed controlled outbound connectivity.

### Why VPC endpoints?
To privately reach supported AWS services and reduce unnecessary NAT dependency.

### Why separate Build and Deploy CodeBuild roles?
To separate ECR image-building permissions from Kubernetes deployment permissions.

### Why did kubectl get nodes fail?
The identity authenticated but did not have cluster-wide node-list authorization.

### Why not grant node-list permission?
It was unnecessary for deployment and would weaken least privilege.

### Why did CodeBuild get ECR 403?
The role had access to the application ECR repository but not the separate private base-image repository.

### Why not store the RDS password in tfvars?
Credentials should not be committed to Git; RDS uses AWS-managed password handling.

### Why was the EKS access configuration change rejected?
Terraform showed that it would replace the existing cluster; a destructive EKS replacement was not acceptable without a migration plan.

### Why does Terraform manage namespaces while Helm manages applications?
To establish clear ownership and avoid Helm ownership conflicts.

## 46. Final engineering principle

The Terraform workflow for this project is:

~~~text
Understand
   ↓
Model
   ↓
Terraform
   ↓
Plan
   ↓
Review
   ↓
Apply
   ↓
Verify
   ↓
Document
~~~

Terraform is being used not merely to create AWS resources, but to demonstrate infrastructure architecture, dependency management, IAM, networking, Kubernetes integration, CI/CD integration, troubleshooting, reproducibility, least privilege, change safety and multi-cloud portability.
