#!/bin/bash

# Uninstall Karpenter from EKS cluster
# This script safely removes Karpenter and cleans up resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🗑️  Uninstalling Karpenter...${NC}\n"

# Get cluster info
export CLUSTER_NAME=$(cd ../1-infra && terraform output -raw cluster_name 2>/dev/null || echo "karpenter-cluster-development")
export AWS_REGION=$(cd ../1-infra && terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
export KARPENTER_NAMESPACE="karpenter"

echo -e "${YELLOW}📋 Configuration:${NC}"
echo -e "  Cluster Name: ${CLUSTER_NAME}"
echo -e "  AWS Region: ${AWS_REGION}"
echo -e "  Namespace: ${KARPENTER_NAMESPACE}"
echo ""

# Configure kubectl
echo -e "${BLUE}🔧 Configuring kubectl...${NC}"
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

# Delete all NodeClaims first
echo -e "${BLUE}🗑️  Deleting NodeClaims...${NC}"
kubectl delete nodeclaims --all --ignore-not-found=true || true

echo -e "${YELLOW}⏳ Waiting for EC2 instances to terminate...${NC}"
sleep 30

# Uninstall Karpenter Helm release
echo -e "${BLUE}🗑️  Uninstalling Karpenter Helm release...${NC}"
helm uninstall karpenter -n ${KARPENTER_NAMESPACE} || {
    echo -e "${YELLOW}⚠️  Karpenter release not found or already uninstalled${NC}"
}

# Delete namespace
echo -e "${BLUE}🗑️  Deleting Karpenter namespace...${NC}"
kubectl delete namespace ${KARPENTER_NAMESPACE} --ignore-not-found=true --timeout=60s || true

# Verify cleanup
echo -e "${BLUE}✅ Verifying cleanup...${NC}"
helm list -n ${KARPENTER_NAMESPACE} || true
kubectl get namespace ${KARPENTER_NAMESPACE} 2>/dev/null || echo -e "${GREEN}  Namespace deleted successfully${NC}"

echo ""
echo -e "${GREEN}🎉 Karpenter uninstalled successfully!${NC}"echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo -e "  1. To remove NodePools/EC2NodeClasses: cd ../3-karpenter && terraform destroy"
echo -e "  2. To remove all infrastructure: cd ../1-infra && terraform destroy"
echo -e "  3. Or run the complete destroy script: cd .. && ./destroy.sh"
echo ""

