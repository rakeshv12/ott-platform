# Kubernetes Platform

## Namespace model
```text
EKS
├── ott-frontend
│   └── Frontend
├── ott-backend
│   ├── Auth
│   ├── Catalog
│   └── Stream
└── ott-media
    └── MinIO
```

The Helm chart is under `Helm/ott`. Development values disable in-cluster PostgreSQL and Redis because AWS managed services are the target.

Application deployment is intended to happen through CI/CD, not manual Helm commands from a developer workstation.

## Current reconciliation items
1. Auth/Catalog reference missing `ott-secrets`.
2. Auth/Catalog still reference legacy database/cache hostnames.
3. Frontend Deployment/Service namespace alignment needs final reconciliation.
4. MinIO is currently Pending and needs a separate storage/scheduling investigation.
