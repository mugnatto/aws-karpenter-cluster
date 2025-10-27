# 3-karpenter: NodePools and EC2NodeClasses
# This creates the Karpenter resources after Helm installation

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
  }
}

# Get values from 1-infra outputs
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "mugnatto-work-ue1-tfstate"
    key    = "aws-karpenter-cluster/1-infra/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = data.terraform_remote_state.infra.outputs.aws_region

  default_tags {
    tags = {
      Environment = "development"
      ManagedBy   = "Terraform"
      Stage       = "3-karpenter"
    }
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infra.outputs.cluster_name, "--region", data.terraform_remote_state.infra.outputs.aws_region]
  }
}

# Karpenter NodePools and EC2NodeClasses
module "karpenter_resources" {
  source = "../../terraform/modules/karpenter"

  cluster_name        = data.terraform_remote_state.infra.outputs.cluster_name
  node_iam_role_name  = data.terraform_remote_state.infra.outputs.karpenter_node_iam_role_name
  
  tags = {
    Environment = "development"
    Project     = "karpenter-cluster"
    ManagedBy   = "Terraform"
    Stage       = "3-karpenter"
  }
}
