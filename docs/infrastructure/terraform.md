# Terraform Infrastructure

## Structure
```text
terraform/
├── bootstrap/
├── environments/aws/dev/
└── modules/
    ├── CICD
    ├── ecr
    ├── eks
    ├── iam
    ├── network
    ├── rds
    ├── redis
    └── s3
```

## State
Development state uses S3:
- Bucket: `ott-platform-terraform-state-use1-dev`
- Region: `us-east-1`
- Key: `aws/dev/terraform.tfstate`

Terraform state and `.terraform/` are excluded from Git.

## Practices
Run `terraform fmt`, `terraform validate` and `terraform plan` before changes. Targeted applies have been used for deliberately narrow changes. In PowerShell, target arguments may need quoting.

## Design principle
Reusable modules hold infrastructure logic; environment configuration supplies environment-specific values.
