output "karpenter_iam_role_arn" {
  description = "ARN of the Karpenter IAM role"
  value       = aws_iam_role.karpenter.arn
}
