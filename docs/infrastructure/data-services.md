# Managed PostgreSQL and Redis

## RDS PostgreSQL
- Database: `ottdb`
- Username: `ottadmin`
- Engine: PostgreSQL 17
- Instance: `db.t3.micro`
- Port: 5432
- Endpoint: `ott-platform-dev-postgres.cglme6k8amk5.us-east-1.rds.amazonaws.com`

The Terraform RDS resource uses `manage_master_user_password = true`, so the master password is AWS-managed rather than stored in Terraform variables or Git.

## ElastiCache Redis
- Engine: Redis 7.1
- Node: `cache.t3.micro`
- Port: 6379
- Endpoint: `master.ott-platform-dev-redis.kwbhne.use1.cache.amazonaws.com`

## Application integration gap
Current Auth/Catalog manifests still use legacy `POSTGRES_HOST=postgres` and `REDIS_HOST=redis`. These must be changed to the managed-service configuration as part of the runtime configuration work.

The in-cluster PostgreSQL and Redis Helm resources are disabled in development.
