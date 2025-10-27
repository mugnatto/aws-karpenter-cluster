# Outputs for 3-karpenter stage

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = data.terraform_remote_state.infra.outputs.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = data.terraform_remote_state.infra.outputs.cluster_endpoint
}

output "aws_region" {
  description = "AWS region"
  value       = data.terraform_remote_state.infra.outputs.aws_region
}
