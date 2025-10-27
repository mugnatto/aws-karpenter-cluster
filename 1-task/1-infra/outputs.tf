# Outputs for 1-infra stage

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = module.eks.oidc_provider_url
}

output "karpenter_node_iam_role_arn" {
  description = "IAM role ARN for Karpenter-managed nodes"
  value       = module.eks.karpenter_node_iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "IAM role name for Karpenter-managed nodes"
  value       = module.eks.karpenter_node_iam_role_name
}

output "karpenter_iam_role_arn" {
  description = "ARN of the Karpenter IAM role"
  value       = module.karpenter_iam.karpenter_iam_role_arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = module.eks.cluster_creator_arn
}
