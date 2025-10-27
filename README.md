# AWS EKS Karpenter Cluster

Production-ready EKS cluster deployment featuring Karpenter autoscaling with support for both AMD64 and ARM64 (Graviton) instances, optimized for cost-efficiency using Spot instances.

## Overview

This repository provides Infrastructure as Code to deploy a fully automated Kubernetes cluster on AWS EKS. The cluster leverages Karpenter for intelligent autoscaling and supports multi-architecture workloads across AMD64 and ARM64 (Graviton) processors.

### Key Features

- Dynamic node provisioning with Karpenter
- Multi-architecture support (AMD64 and ARM64 Graviton)
- Cost optimization through Spot instances
- Bottlerocket OS for enhanced security and performance
- Fargate-hosted system components (Karpenter, CoreDNS)
- Modern EKS authentication using Access Entries API

### Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **Amazon EKS** | 1.34 | Kubernetes control plane |
| **Karpenter** | 1.8.1 | Kubernetes autoscaler |
| **Bottlerocket OS** | 1.49.0 | Container-optimized Linux distribution |
| **Terraform** | >= 1.0 | Infrastructure as Code |
| **AWS Provider** | 6.18.0 | Terraform AWS provider |
| **Kubernetes Provider** | 2.38.0 | Terraform Kubernetes provider |

## Quick Start

### Prerequisites

#### AWS Account and IAM Requirements

- **AWS Account** with appropriate service limits (EKS, VPC, EC2, IAM)
- **IAM User or Role** with permissions for:
  - EKS cluster creation and management
  - VPC, subnet, and security group creation
  - IAM role and policy creation
  - EC2 instance management
  - S3 bucket access (for Terraform state)
  - CloudWatch logs management
- **S3 Bucket** for Terraform remote state storage
- **AWS CLI** configured with credentials:
  ```bash
  aws configure
  # Or use AWS SSO, environment variables, or instance profiles
  ```

**Tip**: For production, use IAM roles with least-privilege policies.

#### Required Tools

Install the following CLI tools (links to official documentation):

- **AWS CLI** (>= 2.0) - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform** (>= 1.0) - [Installation Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- **kubectl** (>= 1.28) - [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **Helm** (>= 3.10) - [Installation Guide](https://helm.sh/docs/intro/install/)
- **jq** (optional, for JSON parsing) - [Installation Guide](https://jqlang.github.io/jq/download/)

**Verification**:
```bash
aws --version        # aws-cli/2.x.x
terraform --version  # Terraform v1.x.x
kubectl version      # Client Version: v1.x.x
helm version         # version.BuildInfo{Version:"v3.x.x"}
```

### Configuration

Update the S3 bucket configuration in the following files:
- `1-task/1-infra/backend.tf`
- `1-task/3-karpenter/backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket = "your-unique-bucket-name"  # Update this
    key    = "aws-karpenter-cluster/1-infra/terraform.tfstate"
    region = "YOUR_REGION"
  }
}
```

### Automated Deployment

Execute the complete deployment script:

```bash
cd 1-task
chmod +x deploy.sh
./deploy.sh
```

The script will automatically:
1. Deploy VPC, EKS cluster, and IAM roles (approximately 15 minutes)
2. Install Karpenter via Helm (approximately 2 minutes)
3. Create NodePools and EC2NodeClasses (approximately 1 minute)
4. Deploy test workloads to validate functionality

### Manual Deployment

For step-by-step deployment:

```bash
# Stage 1: Infrastructure
cd 1-task/1-infra
terraform init
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region YOUR_REGION --name YOUR_CLUSTER_NAME

# Stage 2: Karpenter Installation
cd ../2-helm
chmod +x install-karpenter.sh
./install-karpenter.sh

# Stage 3: Karpenter Resources
cd ../3-karpenter
terraform init
terraform apply

# Deploy Test Workloads
kubectl apply -f ../instances/spot-deployment.yaml
kubectl apply -f ../instances/graviton-deployment.yaml
```

## Usage for Developers

### Deploying Applications on AMD64 Instances

Create a Kubernetes deployment with AMD64 node selector:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-application
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-application
  template:
    metadata:
      labels:
        app: my-application
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
        node-type: default
      containers:
      - name: app
        image: nginx:latest
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

Apply the deployment:
```bash
kubectl apply -f my-application.yaml
```

Karpenter will automatically provision AMD64 Spot instances to accommodate your pods.

### Deploying Applications on Graviton (ARM64) Instances

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-graviton-application
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-graviton-application
  template:
    metadata:
      labels:
        app: my-graviton-application
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
        node-type: graviton
      containers:
      - name: app
        image: nginx:latest
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
```

**Important**: Ensure your container images support ARM64 architecture. Most official Docker images provide multi-architecture support.

### Automatic Node Selection

You can omit the `nodeSelector` to allow Karpenter to select the most cost-effective instance type:

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
```

Karpenter will analyze pricing, availability, and cluster utilization to make optimal provisioning decisions.

## Testing and Validation

### Automated Testing

Run the validation script:

```bash
cd 1-task
chmod +x test-deployment.sh
./test-deployment.sh
```

### Manual Verification

Check cluster status:
```bash
kubectl get nodes -o wide
```

Expected output should include Fargate nodes and Bottlerocket EC2 nodes.

Verify pod architecture:
```bash
# Test AMD64 pod
AMD64_POD=$(kubectl get pods -l app=spot-workload -o jsonpath='{.items[0].metadata.name}')
kubectl exec $AMD64_POD -- uname -m
# Expected output: x86_64

# Test Graviton pod
ARM64_POD=$(kubectl get pods -l app=graviton-workload -o jsonpath='{.items[0].metadata.name}')
kubectl exec $ARM64_POD -- uname -m
# Expected output: aarch64
```

Check Karpenter resources:
```bash
kubectl get nodepools
kubectl get nodeclaims
kubectl get ec2nodeclasses
```

## Troubleshooting

### Pods Remaining in Pending State

Check pod events:
```bash
kubectl describe pod <pod-name>
```

Verify NodePool status:
```bash
kubectl get nodepools
kubectl describe nodepool default
```

Check Karpenter logs:
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50
```

### Nodes Not Joining Cluster

Verify NodeClaims:
```bash
kubectl get nodeclaims
kubectl describe nodeclaim <nodeclaim-name>
```

Check EKS Access Entries:
# aws eks list-access-entries --cluster-name karpenter-cluster-development --region us-east-1
```bash
aws eks list-access-entries --cluster-name YOUR_CLUSTER_NAME --region YOUR_REGION
```

Verify subnet tags:
```bash
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=YOUR_CLUSTER_NAME"
```

Check security group tags:
```bash
aws ec2 describe-security-groups --filters "Name=tag:karpenter.sh/discovery,Values=YOUR_CLUSTER_NAME"
```

### Karpenter Not Provisioning Nodes

Check if NodePools are ready:
```bash
kubectl get nodepools -o wide
```

Describe EC2NodeClass for detailed status:
```bash
kubectl describe ec2nodeclass default
```

Look for these conditions: `AMIsReady`, `SubnetsReady`, `SecurityGroupsReady`, `InstanceProfileReady`

Review Karpenter controller logs for errors:
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=200 | grep -i error
```

## Cleanup

### Automated Cleanup

Execute the destroy script:

```bash
cd 1-task
chmod +x destroy.sh
./destroy.sh
```

### Manual Cleanup

Follow these steps in order to avoid dependency issues:

```bash
# 1. Delete workload deployments
kubectl delete -f 1-task/instances/spot-deployment.yaml
kubectl delete -f 1-task/instances/graviton-deployment.yaml

# 2. Wait for NodeClaims to be removed
kubectl delete nodeclaims --all
sleep 60

# 3. Destroy Karpenter resources
cd 1-task/3-karpenter
terraform destroy 

# 4. Uninstall Karpenter Helm release
cd ../2-helm
./uninstall-karpenter.sh

# 5. Destroy infrastructure
cd ../1-infra
terraform destroy 
```

## Project Structure

```
aws-karpenter-cluster/
├── 1-task/
│   ├── 1-infra/                    # Stage 1: Infrastructure (VPC, EKS, IAM)
│   ├── 2-helm/                     # Stage 2: Karpenter Helm installation
│   ├── 3-karpenter/                # Stage 3: NodePools and EC2NodeClasses
│   ├── instances/                  # Example workload deployments
│   ├── deploy.sh                   # Complete deployment automation
│   ├── destroy.sh                  # Safe cleanup automation
│   └── test-deployment.sh          # Validation script
│
└── terraform/modules/
    ├── vpc/                        # VPC module with Karpenter discovery tags
    ├── eks/                        # EKS cluster with Fargate profile
    ├── karpenter-iam/              # IAM roles and policies for Karpenter
    └── karpenter/                  # NodePools and EC2NodeClasses resources
```

## Architecture

The deployment creates:

- **VPC** with public and private subnets across 2 availability zones
- **EKS Cluster** version 1.34 with API authentication mode
- **Fargate Profile** for Karpenter controller and CoreDNS pods
- **NodePools**: One for AMD64 instances, one for ARM64 Graviton instances
- **EC2NodeClasses**: Configured to use Bottlerocket OS with automatic AMI selection
- **IAM Roles**: Separate roles for Karpenter controller and worker nodes
- **Security Groups**: Configured to allow communication between cluster components

System components (Karpenter and CoreDNS) run on Fargate, while application workloads run on EC2 instances provisioned dynamically by Karpenter.

## Configuration Details

### NodePools

Two NodePools are configured:

1. **default** (AMD64):
   - Instance types: t2, t3, c4, c5, m4, m5 families
   - Capacity: Spot and On-Demand
   - Label: `node-type: default`

2. **graviton** (ARM64):
   - Instance types: m6g, c6g, r6g, t4g families
   - Capacity: Spot and On-Demand
   - Label: `node-type: graviton`

Both NodePools feature:
- Automatic consolidation after 30 seconds of underutilization
- Node expiration after 24 hours
- Maximum 50 CPUs and 50Gi memory per pool

### EC2NodeClasses

Both AMD64 and Graviton node classes use:
- **AMI Family**: Bottlerocket (container-optimized OS)
- **AMI Selection**: Latest Bottlerocket AMI via alias
- **Root Volume**: 50Gi GP3 EBS volume
- **Instance Store**: RAID0 policy
- **Cluster DNS**: Configured to CoreDNS service IP
- **Discovery**: Tags-based subnet and security group selection

## Important Notes

### EKS 1.34 and AL2 Compatibility

Amazon Linux 2 (AL2) is not supported on EKS 1.33 and later versions. This deployment uses Bottlerocket OS, which is the recommended container-optimized operating system for modern EKS versions.

Reference: [Amazon EKS Kubernetes versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html)

### EKS Access Entries

This deployment uses EKS Access Entries for authentication instead of the legacy `aws-auth` ConfigMap. Access Entries are the recommended approach for EKS 1.34 when using API authentication mode.

Reference: [Manage access entries for IAM principals](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)

### Karpenter and Bottlerocket

Karpenter automatically generates the appropriate UserData for Bottlerocket instances. Do not specify custom UserData in the EC2NodeClass when using `amiFamily: Bottlerocket`.

Reference: [Karpenter NodeClasses](https://karpenter.sh/docs/concepts/nodeclasses/)

## Instance Configuration

### NodePool Default (AMD64)
- **Architecture**: AMD64 (x86_64)
- **Instance Types**: Any AMD64 instance (no specific restrictions)
- **Capacity Type**: Spot and On-Demand
- **Limits**: 50 vCPUs, 50Gi RAM

### NodePool Graviton (ARM64)
- **Architecture**: ARM64 (Graviton)
- **Specific Instance Types**:
  - `m6g.medium` - 1 vCPU, 4 Gi RAM
  - `m6g.large` - 2 vCPUs, 8 Gi RAM
  - `m6g.xlarge` - 4 vCPUs, 16 Gi RAM
  - `m6g.2xlarge` - 8 vCPUs, 32 Gi RAM
  - `c6g.medium` - 1 vCPU, 2 Gi RAM
  - `c6g.large` - 2 vCPUs, 4 Gi RAM
  - `c6g.xlarge` - 4 vCPUs, 8 Gi RAM
  - `c6g.2xlarge` - 8 vCPUs, 16 Gi RAM
- **Capacity Type**: Spot and On-Demand
- **Limits**: 50 vCPUs, 50Gi RAM

### Common Configuration
- **OS**: Bottlerocket (container-optimized)
- **Storage**: EBS GP3 50Gi
- **Instance Store**: RAID0 (when available)
- **Expiration**: 24 hours
- **Consolidation**: 30 seconds after empty/underutilized

The project uses a hybrid strategy: generic AMD64 instances for general workloads and specific Graviton instances (m6g/c6g) for ARM64-optimized workloads.

## Cost Considerations

Estimated monthly costs for development environment:
- EKS Control Plane: $73/month
- Fargate pods (2 replicas): approximately $15/month
- EC2 Spot instances: $20-150/month (varies by workload)
- NAT Gateway: $32/month
- Data transfer and storage: $5-10/month

**Total estimated cost: $145-280/month**

Cost optimization is achieved through:
- Spot instances (up to 90% savings vs On-Demand)
- Automatic node consolidation
- Minimal Fargate usage
- Single NAT Gateway


## Monitoring

View Karpenter activity:
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --follow
```

Monitor node provisioning:
```bash
kubectl get nodeclaims
kubectl get nodes -o wide
```

Check resource utilization:
```bash
kubectl top nodes
kubectl top pods
```

## References

### Official Documentation
- [Karpenter Documentation](https://karpenter.sh/docs/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Bottlerocket Documentation](https://bottlerocket.dev/en/)
- [AWS Graviton Technical Guide](https://github.com/aws/aws-graviton-getting-started)

### AWS Best Practices
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/docs/)

### Karpenter Resources
- [Karpenter Getting Started](https://karpenter.sh/docs/getting-started/)
- [Karpenter Upgrade Guide](https://karpenter.sh/docs/upgrading/upgrade-guide/)
- [Karpenter Troubleshooting](https://karpenter.sh/docs/troubleshooting/)

### EKS Access Entries
- [Grant IAM users and roles access to Kubernetes APIs](https://docs.aws.amazon.com/eks/latest/userguide/grant-k8s-access.html)
- [Manage access entries for IAM principals](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)

### Bottlerocket
- [Bottlerocket on Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami-bottlerocket.html)
- [Bottlerocket GitHub Repository](https://github.com/bottlerocket-os/bottlerocket)

## Known Issues and Solutions

This medium also helped a lot with the troubleshooting and debug: https://medium.com/@ShubhamTheDevOps/real-world-karpenter-implementation-complete-guide-troubleshooting-scenerio-d412958a088f

### Issue: AL2023 UserData Not Executing

**Symptom**: Nodes created but not joining cluster when using AL2023

**Cause**: cloud-init in AL2023 does not process Karpenter-generated UserData with content-type `application/node.eks.aws`

**Solution**: Use Bottlerocket OS instead (configured by default in this repository)

**References**:
- [Karpenter Issue #6847](https://github.com/aws/karpenter-provider-aws/issues/6847)
- [AL2023 and nodeadm](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html)

### Issue: NodePools Show "not ready"

**Symptom**: Karpenter logs show `ignoring nodepool, not ready`

**Cause**: EC2NodeClass validation failing, often due to AMI selection issues

**Solution**: 
- Verify `amiFamily` matches `amiSelectorTerms` alias
- For EKS 1.34, use `amiFamily: Bottlerocket` with `alias: bottlerocket@latest`
- AL2 aliases are not supported on EKS 1.33+

**References**:
- [Kubernetes version 1.33 release notes](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html#kubernetes-1-33)

### Issue: Nodes Created But Not Registered

**Symptom**: NodeClaims show `READY: Unknown`, EC2 instances running but nodes don't appear in `kubectl get nodes`

**Cause**: Missing or incorrect EKS Access Entry for node IAM role

**Solution**: Ensure Access Entry exists with type `EC2_LINUX`:
```bash
aws eks describe-access-entry \
  --cluster-name YOUR_CLUSTER_NAME \
  --principal-arn arn:aws:iam::ACCOUNT:role/YOUR_CLUSTER_NAME-karpenter-node-role \
  --region YOUR_REGION
```

The Access Entry should have `type: EC2_LINUX` which automatically grants `system:nodes` and `system:bootstrappers` groups.

**References**:
- [EKS Access Entry types](https://docs.aws.amazon.com/eks/latest/APIReference/API_AccessEntry.html)

### Issue: Karpenter Cannot Find Subnets

**Symptom**: Karpenter logs show `no subnets found`

**Cause**: Subnets not tagged correctly or public subnets incorrectly tagged

**Solution**: 
- Only tag **private subnets** with `karpenter.sh/discovery: <cluster-name>`
- Do not tag public subnets
- Verify tags:
```bash
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=YOUR_CLUSTER_NAME"
```

**References**:
- [Karpenter Subnet Discovery](https://karpenter.sh/docs/concepts/nodeclasses/#subnet-discovery)

## License

This project is provided as-is for educational and demonstration purposes.

---

**Last Updated**: October 2025
