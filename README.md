# AWS Karpenter EKS Cluster

This project contains a modular infrastructure setup for deploying an AWS EKS cluster with Karpenter for dynamic node provisioning using Terraform modules.

## Project Structure

```
├── README.md
├── terraform/
│   ├── main.tf                    # Root module orchestration
│   ├── providers.tf              # Provider configurations
│   ├── variables.tf              # Root variables
│   ├── outputs.tf                # Root outputs
│   ├── backend.tf                # Terraform backend configuration
│   ├── nodepools.yaml           # Karpenter NodePool definitions
│   └── modules/                  # Reusable Terraform modules
│       ├── vpc/                  # VPC Module
│       │   ├── main.tf           # VPC, subnets, NAT Gateway, routing
│       │   ├── variables.tf      # VPC module variables
│       │   └── outputs.tf        # VPC module outputs
│       ├── eks/                  # EKS Module
│       │   ├── main.tf           # EKS cluster, IAM roles, security groups
│       │   ├── variables.tf      # EKS module variables
│       │   └── outputs.tf        # EKS module outputs
│       └── karpenter/            # Karpenter Module
│           ├── main.tf           # Karpenter installation and configuration
│           ├── variables.tf      # Karpenter module variables
│           └── outputs.tf        # Karpenter module outputs
└── instances/                    # Kubernetes deployment examples
    ├── spot-deployment.yaml     # Spot instance deployments
    └── graviton-deployment.yaml # Graviton instance deployments
```

## Architecture Overview

### Infrastructure Components

- **VPC Module**: Creates VPC with public/private subnets, NAT Gateway, and routing
- **EKS Module**: Deploys EKS cluster with OIDC provider, IAM roles, and security groups
- **Karpenter Module**: Installs and configures Karpenter for dynamic node provisioning

### Key Features

- **Modular Design**: Reusable modules for VPC, EKS, and Karpenter
- **Cost Optimization**: Shared NAT Gateway (~$32/month vs $64/month)
- **High Availability**: Multi-AZ deployment across 2 availability zones
- **Security**: Private subnets for workloads, proper IAM roles, OIDC authentication
- **Karpenter Integration**: Automatic node provisioning with spot instance support

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- kubectl installed
- AWS credentials with EKS, EC2, IAM permissions

## Usage

### 1. Configure Backend
```bash
# Copy and configure your S3 backend
cp terraform/backend.tf.example terraform/backend.tf
# Edit backend.tf with your S3 bucket details
```

### 2. Initialize and Deploy
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl
```bash
# After EKS cluster is created
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

### 4. Deploy Karpenter NodePools
```bash
# Apply Karpenter NodePool configurations
kubectl apply -f instances/spot-deployment.yaml
kubectl apply -f instances/graviton-deployment.yaml
```

## Module Configuration

### VPC Module
- **CIDR**: 10.0.0.0/16
- **AZs**: 2 availability zones
- **Subnets**: Public (10.0.0.0/24, 10.0.1.0/24) and Private (10.0.2.0/24, 10.0.3.0/24)
- **NAT Gateway**: 1 shared NAT Gateway for cost optimization
- **Tags**: Karpenter discovery tags for automatic subnet selection

### EKS Module
- **Kubernetes Version**: 1.28
- **OIDC Provider**: For secure authentication
- **IAM Roles**: Separate roles for cluster and node groups
- **Security Groups**: Optimized for EKS and Karpenter

### Karpenter Module
- **Version**: 0.37.0
- **Installation**: Via Helm chart
- **NodePools**: Default configuration for spot and on-demand instances
- **EC2NodeClass**: Optimized for AWS with proper subnet and security group selection

## Cost Optimization

- **Shared NAT Gateway**: ~$32/month (vs $64/month for 2 NAT Gateways)
- **Spot Instances**: Up to 90% cost savings with Karpenter
- **Graviton Support**: Better price/performance ratio
- **Auto-scaling**: Pay only for what you use

## Security Features

- **Private Subnets**: Workloads isolated from internet
- **IAM Roles**: Principle of least privilege
- **OIDC Authentication**: Secure cluster access without AWS keys
- **Security Groups**: Granular traffic control
- **Encryption**: In-transit and at-rest encryption

## Monitoring and Logging

- **CloudWatch Logs**: EKS cluster logging enabled
- **VPC Flow Logs**: Network traffic monitoring
- **Karpenter Metrics**: Node provisioning and scaling metrics

## Troubleshooting

### Common Issues
1. **Provider Configuration**: Ensure kubeconfig is set after cluster creation
2. **Subnet Tags**: Verify Karpenter discovery tags are present
3. **IAM Permissions**: Check Karpenter IAM role has required permissions
4. **NAT Gateway**: Ensure private subnets can reach internet for image pulls

### Useful Commands
```bash
# Check cluster status
kubectl get nodes

# Check Karpenter status
kubectl get pods -n karpenter

# View Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```
