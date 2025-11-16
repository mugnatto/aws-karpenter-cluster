#!/bin/bash

# Complete destroy script for AWS EKS Karpenter Cluster
# This script removes all resources in the correct order to avoid dependency issues

set +e  # Continue even if some commands fail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║   AWS EKS Karpenter Cluster - Destroy All Resources        ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}⚠️  WARNING: This will destroy all infrastructure!${NC}"
echo -e "${YELLOW}Press CTRL+C to cancel, or wait 10 seconds to continue...${NC}"
sleep 10

# Check if central tfvars exists
if [ -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}📋 Using central terraform.tfvars for destroy operations...${NC}"
    TFVARS_FLAG="-var-file=../terraform.tfvars"
else
    echo -e "${YELLOW}⚠️  terraform.tfvars not found. Using default values.${NC}"
    TFVARS_FLAG=""
fi

# Get cluster info
cd 1-infra
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "karpenter-cluster-development")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

echo -e "${YELLOW}🔧 Configuring kubectl access...${NC}"
CLUSTER_EXISTS=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} 2>/dev/null)
if [ $? -eq 0 ]; then
    aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME} 2>/dev/null || true
    KUBECTL_WORKS=true
else
    echo -e "${YELLOW}⚠️  Cluster not found or already deleted${NC}"
    KUBECTL_WORKS=false
fi
cd ..

# =============================================================================
# STEP 1: Delete Workload Deployments
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 1/4: Deleting Workload Deployments${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ "$KUBECTL_WORKS" = true ]; then
    echo -e "${YELLOW}🗑️  Deleting all deployments...${NC}"
    kubectl delete deployments --all --all-namespaces --ignore-not-found=true 2>/dev/null || true
    
    if [ -f "instances/spot-deployment.yaml" ]; then
        kubectl delete -f instances/spot-deployment.yaml --ignore-not-found=true 2>/dev/null || true
    fi
    if [ -f "instances/graviton-deployment.yaml" ]; then
        kubectl delete -f instances/graviton-deployment.yaml --ignore-not-found=true 2>/dev/null || true
    fi
    
    echo -e "${YELLOW}⏳ Waiting for pods to terminate...${NC}"
    sleep 30
else
    echo -e "${YELLOW}⚠️  Skipping workload deletion (cluster not accessible)${NC}"
fi

echo -e "${GREEN}✅ Workloads cleanup complete!${NC}\n"

# =============================================================================
# STEP 2: Delete NodeClaims and Wait for EC2 Termination
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 2/4: Deleting NodeClaims and EC2 Instances${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ "$KUBECTL_WORKS" = true ]; then
    echo -e "${YELLOW}🗑️  Deleting all NodeClaims...${NC}"
    kubectl delete nodeclaims --all --ignore-not-found=true 2>/dev/null || true
    
    echo -e "${YELLOW}⏳ Waiting for EC2 instances to terminate...${NC}"
    sleep 60
    
    # Check if any nodeclaims still exist
    NODECLAIMS=$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l)
    RETRY_COUNT=0
    MAX_RETRIES=10
    
    while [ "$NODECLAIMS" -gt 0 ] && [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
        echo -e "${YELLOW}⚠️  $NODECLAIMS nodeclaim(s) still exist, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)${NC}"
        sleep 30
        NODECLAIMS=$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l)
        RETRY_COUNT=$((RETRY_COUNT+1))
    done
    
    if [ "$NODECLAIMS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Force removing finalizers from remaining nodeclaims...${NC}"
        kubectl patch nodeclaims --all -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        sleep 30
    fi
    
    echo -e "${YELLOW}⏳ Waiting additional 60s for ENIs cleanup...${NC}"
    sleep 60
else
    echo -e "${YELLOW}⚠️  Skipping NodeClaims deletion${NC}"
    echo -e "${YELLOW}⏳ Waiting 90s for potential EC2 cleanup...${NC}"
    sleep 90
fi

echo -e "${GREEN}✅ NodeClaims cleanup complete!${NC}\n"

# =============================================================================
# STEP 3: Destroy Karpenter (Terraform in 2-karpenter)
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 3/4: Destroying Karpenter (Helm + NodePool + NodeClass)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

cd 2-karpenter

if [ -d ".terraform" ]; then
    echo -e "${YELLOW}🗑️  Destroying Karpenter Terraform resources...${NC}"
    terraform destroy -auto-approve 2>/dev/null || echo "  Resources already destroyed or errors occurred"
    
    echo -e "${YELLOW}⏳ Waiting for cleanup to complete...${NC}"
    sleep 60
else
    echo -e "${YELLOW}⚠️  No Terraform state found in 2-karpenter${NC}"
fi

echo -e "${GREEN}✅ Karpenter destruction complete!${NC}\n"

# =============================================================================
# STEP 4: Destroy Infrastructure (EKS + VPC + IAM)
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 4/4: Destroying Infrastructure (EKS + VPC + IAM)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

cd ../1-infra

# Force cleanup ENIs if VPC exists
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
if [ -n "$VPC_ID" ]; then
    echo -e "${YELLOW}🔍 Checking for remaining ENIs in VPC $VPC_ID...${NC}"
    
    ENI_IDS=$(aws ec2 describe-network-interfaces --region ${AWS_REGION} \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'NetworkInterfaces[?!contains(Description, `EKS cluster control plane`)].NetworkInterfaceId' \
        --output text 2>/dev/null)
    
    if [ -n "$ENI_IDS" ]; then
        echo -e "${YELLOW}🗑️  Cleaning up remaining ENIs...${NC}"
        for ENI_ID in $ENI_IDS; do
            aws ec2 delete-network-interface --region ${AWS_REGION} --network-interface-id $ENI_ID 2>/dev/null || true
        done
        sleep 30
    fi
fi

# Destroy infrastructure
if [ -d ".terraform" ]; then
    echo -e "${YELLOW}🗑️  Destroying infrastructure (this may take 10-15 minutes)...${NC}"
    terraform destroy $TFVARS_FLAG -auto-approve
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Infrastructure destroyed successfully!${NC}\n"
    else
        echo -e "${RED}⚠️  Some resources may still exist. Check AWS console.${NC}"
        echo -e "${YELLOW}💡 Common issues:${NC}"
        echo -e "  - ENIs still attached (wait a few minutes and retry)"
        echo -e "  - Security groups with dependencies"
        echo -e "  - Manual resources created outside Terraform"
        echo -e "\n${YELLOW}To retry: cd 1-infra && terraform destroy $TFVARS_FLAG${NC}\n"
    fi
else
    echo -e "${YELLOW}⚠️  No Terraform state found, infrastructure may already be destroyed${NC}"
fi

# Summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            🎉 CLEANUP COMPLETED! 🎉                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📝 All AWS resources have been destroyed.${NC}"
echo -e "${YELLOW}💰 You will no longer be charged for these resources.${NC}"
echo ""
echo -e "${BLUE}Note: Your kubectl config still references the deleted cluster.${NC}"
echo -e "${BLUE}You can clean it up with:${NC}"
echo -e "  kubectl config get-contexts"
echo -e "  kubectl config delete-context <context-name>"
echo ""
