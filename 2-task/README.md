# Multi-Account AWS Architecture for Web Applications

## Overview

Production-ready AWS architecture for a SPA web application: Python/Flask backend, React frontend, PostgreSQL database. This architecture was designed for teams with limited cloud experience. This covers security, cost optimization, and operational simplicity using managed services.

--- 

## Design Principles

**Security**
Application infrastructure in private subnets. CloudFront and WAF for edge protection. VPC Endpoints for AWS internal service access.

**Cost**
Cost-optimized through VPC Endpoints, 2-AZ production, single-AZ development, EKS Fargate .

**Operations**
Managed services (EKS, RDS, CloudFront). Fargate eliminates node management. Automated failover and scaling.

**Scalability**
Supports growth from hundreds to millions of users.
---

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    INNOVATE INC. CLOUD ARCHITECTURE                             │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS ORGANIZATIONS                                            │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐              ┌─────────────────┐              ┌─────────────────┐          │
│  │ ROOT/MGMT ACC   │              │   DEV ACCOUNT   │              │  PROD ACCOUNT   │          │
│  │                 │              │                 │              │                 │          │
│  │ • Billing       │              │ • Development   │              │ • Production    │          │
│  │ • Governance    │              │ • Testing       │              │ • Live Traffic  │          │
│  │ • ECR Central   │              │ • Single-AZ     │              │ • Multi-AZ      │          │
│  │ • Organizations │              │ • Cost Min      │              │ • High Avail    │          │
│  └─────────────────┘              └─────────────────┘              └─────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    TRAFFIC FLOW (Production)                                    │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  Internet Users                                                                                 │
│       │                                                                                         │
│       ▼                                                                                         │
│  ┌─────────────────┐                                                                            │
│  │   Route 53      │  DNS: innovate.com → CloudFront distribution                               │
│  └────────┬────────┘                                                                            │
│           │                                                                                     │
│           ▼                                                                                     │
│  ┌──────────────────────────────────┐                                                           │
│  │    CloudFront (Global CDN)       │  • Edge caching (200+ locations)                          │
│  │                                  │  • TLS/SSL termination                                    │
│  │ Origin: Internal ALB             │  • Compression                                            │
│  └────────┬─────────────────────────┘  • Custom headers validation                              │
│           │                                                                                     │
│           ▼                                                                                     │
│  ┌──────────────────────────────────┐                                                           │
│  │      AWS WAF (CloudFront)        │  • OWASP Top 10 protection                                │
│  │                                  │  • SQL injection blocking                                 │
│  │  • Managed Rules (AWS)           │  • XSS protection                                         │
│  │  • Rate Limiting                 │  • Bot detection                                          │
│  └────────┬─────────────────────────┘                                                           │
│           │                                                                                     │
│           ▼                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                              PRODUCTION VPC (10.0.0.0/16)                               │    │
│  ├─────────────────────────────────────────────────────────────────────────────────────────┤    │
│  │           │                                                                             │    │
│  │           ▼                                                                             │    │
│  │  ┌──────────────────────────────────┐                                                   │    │
│  │  │   Internal ALB (Private IPs)    │  • Scheme: internal                                │    │
│  │  │   10.0.11.x, 10.0.12.x          │  • Cross-zone load balancing                       │    │
│  │  │                                 │  • Health checks (HTTP /health)                    │    │
│  │  │  Security: Accept only from     │  • TLS between CloudFront ↔ ALB                    │    │
│  │  │  CloudFront (custom header)     │                                                    │    │
│  │  └──────────────────────────────────┘                                                   │    │
│  │           │                                                                             │    │
│  │  ┌────────┴────────┐                                                                    │    │
│  │  │                 │                                                                    │    │
│  │  AZ-1 (us-east-1a)              AZ-2 (us-east-1b)                                       │    │
│  │  ┌─────────────────┐              ┌─────────────────┐                                   │    │
│  │  │ Private App     │              │ Private App     │                                   │    │
│  │  │ 10.0.11.0/24    │              │ 10.0.12.0/24    │                                   │    │
│  │  │                 │              │                 │                                   │    │
│  │  │ • ALB ENI       │              │ • ALB ENI       │                                   │    │
│  │  │ • Frontend Pods │              │ • Frontend Pods │                                   │    │
│  │  │   (React/NGINX) │              │   (React/NGINX) │                                   │    │
│  │  │ • Backend Pods  │              │ • Backend Pods  │                                   │    │
│  │  │   (Flask/Python)│              │   (Flask/Python)│                                   │    │
│  │  │ • Managed Nodes │              │                 │                                   │    │
│  │  │   (Add-ons only)│              │                 │                                   │    │
│  │  └─────────────────┘              └─────────────────┘                                   │    │
│  │         │                                  │                                            │    │
│  │         └──────────────┬───────────────────┘                                            │    │
│  │                        ▼                                                                │    │
│  │  ┌─────────────────┐              ┌─────────────────┐                                   │    │
│  │  │ Private DB      │              │ Private DB      │                                   │    │
│  │  │ 10.0.21.0/24    │              │ 10.0.22.0/24    │                                   │    │
│  │  │                 │              │                 │                                   │    │
│  │  │ • RDS Primary   │◄────────────►│ • RDS Standby   │                                   │    │
│  │  │   (Multi-AZ)    │ Sync Repl    │   (Failover)    │                                   │    │
│  │  │ • region bkp rep│              │                 │                                   │    │
│  │  │ • Encrypted     │              │                 │                                   │    │
│  │  └─────────────────┘              └─────────────────┘                                   │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                      VPC ENDPOINTS (AWS PrivateLink)                            │     │   │
│  │  │  • com.amazonaws.us-east-1.ecr.dkr  (Pull images from Root Account ECR)         │     │   │
│  │  │  • com.amazonaws.us-east-1.ecr.api  (ECR API calls)                             │     │   │
│  │  │  • com.amazonaws.us-east-1.s3       (S3 Gateway - FREE, ECR layers)             │     │   │
│  │  │  • com.amazonaws.us-east-1.secretsmanager  (Secrets injection to pods)          │     │   │
│  │  │  • com.amazonaws.us-east-1.logs     (CloudWatch Logs)                           │     │   │
│  │  │                                                                                 │     │   │
│  │  │  ✅ All AWS traffic via PrivateLink backbone                                    │    │    │
│  │  │  ✅ Cost-effective data transfer                                                │    │    │
│  │  └──────────────────────────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              AMAZON EKS CLUSTER (Production)                                    │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │  Fargate Pods   │  │  Fargate Pods   │  │  Fargate Pods   │  │  Fargate Pods   │             │
│  │  Backend (AZ-1) │  │  Backend (AZ-2) │  │  Frontend (AZ-1)│  │  Frontend (AZ-2)│             │
│  │  Python/Flask   │  │  Python/Flask   │  │  React/NGINX    │  │  React/NGINX    │             │
│  │                 │  │                 │  │                 │  │                 │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐            │
│  │         Small Managed Node Group (Add-ons ONLY - Production)                  │              │
│  │  Instance:                                                                    │              │
│  │  Essential Add-ons:                                                           │              │
│  │  • AWS Load Balancer Controller - Create/manage Internal ALB automatically    │              │
│  │  • ExternalDNS - Automatic DNS record management in Route 53                  │              │
│  │  • Metrics Server - Required for HPA (Horizontal Pod Autoscaler)              │              │
│  │  • Secrets Store CSI Driver - Mount secrets from AWS Secrets Manager          │              │
│  │  • IRSA (IAM Roles for Service Accounts) - Secure AWS API access without keys │              │
│  └─────────────────────────────────────────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    CI/CD PIPELINE                                               │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  ┌─────────────────┐    ┌─────────────────────┐    ┌──────────────┐    ┌──────────────┐         │
│  │   GitHub        │    │   ROOT ACCOUNT      │    │ DEV ACCOUNT  │    │ PROD ACCOUNT │         │
│  │   Actions       │───►│   ECR (Central)     │───►│  EKS Deploy  │───►│  EKS Deploy  │         │
│  │                 │    │                     │    │              │    │  (Manual)    │         │
│  │ • OIDC Auth     │    │ • Image Scan (ECR)  │    │ • Auto       │    │ • Approval   │         │
│  │ • Build & Test  │    │ • Snyk/Trivy        │    │ • Fast iter  │    │              │         │
│  │ • Security Scan │    │ • Lifecycle Policy  │    │              │    │              │         │
│  └─────────────────┘    └─────────────────────┘    └──────────────┘    └──────────────┘         │
│                                                                                                 │
│  Cross-Account ECR Access: Dev and Prod accounts pull images from Root via VPC Endpoints        │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Multi-Account Strategy

### Account Structure

Three-account setup using AWS Organizations:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Root/Mgmt     │    │   Dev Account   │    │  Prod Account   │
│   Account       │    │                 │    │                 │
│                 │    │                 │    │                 │
│ • Billing       │    │ • Development   │    │ • Production    │
│ • Governance    │    │ • Testing       │    │ • Live Traffic  │
│ • Central ECR   │    │ • Single-AZ     │    │ • Multi-AZ      │
│ • Organizations │    │ • Cost Min      │    │ • High Avail    │
│ • CloudTrail    │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Account Responsibilities

**Root/Management Account**
- AWS Organizations and consolidated billing
- Centralized ECR for all container images, Central S3 for Static Images and tfstate files
- Organization-wide CloudTrail for audit logs
- Service Control Policies (SCPs)
- Cross-account IAM roles
- No application workloads

**Development Account**
- Single-AZ deployment to minimize cost
- Relaxed security controls for rapid iteration
- Auto-shutdown capabilities for non-business hours
- Same architecture pattern as production

**Production Account**
- Multi-AZ deployment across 2 availability zones
- Strict security controls and monitoring


### Why Centralized ECR

Single ECR registry in the Root account provides:
- Single source of truth for container images
- Images scanned once, used everywhere
- Cost efficiency (single storage, single scan)
- Cross-account access via VPC Endpoints
- Simplified CI/CD (push once, deploy anywhere)
- Immutable image promotion from Dev to Prod

### Benefits of Multi-Account

**Security Isolation**
Credential exposure in Dev doesn't compromise Prod. Blast radius is limited to a single account.

**Cost Visibility**
Clear separation of Dev vs Prod costs. Easier to optimize and forecast spending.

**Compliance**
Different security controls per environment. Prod can meet SOC 2/HIPAA while Dev remains flexible.

**Access Control**
Granular IAM policies per account. Devs get full Dev access, restricted Prod access.

---

## 2. Network Architecture

### VPC Design

Architecture with CloudFront and WAF as the internet-facing layer. All application resources run in private subnets.

```
┌──────────────────────────────────────────────────────────────────┐
│              INTERNET (Users)                                    │
│                     ↓                                            │
│      Route 53 → CloudFront → WAF → Internal ALB (Private!)      │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                        │
├─────────────────────────────────────────────────────────────────┤
│  AZ-1 (us-east-1a)              AZ-2 (us-east-1b)               │
│                                                                 │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │ Private App     │              │ Private App     │           │
│  │ 10.0.11.0/24    │              │ 10.0.12.0/24    │           │
│  │                 │              │                 │           │
│  │ • Internal ALB  │              │ • Internal ALB  │           │
│  │ • EKS Pods      │              │ • EKS Pods      │           │
│  │ • VPC Endpoints │              │ • VPC Endpoints │           │
│  └─────────────────┘              └─────────────────┘           │
│                                                                 │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │ Private DB      │              │ Private DB      │           │
│  │ 10.0.21.0/24    │              │ 10.0.22.0/24    │           │
│  │ • RDS Primary   │              │ • RDS Standby   │           │
│  └─────────────────┘              └─────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### Network Tiers

**Internet-Facing Layer**
- CloudFront 
- AWS WAF for OWASP protection
- TLS termination at edge
- Origin: Internal ALB

**Application Tier**
- Internal ALB to Fargate pods
- Custom header validation (CloudFront → ALB)
- VPC Endpoints for AWS services

**Database Tier**
- RDS PostgreSQL in separate security groups
- Application tier access only
- Multi-AZ (production), Single-AZ (development)
- Backup replication to other region for disaster recovery


### High Availability

**Production: 2 Availability Zones**
- All resources deployed across different AZs
- Internal ALB with cross-zone load balancing
- RDS Multi-AZ with for Zonal Disaster Recovery
- Fargate pods distributed across both AZs
- Can survive complete AZ failure.
- Infrastructure deployed via Terraform so it's easier to recreate in other region in case of regional disaster.
- RDS backup replication to second region to enable disaster recovery.  

**Why 2 AZs Instead of 3**
- Sufficient redundancy: 99.99% availability
- AWS best practice minimum for production


**Development: Single AZ**
- Minimal cost deployment in 1 AZ only
- Same architecture pattern as production
- Can be auto-shutdown during non-business hours

### VPC Endpoints Strategy

AWS VPC Endpoint connectivity for AWS services without going through the internet.

**Interface Endpoints (Production)**
- `com.amazonaws.us-east-1.ecr.dkr` - Pull images from Root account ECR
- `com.amazonaws.us-east-1.ecr.api` - ECR API operations  
- `com.amazonaws.us-east-1.secretsmanager` - Secret injection to pods
- `com.amazonaws.us-east-1.logs` - CloudWatch logs

**Gateway Endpoints**
- `com.amazonaws.us-east-1.s3` - ECR image layers, backups, logs
- No data processing charges

**Benefits**
- Traffic on AWS backbone
- Lower data transfer costs
- Simplified security group management

### Security Groups

Least-privilege firewall rules for each component:
- Frontend pods: Accept traffic from Internal ALB only
- Backend pods: Accept traffic from Internal ALB only
- RDS: Accept traffic from application subnets only on port 5432
- Internal ALB: Accept traffic with CloudFront custom header only

### AWS WAF Configuration

Attached to CloudFront (edge protection):
- AWS WAF
- Rate limiting
- SQL injection and XSS protection
- Bot detection and mitigation

**Why CloudFront WAF Instead of ALB**
- Blocks attacks at edge before reaching VPC
- Reduces data transfer costs to origin
- Better performance for legitimate users
- Lower latency (cached at edge)

### Network Optimization

**CloudFront Benefits**
- 70-90% cache hit ratio
- Lower data transfer costs
- Reduced compute costs
- Free SSL certificates

**Right-Sizing Strategy**
- Production: 2 AZs (99.99% availability)
- Development: Single AZ
- Systems Manager Session Manager for access
- Strategic VPC Endpoint placement

---

## 3. Compute Platform

### Amazon EKS with Fargate

Managed Kubernetes control plane with serverless container execution. No EC2 nodes to manage except for a small managed node group for essential add-ons.

**Why EKS + Fargate**
- Zero node management (no OS patching, capacity planning, or node failures)
- Pay-per-pod pricing (no idle EC2 costs)
- Automatic scaling based on pod resource requests
- Focus on application, not infrastructure

**Architecture Decision**
- Fargate for all application workloads (frontend and backend)
- Small managed node group for add-ons only
- No user workloads on managed nodes
- IaC

**AWS Load Balancer Controller**
- Automatically creates Internal ALB from Kubernetes Ingress
- Manages target groups and health checks
- SSL certificate integration with ACM
- No manual load balancer configuration needed

**ExternalDNS**
- Automatic Route 53 record management
- Creates/updates/deletes DNS based on Ingress resources
- Reduces manual DNS errors

**Secrets Store CSI Driver**
- Mounts secrets from AWS Secrets Manager as volumes
- Automatic secret rotation support
- Used for database credentials and API keys

**Metrics Server**
- Provides resource metrics for HPA decisions
- Enables `kubectl top nodes` and `kubectl top pods`
- Required for autoscaling

**IAM Roles for Service Accounts (IRSA)**
- Pods assume IAM roles without credentials
- Least-privilege access to AWS services
- Used by Load Balancer Controller, ExternalDNS, CSI Driver
- No AWS access keys in cluster

---

## 4. Container Strategy

### Multi-Stage Builds

**Backend (Python/Flask)**
```dockerfile
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY . .
EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
```

**Frontend (React/NGINX)**
```dockerfile
FROM node:18-alpine as builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

### Container Registry (ECR)

**Centralized ECR in Root Account**
- Private registry accessible by Dev and Prod accounts
- Cross-account access via VPC Endpoints
- Images scanned once on push with ECR image scanning
- Snyk/Trivy scanning in CI/CD before push

**Image Tagging Strategy**
- Git commit SHA for immutability
- Environment-specific tags (dev-latest, prod-latest)
- Semantic versioning for releases (v1.2.3)

---

## 5. Database Architecture

### Amazon RDS PostgreSQL

Managed PostgreSQL with automated operations (backups, cross region backup rep´lication, patching, monitoring).

**Configuration**

**Production**

- Multi-AZ: Primary in AZ-1, standby in AZ-2
- cross region backup replication
- Backups: 7-day retention, automated daily backups

**Development**

- Single-AZ deployment

- Backups: 1-day retention

### High Availability (Production)

```
┌─────────────────────────────────────────────────────────────────┐
│                Amazon RDS PostgreSQL Multi-AZ                   │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │   Primary DB    │◄────────────►│  Standby DB     │           │
│  │   (AZ-1)        │ Sync Repl    │  (AZ-2)         │           │
│  └─────────────────┘              └─────────────────┘           │
│           │                                 │                   │
│           └─────  Automatic Failover ───────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

- Synchronous replication to standby
- Failover to second AZ 
- Zero data loss on failover
- Backup replication to other AWS region for disaster recovery

### Security

**Encryption**
- At rest: KMS encryption enabled by default
- In transit: TLS enforced for all connections
- Backups: Encrypted with same KMS keys

**Network Isolation**
- Private subnets only 
- Security groups: Accept traffic from application subnets

**Access Control**
- Credentials stored in AWS Secrets Manager
- Mounted to pods via CSI Driver
- Automatic credential rotation
- IAM database authentication available for admin access

---

## 6. Frontend Delivery

### CloudFront + Internal ALB

Single-page React application served through CloudFront with Internal ALB as origin.

**Request Flow**
```
User → Route 53 → CloudFront + WAF → Internal ALB → Frontend Pods (React/NGINX)
                                   └→ Backend Pods (Flask API)
```

**CloudFront Origin Behaviors**
- Default (`/`): Internal ALB (React SPA)
- API (`/api/*`): Internal ALB (Flask backend)
- Static assets served directly by NGINX in frontend pods

**Benefits**

- WAF at edge
- Custom header validation (CloudFront → ALB)
- Edge Cache
- Compression
- Low latency
- Free SSL certificates

---

## 7. CI/CD Pipeline

### GitHub Actions with OIDC

No static AWS credentials stored in GitHub. OIDC provider authenticates directly to AWS.

**Pipeline Flow**
```
Code Commit → GitHub Actions → Security Scan → Build → Push ECR → Deploy EKS

```

---

## 8. Security

### Defense in Depth

**Network**
- Private subnets for application infrastructure
- Internal ALB
- VPC Endpoints for AWS services
- Least-privilege security groups
- Network ACLs at subnet level

**Application**
- AWS WAF on CloudFront
- Custom header validation (CloudFront → ALB)
- Rate limiting
- Input validation
- CI/CD security scanning (Snyk/Trivy)

**Data**
- KMS encryption at rest (RDS, EBS, S3)
- TLS in transit
- Automatic key rotation

**Identity & Access**
- IAM least privilege
- IRSA for pod-level AWS access
- MFA for admin/production
- OIDC for GitHub Actions
- Cross-account roles

**Secrets**
- AWS Secrets Manager
- CSI Driver mounts to pods
- Automated Key rotation
- CloudTrail audit

**Monitoring**
- CloudTrail (organization-wide)
- CloudWatch Logs and Alarms
- Real-time dashboards

---

## 9. Cost Management

### Cost Optimization Strategy

**Infrastructure Efficiency**
- VPC Endpoints for AWS service connectivity
- 2 AZ deployment balances HA with cost
- Fargate pay-per-use (no idle resource costs)

**Account Structure**
- Root/Management: ECR storage, CloudTrail, Organizations
- Development: Single-AZ, auto-shutdown capabilities
- Production: Multi-AZ, full redundancy

### Cost Controls

**Monitoring & Alerts**
- AWS Budgets with threshold alerts
- Cost Anomaly Detection enabled

**Optimization Practices**
- Dev environment auto-shutdown (nights/weekends)
- CloudWatch metrics for usage tracking

---

## Summary

### Architecture Highlights

Production-ready, cost-optimized architecture for startups.

**Security**
- Private subnets for infrastructure
- CloudFront + WAF
- VPC Endpoints for AWS service access
- KMS encryption at rest, TLS in transit
- IRSA, Secrets Manager, OIDC
- CloudTrail audit logs

**Cost Optimization**
- VPC Endpoints for efficient AWS connectivity
- 2 AZ deployment balances HA with efficiency
- Fargate pay-per-use model
- CloudFront caching

**Operations**
- Managed services (EKS, RDS, CloudFront)
- Fargate (no node management)
- Automatic scaling (HPA, RDS Multi-AZ)
- GitHub Actions OIDC
- Centralized ECR

**High Availability**
- 2 availability zones
- RDS failover
- CloudFront
- Cross-zone load balancing
- RDS bacck replication to second region
- Terraformed infrastructure

