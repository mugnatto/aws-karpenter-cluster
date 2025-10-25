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
# Apply Karpenter NodePool configurations
kubectl apply -f instances/spot-deployment.yaml
kubectl apply -f instances/graviton-deployment.yaml
