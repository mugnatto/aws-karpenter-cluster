# 1-infra: VPC + EKS + IAM Resources
# This creates the foundational infrastructure for the Karpenter cluster

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Stage       = "1-infra"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../terraform/modules/vpc"
  
  name_prefix = "${var.project_name}-${var.environment}"
  vpc_cidr    = var.vpc_cidr
  az_count    = var.az_count
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Stage       = "1-infra"
  }
}

# EKS Module
module "eks" {
  source = "../../terraform/modules/eks"
  
  cluster_name        = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  subnet_ids          = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  private_subnet_ids  = module.vpc.private_subnet_ids
  vpc_id              = module.vpc.vpc_id
  public_access_cidrs = var.public_access_cidrs
  log_retention_days  = var.log_retention_days
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Stage       = "1-infra"
  }
}

# Karpenter IAM Module (only IAM roles, no Kubernetes resources)
module "karpenter_iam" {
  source = "../../terraform/modules/karpenter-iam"

  cluster_name         = module.eks.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  karpenter_namespace = var.karpenter_namespace
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Stage       = "1-infra"
  }

  depends_on = [module.eks]
}