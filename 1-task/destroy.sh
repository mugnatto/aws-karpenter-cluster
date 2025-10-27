#!/bin/bash

# Complete destroy script for AWS EKS Karpenter Cluster
# This script removes all resources in the correct order to avoid dependency issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║   AWS EKS Karpenter Cluster - Destroy All Resources       ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}⚠️  WARNING: This will destroy all infrastructure!${NC}"
echo -e "${YELLOW}Press CTRL+C to cancel, or wait 10 seconds to continue...${NC}"
sleep 10

# Configure kubectl
cd 1-infra
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "karpenter-cluster-development")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

echo -e "${YELLOW}🔧 Configuring kubectl access...${NC}"
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME} 2>/dev/null || true
cd ..

# Step 1: Delete workload deployments
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 1/5: Deleting Workload Deployments${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}🗑️  Deleting test workloads...${NC}"
kubectl delete -f instances/spot-deployment.yaml --ignore-not-found=true
kubectl delete -f instances/graviton-deployment.yaml --ignore-not-found=true

echo -e "${YELLOW}⏳ Waiting for pods to terminate...${NC}"
kubectl wait --for=delete pod -l app=spot-workload --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pod -l app=graviton-workload --timeout=60s 2>/dev/null || true

echo -e "${GREEN}✅ Workloads deleted!${NC}\n"

# Step 2: Delete NodeClaims
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 2/5: Deleting NodeClaims and EC2 Instances${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}🗑️  Deleting NodeClaims...${NC}"
kubectl delete nodeclaims --all --ignore-not-found=true

echo -e "${YELLOW}⏳ Waiting for EC2 instances to terminate (max 2 minutes)...${NC}"
sleep 30

# Check if any nodeclaims still exist
NODECLAIMS=$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l)
if [ "$NODECLAIMS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some nodeclaims still exist, waiting longer...${NC}"
    sleep 60
fi

echo -e "${GREEN}✅ NodeClaims deleted!${NC}\n"

# Step 3: Destroy Karpenter Resources
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 3/5: Destroying Karpenter Resources (NodePools/EC2NodeClasses)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
cd 3-karpenter

echo -e "${YELLOW}🗑️  Destroying Karpenter Terraform resources...${NC}"
terraform destroy -auto-approve

echo -e "${GREEN}✅ Karpenter resources destroyed!${NC}\n"

# Step 4: Uninstall Karpenter Helm Release
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 4/5: Uninstalling Karpenter Helm Release${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}🗑️  Uninstalling Karpenter...${NC}"
helm uninstall karpenter -n karpenter 2>/dev/null || echo "  Karpenter already uninstalled"

echo -e "${YELLOW}🗑️  Deleting Karpenter namespace...${NC}"
kubectl delete namespace karpenter --ignore-not-found=true --timeout=60s 2>/dev/null || true

echo -e "${GREEN}✅ Karpenter uninstalled!${NC}\n"

# Step 5: Destroy Infrastructure
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 5/5: Destroying Infrastructure (EKS + VPC + IAM)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
cd ../1-infra

echo -e "${YELLOW}🗑️  Destroying infrastructure...${NC}"
terraform destroy -auto-approve

echo -e "${GREEN}✅ Infrastructure destroyed!${NC}\n"

# Final cleanup
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            🎉 CLEANUP COMPLETED! 🎉                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📝 All AWS resources have been destroyed.${NC}"
echo -e "${YELLOW}💰 You will no longer be charged for these resources.${NC}"
echo ""
echo -e "${BLUE}Note: Your kubectl config still references the deleted cluster.${NC}"
echo -e "${BLUE}You can clean it up with: kubectl config delete-context <context-name>${NC}"
echo ""
