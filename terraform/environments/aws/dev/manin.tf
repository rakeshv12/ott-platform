module "network" {
  source = "../../../modules/network"

  project_name = "ott-platform"
  environment  = "dev"
  vpc_cidr     = var.vpc_cidr
}