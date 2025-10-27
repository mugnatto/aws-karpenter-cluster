# Variables for 1-infra stage

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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.34"
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS API server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "karpenter_version" {
  description = "Version of Karpenter to install"
  type        = string
  default     = "1.8.0"
}

variable "karpenter_namespace" {
  description = "Namespace for Karpenter"
  type        = string
  default     = "karpenter"
}

variable "interruption_queue_name" {
  description = "Name of the SQS queue for spot instance interruptions"
  type        = string
  default     = ""
}
