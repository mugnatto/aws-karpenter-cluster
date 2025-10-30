# AWS Cloud Infrastructure - Kubernetes & Architecture Design

This repository contains two distinct technical tasks related to Kubernetes infrastructure on AWS. Each task demonstrates different aspects of cloud architecture and DevOps practices.

## Repository Structure

```
aws-karpenter-cluster/
├── 1-task/          # Task 1: EKS + Karpenter Infrastructure
├── 2-task/          # Task 2: Architecture Design Document
└── terraform/       # Reusable Terraform modules
```

---

## Task 1: EKS Cluster with Karpenter and Multi-Architecture Support

**Objective**: Build initial Kubernetes infrastructure for a growing startup, leveraging advanced autoscaling with Karpenter and support for both x86 (AMD64) and ARM64 (Graviton) instances.

### Task 1 Scope

Infrastructure as Code (Terraform) implementation that provisions:
- EKS Cluster (latest available version) in dedicated VPC
- Karpenter configured with NodePools for x86 and ARM64 architectures
- Documentation for developers to use the infrastructure

### Key Features

- **Intelligent autoscaling** with Karpenter
- **Multi-architecture**: AMD64 and ARM64 (Graviton) support
- **Cost optimization** with Spot instances
- **Bottlerocket OS** for enhanced security and performance
- **Fargate** for system components (Karpenter, CoreDNS)
- **Modern EKS Access Entries API** for authentication

### Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **Amazon EKS** | 1.34 | Kubernetes control plane |
| **Karpenter** | 1.8.1 | Kubernetes autoscaler |
| **Bottlerocket OS** | 1.49.0 | Container-optimized OS |
| **Terraform** | >= 1.0 | Infrastructure as Code |
| **AWS Provider** | 6.18.0 | Terraform AWS provider |
| **Kubernetes Provider** | 2.38.0 | Terraform Kubernetes provider |

### Location

Complete implementation is in the **`1-task/`** directory with specific README containing deployment instructions.

---

## Task 2: Cloud Architecture Design Document for Startup

**Objective**: Create comprehensive architectural design document for a startup requiring web application deployment on AWS following best practices for security, scalability, and cost optimization.

### Task 2 Scope

Cloud architecture design covering:
- **AWS Account Structure**: Multi-account strategy with AWS Organizations
- **Network Design**: VPC, subnets, security groups, VPC Endpoints
- **Compute Platform**: EKS with Fargate
- **Database**: RDS PostgreSQL Multi-AZ
- **CI/CD**: GitHub Actions with OIDC
- **Security**: WAF, Secrets Manager, encryption, infosec compliance
- **Monitoring & Costs**: CloudWatch, Cost Explorer

### Target Application

- **Backend**: Python/Flask (REST API)
- **Frontend**: React (SPA)
- **Database**: PostgreSQL
- **Initial Traffic**: Few hundred users per day
- **Expected Growth**: Potentially millions of users
- **Data**: Sensitive user information
- **Deployment**: Continuous CI/CD

### Architecture Characteristics

- **Security-first**: APP Sec pipeline, CloudFront + WAF, VPC Endpoints
- **Cost-optimized**: Multi-account setup
- **High availability**: Multi-AZ deployment, RDS failover
- **Scalable**: Supports growth without architectural rewrites

### Location

Complete architecture document in **`2-task/README.md`** with high-level diagrams.