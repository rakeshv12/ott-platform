# Security and Secrets

## Current state
No Terraform-managed application Secret named `ott-secrets` exists, and External Secrets Operator is not installed. Auth and Catalog therefore fail with `CreateContainerConfigError` because the referenced Secret is missing.

## Multi-cloud decision
The application should consume:
```text
Auth/Catalog
    -> Kubernetes Secret: ott-secrets
    -> External Secrets Operator
       -> AWS Secrets Manager
       -> Azure Key Vault
       -> HashiCorp Vault (bare metal)
```

This is **planned**, not implemented.

The earlier idea of using EKS Pod Identity for ESO is AWS-specific. It can be used behind the AWS provider layer, but the application contract must remain portable across EKS, AKS and bare-metal Kubernetes.

## Rules
- Never commit passwords, tokens or access keys.
- Do not put the RDS password in `terraform.tfvars`.
- Do not hardcode application credentials in Helm values.
- Use least-privilege provider permissions.
