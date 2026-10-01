# AWS-Native CI/CD

## Selected architecture
```text
GitHub -> CodeConnections -> CodePipeline V2 -> CodeBuild -> ECR -> EKS
```

Build and deploy are separate CodeBuild projects:
- `ott-platform-dev-build`
- `ott-platform-dev-deploy`

Pipeline: `ott-platform-dev-pipeline`

## GitHub integration
The source uses AWS CodeConnections with `rakeshv12/ott-platform` on `main`. Automatic triggering required installation/connection of the AWS GitHub App.

## Private ECR base-image issue
CodeBuild initially received ECR 403 while pulling a private shared base image. Application push permissions did not provide pull permissions for that separate repository. The resolution was repository-scoped ECR read permissions for the base-image repository.

## Deploy buildspec issue
A YAML parsing error occurred because a command was interpreted as YAML structure instead of a command string. The deploy buildspec was simplified and validated.

## Current limitation
The current deploy buildspec installs Helm, runs `aws eks update-kubeconfig`, and runs `kubectl cluster-info`, but its build phase only echoes `Starting Helm deployment...`. Therefore the latest successful deployment stage is **connectivity verification**, not completed Helm deployment.

## Next step
Reintroduce the actual Helm command through a robust deployment script/buildspec and verify resulting workloads.
