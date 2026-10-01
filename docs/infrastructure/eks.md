# Amazon EKS

## Implemented
- Cluster: `ott-platform-dev`
- Kubernetes: `1.33`
- Two private worker nodes across two AZs.
- Node type: `t3.medium`
- Minimum/desired nodes: 2
- Maximum nodes: 4
- Public and private cluster endpoints currently enabled.

## Authentication and RBAC
The cluster currently uses EKS `CONFIG_MAP` authentication. Terraform manages `aws-auth` mappings for the node role and CodeBuild deployment group.

A ClusterRole named `ott-platform-deployer` is bound to group `ott-platform-deployer`.

## Troubleshooting lesson
`kubectl get nodes` from the CodeBuild deployment identity returned Forbidden because node-list permission was not granted. This was an RBAC authorization result, not an API connectivity failure. The verification command was changed to `kubectl cluster-info`, which verifies connectivity without broad node-read permissions.

## Hardening
Review private-only/tightly restricted API access, namespace-scoped deployment permissions, and removal of unnecessary EKS permissions from the general build role.
