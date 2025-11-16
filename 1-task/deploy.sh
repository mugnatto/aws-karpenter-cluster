#!/bin/bash

# Complete deployment script for AWS EKS Karpenter Cluster
# This script automates the entire deployment process in the correct order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AWS EKS Karpenter Cluster - Automated Deployment         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI is required but not installed.${NC}" >&2; exit 1; }
echo -e "${GREEN}✅ All prerequisites satisfied${NC}\n"

# Check if central tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars not found. Using default values from variables.tf${NC}"
    echo -e "${YELLOW}💡 Copy terraform.tfvars.example to terraform.tfvars and customize it${NC}"
    TFVARS_FLAG=""
else
    echo -e "${YELLOW}📋 Using central terraform.tfvars...${NC}"
    TFVARS_FLAG="-var-file=../terraform.tfvars"
fi

# =============================================================================
# STAGE 1: Infrastructure (VPC + EKS + IAM)
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STAGE 1/2: Deploying Infrastructure (VPC + EKS + IAM)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

cd 1-infra

if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}🔧 Initializing Terraform...${NC}"
    terraform init
fi

echo -e "${YELLOW}🚀 Deploying infrastructure (this takes ~15 minutes)...${NC}"
terraform apply $TFVARS_FLAG -auto-approve

echo -e "${GREEN}✅ Stage 1 completed!${NC}"
echo -e "${YELLOW}📊 Infrastructure outputs:${NC}"
terraform output
echo ""

# Configure kubectl
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw aws_region)

echo -e "${YELLOW}🔧 Configuring kubectl access...${NC}"
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

echo -e "${GREEN}✅ kubectl configured!${NC}"
kubectl get nodes
echo ""

# =============================================================================
# STAGE 2: Karpenter + NodePool (2-phase Terraform deployment)
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STAGE 2/2: Deploying Karpenter + Multi-Arch NodePool${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

cd ../2-karpenter

if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}🔧 Initializing Terraform...${NC}"
    terraform init
fi

# Phase 1: Install Karpenter Helm chart (creates CRDs)
echo -e "${YELLOW}🚀 Phase 1: Installing Karpenter Helm chart...${NC}"
terraform apply -target=kubernetes_namespace.karpenter -target=helm_release.karpenter -auto-approve

echo -e "${GREEN}✅ Karpenter Helm chart installed!${NC}"
echo ""

# Fix CoreDNS scheduling (REQUIRED)
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  REQUIRED: Fixing CoreDNS Scheduling on Fargate${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}🔄 Deleting CoreDNS pods to reschedule on Fargate...${NC}"
kubectl delete pods -n kube-system -l k8s-app=kube-dns --ignore-not-found=true

echo -e "${YELLOW}⏳ Waiting for CoreDNS to become ready (max 2 minutes)...${NC}"
kubectl wait --for=condition=ready pod -n kube-system -l k8s-app=kube-dns --timeout=120s

echo -e "${GREEN}✅ CoreDNS is running on Fargate!${NC}"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
echo ""

echo -e "${YELLOW}⏳ Waiting for Karpenter to become ready...${NC}"
kubectl wait --for=condition=ready pod -n karpenter -l app.kubernetes.io/name=karpenter --timeout=120s

echo -e "${GREEN}✅ Karpenter is healthy!${NC}"
kubectl get pods -n karpenter -o wide
echo ""

# Phase 2: Create NodePool and EC2NodeClass
echo -e "${YELLOW}🚀 Phase 2: Creating Multi-Arch NodePool and EC2NodeClass...${NC}"
terraform apply -auto-approve

echo -e "${GREEN}✅ Stage 2 completed!${NC}"
echo -e "${YELLOW}📊 Karpenter resources:${NC}"
kubectl get nodepools
kubectl get ec2nodeclasses
echo ""

# Test deployment (optional)
if [ -f "../instances/spot-deployment.yaml" ]; then
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Deploying Test Workloads (Optional)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    
    echo -e "${YELLOW}🚀 Deploying test workloads...${NC}"
    kubectl apply -f ../instances/spot-deployment.yaml 2>/dev/null || echo "  spot-deployment.yaml not found"
    kubectl apply -f ../instances/graviton-deployment.yaml 2>/dev/null || echo "  graviton-deployment.yaml not found"
    
    echo -e "${YELLOW}⏳ Waiting for Karpenter to provision nodes (30s)...${NC}"
    sleep 30
    
    echo -e "${GREEN}✅ Test workloads deployed!${NC}"
    echo -e "${YELLOW}📊 Current status:${NC}"
    kubectl get nodes -o wide
    echo ""
    kubectl get pods -o wide
    echo ""
fi

# Summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              🎉 DEPLOYMENT COMPLETED! 🎉                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📋 Quick validation commands:${NC}"
echo -e "  ${BLUE}# View all resources${NC}"
echo -e "  kubectl get nodes,nodepools,nodeclaims -o wide"
echo ""
echo -e "  ${BLUE}# Deploy a test app${NC}"
echo -e "  kubectl run nginx --image=nginx --requests=cpu=500m,memory=512Mi"
echo -e "  kubectl get pods -w"
echo ""
echo -e "  ${BLUE}# Check node architecture${NC}"
echo -e "  kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type"
echo ""
echo -e "${YELLOW}📝 To clean up all resources:${NC}"
echo -e "  ./destroy.sh"
echo ""
