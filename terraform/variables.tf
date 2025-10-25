variable "aws_region" {
  description = "AWS region where karpenter cluster will be deployed"
  default = "us-east-1"
  type        = string
}

variable "environment" {
  description = "Environment where karpenter cluster will be deployed"
  default = "development"
  type        = string
}
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "karpenter-cluster"
}
