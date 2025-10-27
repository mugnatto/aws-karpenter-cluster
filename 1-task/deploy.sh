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
echo -e "${BLUE}║   AWS EKS Karpenter Cluster - Complete Deployment         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ Helm is required but not installed.${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI is required but not installed.${NC}" >&2; exit 1; }
echo -e "${GREEN}✅ All prerequisites satisfied${NC}\n"

# Stage 1: Infrastructure
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STAGE 1/3: Deploying Infrastructure (VPC + EKS + IAM)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
cd 1-infra

if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}🔧 Initializing Terraform...${NC}"
    terraform init
fi

echo -e "${YELLOW}🚀 Deploying infrastructure...${NC}"
terraform apply -auto-approve

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

# Stage 2: Karpenter Installation
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STAGE 2/3: Installing Karpenter via Helm${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
cd ../2-helm

echo -e "${YELLOW}🚀 Installing Karpenter...${NC}"
chmod +x install-karpenter.sh
./install-karpenter.sh

echo -e "${GREEN}✅ Stage 2 completed!${NC}"
echo -e "${YELLOW}📊 Karpenter status:${NC}"
kubectl get pods -n karpenter
echo ""

# Stage 3: Karpenter Resources
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STAGE 3/3: Creating NodePools and EC2NodeClasses${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
cd ../3-karpenter

if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}🔧 Initializing Terraform...${NC}"
    terraform init
fi

echo -e "${YELLOW}🚀 Deploying Karpenter resources...${NC}"
terraform apply -auto-approve

echo -e "${GREEN}✅ Stage 3 completed!${NC}"
echo -e "${YELLOW}📊 Karpenter resources:${NC}"
kubectl get nodepools
kubectl get ec2nodeclasses
echo ""

# Deploy test workloads
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Deploying Test Workloads${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}🚀 Deploying AMD64 Spot workload...${NC}"
kubectl apply -f ../instances/spot-deployment.yaml

echo -e "${YELLOW}🚀 Deploying ARM64 Graviton workload...${NC}"
kubectl apply -f ../instances/graviton-deployment.yaml

echo -e "${YELLOW}⏳ Waiting for Karpenter to provision nodes...${NC}"
sleep 30

echo -e "${GREEN}✅ Test workloads deployed!${NC}"
echo -e "${YELLOW}📊 Current status:${NC}"
kubectl get nodes -o wide
echo ""
kubectl get pods -o wide
echo ""

# Summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              🎉 DEPLOYMENT COMPLETED! 🎉                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📋 Quick validation commands:${NC}"
echo -e "  ${BLUE}# View all resources${NC}"
echo -e "  kubectl get nodes,nodepools,nodeclaims,pods -o wide"
echo ""
echo -e "  ${BLUE}# Test AMD64 pod architecture${NC}"
echo -e "  AMD64_POD=\$(kubectl get pods -l app=spot-workload -o jsonpath='{.items[0].metadata.name}')"
echo -e "  kubectl exec \$AMD64_POD -- uname -m  # Should output: x86_64"
echo ""
echo -e "  ${BLUE}# Test Graviton pod architecture${NC}"
echo -e "  ARM64_POD=\$(kubectl get pods -l app=graviton-workload -o jsonpath='{.items[0].metadata.name}')"
echo -e "  kubectl exec \$ARM64_POD -- uname -m  # Should output: aarch64"
echo ""
echo -e "  ${BLUE}# Run automated tests${NC}"
echo -e "  ./test-deployment.sh"
echo ""
echo -e "${YELLOW}📝 To clean up:${NC}"
echo -e "  ./destroy.sh"
echo ""
