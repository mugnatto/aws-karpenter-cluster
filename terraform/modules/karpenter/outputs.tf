# Karpenter Module Outputs

output "default_nodepool_name" {
  description = "Name of the default NodePool"
  value       = kubernetes_manifest.default_nodepool.manifest.metadata.name
}

output "graviton_nodepool_name" {
  description = "Name of the Graviton NodePool"
  value       = kubernetes_manifest.graviton_nodepool.manifest.metadata.name
}

output "default_nodeclass_name" {
  description = "Name of the default EC2NodeClass"
  value       = kubernetes_manifest.default_nodeclass.manifest.metadata.name
}

output "graviton_nodeclass_name" {
  description = "Name of the Graviton EC2NodeClass"
  value       = kubernetes_manifest.graviton_nodeclass.manifest.metadata.name
}