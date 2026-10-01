# CI/CD Interview Questions

## Current pipeline
GitHub -> CodeConnections -> CodePipeline V2 -> Build CodeBuild -> ECR; then Deploy CodeBuild -> EKS.

### 1. Why AWS-native CI/CD?
**Answer:** It integrates directly with AWS IAM, ECR and EKS. Jenkins remains a comparison/reference option but is not the selected AWS deployment path.

### 2. Why separate Build and Deploy CodeBuild projects?
**Answer:** Build needs ECR permissions; Deploy needs EKS/Kubernetes permissions. Separation reduces privilege and blast radius.

### 3. Where does the application build happen?
**Answer:** AWS CodeBuild. GitHub supplies source through CodeConnections and CodePipeline orchestrates the stages.

### 4. How does GitHub trigger the pipeline?
**Answer:** CodeConnections connects the GitHub repository and CodePipeline V2 has a push trigger for main.

### 5. Why use commit-based image tags?
**Answer:** They provide source-to-image traceability and avoid ambiguity from mutable tags.

### 6. What happened with the GitHub trigger?
**Answer:** The AWS GitHub App was not initially fully installed/connected. Reconnecting the source and installing the app resolved the integration.

### 7. What YAML problem happened in Deploy?
**Answer:** A command was parsed as YAML structure instead of a command string. The buildspec was simplified and validated.

### 8. Why was kubectl get nodes removed?
**Answer:** The deployment identity lacked cluster-wide Node list permission. The command was unnecessary, so kubectl cluster-info was used.

### 9. Is the current Deploy stage a completed application deployment?
**Answer:** No. It verifies EKS connectivity and Helm installation, but the current build phase only echoes the Helm deployment step.

## Scenario-based
### 10. GitHub push occurs but pipeline does not start.
**Answer:** Check CodeConnections, GitHub App installation, repository/branch, V2 trigger and source action revision.

### 11. Build succeeds but ECR push fails.
**Answer:** Check ECR authentication, repository ARN permissions, region, repository existence and CodeBuild role.

### 12. Build fails pulling a private base image.
**Answer:** Check GetAuthorizationToken and repository-scoped pull permissions on the base-image repository. This exact failure occurred in the project.

### 13. Deploy says Succeeded but workloads did not change.
**Answer:** Inspect the actual commands and logs. Stage success only means executed commands returned success. The current stage has not executed Helm.

### 14. Pipeline is slow. What do you do?
**Answer:** Measure Source, CodeBuild startup, dependency installation, Docker builds, ECR pushes and deployment separately. Optimize the actual bottleneck.

### 15. How would you safely add Helm deployment?
**Answer:** Use a version-controlled deployment script or carefully validated buildspec, run helm upgrade/install, verify rollout status and fail the build on unhealthy workloads.

### 16. Build role can deploy to EKS. Is that desirable?
**Answer:** No for this design. Remove unnecessary EKS permissions from the build role and keep deployment access in the dedicated role.

### 17. Deployment partially updates workloads.
**Answer:** Inspect Helm release status and Kubernetes rollout status, identify the failed resource and use rollback or a corrected release. Record the root cause.