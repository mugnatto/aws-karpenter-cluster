# EKS Module Outputs

output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "karpenter_node_iam_role_arn" {
  description = "IAM role ARN for Karpenter-managed nodes"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_iam_role_name" {
  description = "IAM role name for Karpenter-managed nodes"
  value       = aws_iam_role.karpenter_node.name
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_creator_arn" {
  description = "ARN of the IAM principal that created the cluster"
  value       = data.aws_caller_identity.current.arn
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "karpenter_nodes_security_group_id" {
  description = "Security group ID for Karpenter-managed nodes"
  value       = aws_security_group.karpenter_nodes.id
}