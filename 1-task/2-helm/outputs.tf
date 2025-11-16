output "karpenter_release_name" {
  description = "Name of the Karpenter Helm release"
  value       = helm_release.karpenter.name
}

output "karpenter_namespace" {
  description = "Namespace where Karpenter is deployed"
  value       = helm_release.karpenter.namespace
}

output "karpenter_version" {
  description = "Version of Karpenter deployed"
  value       = helm_release.karpenter.version
}

output "nodepool_name" {
  description = "Name of the multi-arch NodePool"
  value       = kubernetes_manifest.multi_arch_nodepool.manifest.metadata.name
}

output "nodeclass_name" {
  description = "Name of the multi-arch EC2NodeClass"
  value       = kubernetes_manifest.multi_arch_nodeclass.manifest.metadata.name
}

output "karpenter_status" {
  description = "Status of the Karpenter Helm release"
  value       = helm_release.karpenter.status
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = data.terraform_remote_state.infra.outputs.cluster_name
}

output "aws_region" {
  description = "AWS region"
  value       = data.terraform_remote_state.infra.outputs.aws_region
}

