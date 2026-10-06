terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

resource "kubernetes_manifest" "secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"

    metadata = {
      name      = "aws-secrets-manager"
      namespace = var.namespace
    }

    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
        }
      }
    }
  }
}

resource "kubernetes_manifest" "ott_secrets" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"

    metadata = {
      name      = "ott-secrets"
      namespace = var.namespace
    }

    spec = {
      refreshInterval = "1h"

      secretStoreRef = {
        name = kubernetes_manifest.secret_store.manifest.metadata.name
        kind = "SecretStore"
      }

      target = {
        name           = "ott-secrets"
        creationPolicy = "Owner"

        template = {
          engineVersion = "v2"
          data = {
            POSTGRES_USER     = "{{ .POSTGRES_USER }}"
            POSTGRES_PASSWORD = "{{ .POSTGRES_PASSWORD }}"
            POSTGRES_DB       = var.database_name
            JWT_SECRET        = "{{ .JWT_SECRET }}"
          }
        }
      }

      data = [
        {
          secretKey = "POSTGRES_USER"
          remoteRef = {
            key      = var.rds_secret_arn
            property = "username"
          }
        },
        {
          secretKey = "POSTGRES_PASSWORD"
          remoteRef = {
            key      = var.rds_secret_arn
            property = "password"
          }
        },
        {
          secretKey = "JWT_SECRET"
          remoteRef = {
            key      = var.application_secret_arn
            property = "JWT_SECRET"
          }
        }
      ]
    }
  }
}