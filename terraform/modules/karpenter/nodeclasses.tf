resource "kubernetes_manifest" "default_nodeclass" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "Bottlerocket"
      role      = var.node_iam_role_name
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      instanceStorePolicy = "RAID0"
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvdb"
          ebs = {
            volumeSize          = "50Gi"
            volumeType          = "gp3"
            deleteOnTermination = true
          }
        }
      ]
      amiSelectorTerms = [
        {
          alias = "bottlerocket@latest"
        }
      ]
      kubelet = {
        clusterDNS = ["172.20.0.10"]
        podsPerCore = 2
        maxPods = 110
        systemReserved = {
          cpu = "100m"
          memory = "100Mi"
          ephemeral-storage = "1Gi"
        }
        kubeReserved = {
          cpu = "200m"
          memory = "100Mi"
          ephemeral-storage = "3Gi"
        }
        evictionHard = {
          "memory.available" = "5%"
          "nodefs.available" = "10%"
          "nodefs.inodesFree" = "10%"
        }
        evictionSoft = {
          "memory.available" = "500Mi"
          "nodefs.available" = "15%"
          "nodefs.inodesFree" = "15%"
        }
        evictionSoftGracePeriod = {
          "memory.available" = "1m"
          "nodefs.available" = "1m30s"
          "nodefs.inodesFree" = "2m"
        }
        evictionMaxPodGracePeriod = 60
        imageGCHighThresholdPercent = 85
        imageGCLowThresholdPercent = 80
        cpuCFSQuota = true
      }
    }
  }
  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }
}

resource "kubernetes_manifest" "graviton_nodeclass" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "graviton"
    }
    spec = {
      amiFamily = "Bottlerocket"
      role      = var.node_iam_role_name
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      instanceStorePolicy = "RAID0"
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvdb"
          ebs = {
            volumeSize          = "50Gi"
            volumeType          = "gp3"
            deleteOnTermination = true
          }
        }
      ]
      amiSelectorTerms = [
        {
          alias = "bottlerocket@latest"
        }
      ]
      kubelet = {
        clusterDNS = ["172.20.0.10"]
        podsPerCore = 2
        maxPods = 110
        systemReserved = {
          cpu = "100m"
          memory = "100Mi"
          ephemeral-storage = "1Gi"
        }
        kubeReserved = {
          cpu = "200m"
          memory = "100Mi"
          ephemeral-storage = "3Gi"
        }
        evictionHard = {
          "memory.available" = "5%"
          "nodefs.available" = "10%"
          "nodefs.inodesFree" = "10%"
        }
        evictionSoft = {
          "memory.available" = "500Mi"
          "nodefs.available" = "15%"
          "nodefs.inodesFree" = "15%"
        }
        evictionSoftGracePeriod = {
          "memory.available" = "1m"
          "nodefs.available" = "1m30s"
          "nodefs.inodesFree" = "2m"
        }
        evictionMaxPodGracePeriod = 60
        imageGCHighThresholdPercent = 85
        imageGCLowThresholdPercent = 80
        cpuCFSQuota = true
      }
    }
  }

  
  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }
}
