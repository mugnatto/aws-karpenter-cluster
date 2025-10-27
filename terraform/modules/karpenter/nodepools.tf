resource "kubernetes_manifest" "default_nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "node-type" = "default"
            "kubernetes.io/arch" = "amd64"
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
              values   = ["amd64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = ["t3.medium", "t3.large", "t3.xlarge"]
            }
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          expireAfter = "24h"
        }
      }
      limits = {
        cpu    = "50"
        memory = "50Gi"
      }
      disruption = {
        consolidateAfter = "5m"
        consolidationPolicy = "WhenEmptyOrUnderutilized"
      }
    }
  }
  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }
}

resource "kubernetes_manifest" "graviton_nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "graviton"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "node-type" = "graviton"
            "kubernetes.io/arch" = "arm64"
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
              values   = ["arm64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values = [
                "m6g.medium",
                "m6g.large",
                "m6g.xlarge",
                "m6g.2xlarge",
                "c6g.medium",
                "c6g.large",
                "c6g.xlarge",
                "c6g.2xlarge"
              ]
            }
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "graviton"
          }
          expireAfter = "24h"
        }
      }
      limits = {
        cpu    = "50"
        memory = "50Gi"
      }
      disruption = {
        consolidateAfter = "5m"
        consolidationPolicy = "WhenEmptyOrUnderutilized"
      }
    }
  }


  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }
}

