module "vpc" {
  source = "./modules/vpc"
  
  name_prefix = "${var.project_name}-${var.environment}"
  vpc_cidr    = "10.0.0.0/16"
  az_count    = 2
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

module "eks" {
  source = "./modules/eks"
  
  cluster_name = "${var.project_name}-${var.environment}"
  subnet_ids = module.vpc.public_subnet_ids
  vpc_id = module.vpc.vpc_id
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}