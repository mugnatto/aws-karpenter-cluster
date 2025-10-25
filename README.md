# AWS Karpenter EKS Cluster

This project contains the infrastructure and configuration files for deploying an AWS EKS cluster with Karpenter for dynamic node provisioning.

## Project Structure

```
├── README.md
├── terraform/
│   ├── main.tf
│   ├── providers.tf
│   ├── vpc.tf
│   ├── eks.tf
│   ├── karpenter.tf
│   ├── nodepools.yaml
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf.example
└── instances/
    ├── spot-deployment.yaml
    └── graviton-deployment.yaml
```

## Prerequisites

- AWS CLI configured
- Terraform installed
- kubectl installed
- AWS credentials with appropriate permissions

## Usage

1. Configure your Terraform backend by copying `backend.tf.example` to `backend.tf`
2. Initialize Terraform: `terraform init`
3. Plan the deployment: `terraform plan`
4. Apply the infrastructure: `terraform apply`
5. Deploy Karpenter NodePools using the YAML files in the `instances/` directory

## Security Considerations

This project follows AWS security best practices and implements proper IAM roles, security groups, and network configurations for production use.
