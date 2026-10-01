# Kubernetes Interview Questions

## Fundamentals
### 1. Why Kubernetes for the OTT platform?
**Answer:** It provides scheduling, service discovery, rolling deployments, resource management and a common application platform across EKS, AKS and bare-metal Kubernetes.

### 2. Explain the namespace architecture.
**Answer:** Frontend -> ott-frontend; Auth/Catalog/Stream -> ott-backend; MinIO/media -> ott-media.

### 3. What does Helm provide?
**Answer:** Helm packages Kubernetes resources into releases and provides reusable environment values.

### 4. Why not deploy manually with Helm?
**Answer:** The project requires CI/CD-driven deployment for repeatability and auditability.

### 5. Why does Terraform manage namespaces while Helm manages application resources?
**Answer:** It creates clear ownership and avoids two tools managing the same Kubernetes object.

### 6. Authentication versus authorization?
**Answer:** Authentication establishes identity. RBAC determines what that identity can do.

### 7. Why did kubectl get nodes fail from CodeBuild?
**Answer:** The identity authenticated but lacked permission to list Node resources cluster-wide.

### 8. Why did kubectl cluster-info succeed?
**Answer:** It verifies API connectivity without requiring cluster-wide Node list permission.

### 9. What is the Stream service's Kubernetes role?
**Answer:** It needs permission to create and manage video-processing Jobs. Current RBAC includes Job create/get/list/delete.

### 10. Explain the Stream workflow.
**Answer:** Stream receives upload, stores raw media in MinIO, creates a Kubernetes Job, FFmpeg transcodes HLS, and output is stored in MinIO.

## Runtime troubleshooting
### 11. Pod is CreateContainerConfigError. What do you check?
**Answer:** Describe the pod and inspect Events. In this project, Auth/Catalog events showed ott-secrets was missing.

### 12. Pod is Pending. What do you check?
**Answer:** Describe the pod and inspect scheduling events, node capacity, PVC binding, affinity, taints/tolerations and resource requests.

### 13. Pod is Running but API is unreachable.
**Answer:** Check Service selectors, endpoints, container port, readiness and namespace.

### 14. Deployment rollout is stuck.
**Answer:** Inspect Deployment, ReplicaSet, pod events, image availability, probes, resources and application logs.

## Scenario-based
### 15. New image is in ECR but Kubernetes runs the old image.
**Answer:** Check Deployment image, Helm values, rendered manifest and rollout. Pushing to ECR alone does not update a Deployment.

### 16. Helm says a resource already exists and is not owned.
**Answer:** Check ownership and decide which tool should own it. The project chose Terraform for namespaces and Helm for application resources.

### 17. Stream cannot create FFmpeg Jobs.
**Answer:** Check Stream logs, ServiceAccount, RBAC, target namespace and Kubernetes API errors.

### 18. MinIO is Pending.
**Answer:** Start with pod events, then inspect PVC, StorageClass, node capacity and scheduling constraints before changing manifests.

### 19. A namespace disappears after infrastructure changes.
**Answer:** Determine whether Terraform, Helm or a manual action owns it. Avoid duplicate ownership.

### 20. How would you secure ServiceAccounts?
**Answer:** Use dedicated accounts, disable unnecessary token automounting where possible, apply least privilege and use cloud workload identity when AWS/Azure access is required.