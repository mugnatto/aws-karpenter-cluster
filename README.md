# AWS EKS with Karpenter Multi-Architecture Autoscaling

Production-ready EKS cluster with Karpenter supporting **both x86 and ARM64 (Graviton)** instances in a single NodePool. Karpenter automatically picks the cheapest option (usually ARM64).

## 🎯 What You Get

- **EKS 1.34** cluster in dedicated VPC
- **Karpenter 1.8.1** with intelligent autoscaling
- **Single NodePool** supporting AMD64 + ARM64
- **Spot instances** by default (up to 90% savings)
- **Automatic cost optimization** (ARM64 ~20% cheaper)

---

## 📋 Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- kubectl >= 1.28

---

## 🚀 Deploy Infrastructure

### Option A: Automated Deployment (Recommended)

Use the automated script for one-command deployment:

```bash
cd 1-task
chmod +x deploy.sh
./deploy.sh
```

This script handles all steps automatically including:
- Infrastructure deployment
- kubectl configuration
- Karpenter installation (2-phase)
- CoreDNS fix
- Verification

**Time:** ~20 minutes total

---

### Option B: Manual Step-by-Step

For more control, follow these manual steps:

### Step 1: Deploy EKS Cluster

```bash
cd 1-task/1-infra
terraform init
terraform apply
```

**Time:** ~15 minutes

### Step 2: Configure kubectl

```bash
export CLUSTER_NAME=$(terraform output -raw cluster_name)
export AWS_REGION=$(terraform output -raw aws_region)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify
kubectl get nodes
```

### Step 3: Deploy Karpenter (2-phase process)

```bash
cd ../2-karpenter  # or 2-helm if not renamed
terraform init

# Phase 1: Install Karpenter + CRDs
terraform apply -target=kubernetes_namespace.karpenter -target=helm_release.karpenter
```

**IMPORTANT: Fix CoreDNS scheduling (required)**

CoreDNS pods start as Pending. Delete them to reschedule on Fargate:

```bash
# Delete CoreDNS pods
kubectl delete pods -n kube-system -l k8s-app=kube-dns

# Wait for them to be ready on Fargate
kubectl wait --for=condition=ready pod -n kube-system -l k8s-app=kube-dns --timeout=120s

# Verify they're on Fargate
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
```

**Then continue:**
```bash
# Phase 2: Create NodePool + NodeClass
terraform apply
```

**Time:** ~3 minutes total

### Step 4: Verify Installation

```bash
kubectl get pods -n karpenter
kubectl get nodepools
kubectl get ec2nodeclasses
```

---

## 👨‍💻 Deploy Workloads

### Automatic Architecture (Recommended)

Karpenter picks the cheapest option (usually ARM64):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-auto
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
```

```bash
kubectl apply -f deployment.yaml
kubectl get pods -o wide
kubectl get nodes -L kubernetes.io/arch
```

### Force x86 (AMD64)

Add `nodeSelector`:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64  # Force x86
      containers:
      - name: app
        image: my-app
```

### Force Graviton (ARM64)

Add `nodeSelector`:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64  # Force Graviton
      containers:
      - name: app
        image: my-app
```

**Note:** Images must support the target architecture.

### Test with Examples

```bash
# Deploy all examples
kubectl apply -f examples/

# Check provisioned nodes
kubectl get nodes -L kubernetes.io/arch

# Verify pod architecture
POD=$(kubectl get pods -l app=nginx-x86 -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- uname -m
# x86: outputs "x86_64"
# ARM: outputs "aarch64"
```

---

## 🧹 Destroy Everything

### Option A: Automated Cleanup (Recommended)

Use the automated script:

```bash
cd 1-task
chmod +x destroy.sh
./destroy.sh
```

This script handles cleanup in the correct order:
1. Deletes all workloads
2. Waits for NodeClaims to terminate
3. Destroys Karpenter
4. Destroys infrastructure

**Time:** ~15 minutes total

---

### Option B: Manual Cleanup

**Follow this order to avoid issues:**

```bash
# 1. Delete all workloads
kubectl delete -f examples/
# or
kubectl delete deployment --all

# 2. Wait for nodes to drain
kubectl get nodeclaims
# Wait until empty (may take 2-3 minutes)

# 3. Destroy Karpenter
cd 1-task/2-karpenter  # or 2-helm
terraform destroy

# 4. Destroy infrastructure
cd ../1-infra
terraform destroy
```

**Total cleanup time:** ~10 minutes

---

## 💡 How It Works

### Single Multi-Arch NodePool

Instead of separate NodePools for x86 and ARM64, we use **one intelligent NodePool**:

```yaml
requirements:
  - key: kubernetes.io/arch
    values: ["amd64", "arm64"]  # Both!
```

**Benefits:**
- Karpenter automatically picks cheapest option
- Better availability (more instance types available)
- ARM64 usually 20% cheaper than x86
- Automatic fallback if one arch unavailable

### Cost Optimization

| Strategy | Savings |
|----------|---------|
| Spot instances | Up to 90% |
| ARM64 (Graviton) | ~20% |
| Right-sizing | 10-30% |
| Fast consolidation | 5-15% |
| **Combined** | **50-70%** |

---

## 📁 Repository Structure

```
.
├── 1-task/
│   ├── 1-infra/          # VPC + EKS + IAM
│   ├── 2-karpenter/      # Karpenter + NodePool
│   └── terraform.tfvars
│
├── examples/             # Sample deployments
│   ├── 01-auto-arch.yaml
│   ├── 02-force-x86.yaml
│   └── 03-force-graviton.yaml
│
└── terraform/modules/    # Reusable modules
    ├── vpc/
    ├── eks/
    └── karpenter-iam/
```

---

## 🐛 Troubleshooting

### Pods stuck in Pending

```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50

# Check NodePool status
kubectl describe nodepool multi-arch
```

### Karpenter pod crashlooping

Usually DNS issue. Fix CoreDNS:

```bash
kubectl delete pods -n kube-system -l k8s-app=kube-dns
kubectl wait --for=condition=ready pod -n kube-system -l k8s-app=kube-dns --timeout=120s
```

### No nodes provisioning

Check if NodePool is ready:

```bash
kubectl get nodepools
kubectl get ec2nodeclasses
kubectl describe ec2nodeclass multi-arch
```

---

## 🔧 Configuration

Edit `1-task/terraform.tfvars`:

```hcl
aws_region         = "us-east-1"
environment        = "development"
project_name       = "karpenter-cluster"
kubernetes_version = "1.34"
vpc_cidr           = "10.0.0.0/16"
```

---

## 📚 Key Features

### Automatic AMI Selection

```yaml
amiSelectorTerms:
  - alias: "bottlerocket@latest"
```

Karpenter automatically picks the correct AMI:
- `bottlerocket-x86_64` for AMD64 pods
- `bottlerocket-aarch64` for ARM64 pods

### Smart Instance Selection

```yaml
instance-category: ["c", "m", "t"]    # Any C/M/T family
instance-generation: Gt "2"            # Gen 3+ only
```

Benefits:
- New instance types automatically included
- More diversity = better Spot availability
- Zero maintenance

### Security

- IMDSv2 required
- EBS encrypted by default
- Bottlerocket OS (minimal attack surface)
- IRSA for fine-grained IAM permissions
- Nodes in private subnets

---

## 🎓 Multi-Arch Images

Popular images that work on both architectures:
- `nginx:latest`
- `redis:latest`
- `postgres:latest`
- `node:latest`
- `python:latest`

Check if your image is multi-arch:
```bash
docker manifest inspect nginx:latest | jq '.manifests[].platform'
```

---

## ⚡ Quick Reference

### Essential Commands

```bash
# Get cluster info
kubectl cluster-info

# List nodes with architecture
kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type

# Check Karpenter status
kubectl get pods -n karpenter

# View NodePool
kubectl get nodepools

# Check provisioned nodes
kubectl get nodeclaims

# Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

---

## 📝 Notes

- **2-phase deploy required:** Helm chart installs CRDs needed by NodePool/NodeClass
- **CoreDNS on Fargate:** System pods run on Fargate, not Karpenter-managed nodes
- **Spot by default:** On-Demand used as fallback
- **1-minute consolidation:** Underutilized nodes consolidated quickly
- **7-day node expiration:** Nodes rotated automatically for security patches

---

## 🔗 References

- [Karpenter Docs](https://karpenter.sh/docs/)
- [AWS Graviton](https://github.com/aws/aws-graviton-getting-started)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

**Ready to deploy?** Start with Step 1 above! 🚀
