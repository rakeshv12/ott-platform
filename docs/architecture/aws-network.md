# AWS Network Architecture

## Implemented
- Region: `us-east-1`
- VPC: `10.0.0.0/16`
- AZs: `us-east-1a`, `us-east-1b`
- Two public and two private subnets.
- Internet Gateway.
- Public/private route tables.
- One NAT Gateway for development.
- VPC endpoints for S3, ECR API, ECR DKR and Secrets Manager.
- EKS workers run in private subnets.

## CIDR layout
| Network | CIDR |
|---|---|
| VPC | 10.0.0.0/16 |
| Public AZ-a | 10.0.0.0/20 |
| Public AZ-b | 10.0.16.0/20 |
| Private AZ-a | 10.0.32.0/20 |
| Private AZ-b | 10.0.48.0/20 |

## Flow
```text
Internet -> Internet Gateway -> Public subnet -> NAT Gateway
        -> Private subnet -> EKS worker -> Pod
```

NAT was added after private EKS workers lacked required outbound connectivity. VPC endpoints provide private paths for supported AWS services.

## Production considerations
Evaluate one NAT Gateway per AZ for availability. Tighten endpoint security groups to required workload security groups. Keep worker nodes private and expose applications through controlled ingress/load-balancing layers.
