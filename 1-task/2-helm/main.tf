terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.0"
    }
  }
}

locals {
  karpenter_version = "1.8.1"
  cluster_name      = data.terraform_remote_state.infra.outputs.cluster_name
}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "mugnatto-work-ue1-tfstate"
    key    = "aws-karpenter-cluster/1-infra/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = data.terraform_remote_state.infra.outputs.aws_region
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.terraform_remote_state.infra.outputs.cluster_name,
      "--region",
      data.terraform_remote_state.infra.outputs.aws_region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        data.terraform_remote_state.infra.outputs.cluster_name,
        "--region",
        data.terraform_remote_state.infra.outputs.aws_region
      ]
    }
  }
}
# I've chosen to create the namespace separate from helm to have better control in case of uninstall.
resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = var.karpenter_namespace
    
    labels = {
      name = var.karpenter_namespace
    }
  }
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = local.karpenter_version
  namespace        = kubernetes_namespace.karpenter.metadata[0].name
  create_namespace = false

  values = [
    templatefile("${path.module}/helm_values.yaml", {
      cluster_name     = local.cluster_name
      cluster_endpoint = data.terraform_remote_state.infra.outputs.cluster_endpoint
      iam_role_arn     = data.terraform_remote_state.infra.outputs.karpenter_iam_role_arn
    })
  ]

  wait    = true
  timeout = 300

  depends_on = [kubernetes_namespace.karpenter]
}

# Multi-Architecture NodePool (AMD64 + ARM64)
resource "kubernetes_manifest" "multi_arch_nodepool" {
  computed_fields = ["spec", "status"]
  
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "multi-arch"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-type" = "general"
          }
        }
        spec = {
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64", "arm64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "t"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            }
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "multi-arch"
          }
          expireAfter = "168h"
        }
      }
      limits = {
        cpu    = "100"
        memory = "200Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  }

  depends_on = [helm_release.karpenter]
}

# Multi-Architecture EC2NodeClass
resource "kubernetes_manifest" "multi_arch_nodeclass" {
  computed_fields = ["spec", "status"]
  
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "multi-arch"
    }
    spec = {
      amiFamily = "Bottlerocket"
      role      = data.terraform_remote_state.infra.outputs.karpenter_node_iam_role_name

      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cluster_name
          }
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cluster_name
          }
        }
      ]

      amiSelectorTerms = [
        {
          alias = "bottlerocket@latest"
        }
      ]

      instanceStorePolicy = "RAID0"

      blockDeviceMappings = [
        {
          deviceName = "/dev/xvdb"
          ebs = {
            volumeSize          = "50Gi"
            volumeType          = "gp3"
            iops                = 3000
            throughput          = 125
            deleteOnTermination = true
            encrypted           = true
          }
        }
      ]

      userData = <<-EOT
        [settings.kubernetes]
        "cluster-dns" = "172.20.0.10"

        [settings.host-containers.admin]
        enabled = false

        [settings.host-containers.control]
        enabled = true
      EOT

      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 1
        httpTokens              = "required"
      }

      tags = {
        ManagedBy = "Karpenter"
        NodePool  = "multi-arch"
      }
    }
  }

  depends_on = [helm_release.karpenter]
}

