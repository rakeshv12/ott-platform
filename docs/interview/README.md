# OTT Platform Interview Preparation

This section contains the interview question bank for the complete project.

| Topic | Questions |
|---|---|
| Architecture | ../architecture/interview-questions.md |
| Terraform / Infrastructure | ../infrastructure/interview-questions.md |
| CI/CD | ../cicd/interview-questions.md |
| Kubernetes | ../kubernetes/interview-questions.md |
| IAM / Security | ../security/interview-questions.md |
| Troubleshooting | ../troubleshooting/scenario-based-questions.md |

## Preparation method

Do not memorize only the final answer. Be able to explain:

**What -> Why -> How -> Verification -> Failure -> Fix -> Trade-off -> Production improvement**

## Project-specific rule

Clearly separate Implemented, Observed, Decision, Planned and Issue. This prevents overstating current capabilities.

## High-priority scenarios

1. EKS nodes cannot join.
2. CodeBuild cannot pull a private ECR base image.
3. GitHub push does not trigger CodePipeline.
4. Buildspec YAML fails.
5. EKS authentication succeeds but Kubernetes RBAC returns Forbidden.
6. Auth/Catalog shows CreateContainerConfigError.
7. RDS is healthy but application cannot connect.
8. Redis is healthy but application cannot connect.
9. MinIO is Pending.
10. Pipeline succeeds but workloads do not change.
11. Terraform proposes EKS replacement.
12. Helm namespace ownership conflict.
13. New image is in ECR but old image runs.
14. Stream cannot create FFmpeg Jobs.
15. Production readiness review.