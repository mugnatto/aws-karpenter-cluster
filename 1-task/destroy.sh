#!/bin/bash

# Complete destroy script for AWS EKS Karpenter Cluster
# This script removes all resources in the correct order to avoid dependency issues

# Don't exit on error - we want to continue even if some resources are already deleted
set +e

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

# Configure kubectl
cd 1-infra
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "karpenter-cluster-development")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

echo -e "${YELLOW}🔧 Configuring kubectl access...${NC}"
# Check if cluster exists before trying to configure kubectl
CLUSTER_EXISTS=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} 2>/dev/null)
if [ $? -eq 0 ]; then
    aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME} 2>/dev/null || true
    KUBECTL_WORKS=true
else
    echo -e "${YELLOW}⚠️  Cluster not found or already deleted, skipping kubectl operations${NC}"
    KUBECTL_WORKS=false
fi
cd ..

# Step 1: Delete workload deployments
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 1/6: Deleting Workload Deployments${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ "$KUBECTL_WORKS" = true ]; then
    echo -e "${YELLOW}🗑️  Deleting test workloads...${NC}"
    kubectl delete -f instances/spot-deployment.yaml --ignore-not-found=true 2>/dev/null || echo "  Spot workload not found or already deleted"
    kubectl delete -f instances/graviton-deployment.yaml --ignore-not-found=true 2>/dev/null || echo "  Graviton workload not found or already deleted"

    echo -e "${YELLOW}⏳ Waiting for pods to terminate...${NC}"
    kubectl wait --for=delete pod -l app=spot-workload --timeout=60s 2>/dev/null || true
    kubectl wait --for=delete pod -l app=graviton-workload --timeout=60s 2>/dev/null || true
else
    echo -e "${YELLOW}⚠️  Skipping workload deletion (cluster not accessible)${NC}"
fi

echo -e "${GREEN}✅ Workloads cleanup complete!${NC}\n"

# Step 2: Delete NodeClaims
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 2/6: Deleting NodeClaims and EC2 Instances${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ "$KUBECTL_WORKS" = true ]; then
    echo -e "${YELLOW}🗑️  Deleting NodeClaims...${NC}"
    kubectl delete nodeclaims --all --ignore-not-found=true 2>/dev/null || echo "  No NodeClaims found or already deleted"

    echo -e "${YELLOW}⏳ Waiting for EC2 instances to terminate...${NC}"
    sleep 30

    # Check if any nodeclaims still exist
    NODECLAIMS=$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l)
    RETRY_COUNT=0
    MAX_RETRIES=6

    while [ "$NODECLAIMS" -gt 0 ] && [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
        echo -e "${YELLOW}⚠️  $NODECLAIMS nodeclaim(s) still exist, waiting 30s... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)${NC}"
        sleep 30
        NODECLAIMS=$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l)
        RETRY_COUNT=$((RETRY_COUNT+1))
    done

    if [ "$NODECLAIMS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some nodeclaims still exist after waiting, forcing deletion...${NC}"
        kubectl patch nodeclaims --all -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    fi

    echo -e "${YELLOW}⏳ Waiting additional 60s for ENIs to be cleaned up...${NC}"
    sleep 60
else
    echo -e "${YELLOW}⚠️  Skipping NodeClaims deletion (cluster not accessible)${NC}"
    echo -e "${YELLOW}⏳ Waiting 60s for any remaining EC2 instances to terminate...${NC}"
    sleep 60
fi

echo -e "${GREEN}✅ NodeClaims cleanup complete!${NC}\n"

# Step 3: Destroy Karpenter Resources
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 3/6: Destroying Karpenter Resources (NodePools/EC2NodeClasses)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
cd 3-karpenter

if [ -f "terraform.tfstate" ] || [ -f ".terraform/terraform.tfstate" ]; then
    echo -e "${YELLOW}🗑️  Destroying Karpenter Terraform resources...${NC}"
    terraform destroy -auto-approve 2>/dev/null || echo "  Resources already destroyed or not found"
else
    echo -e "${YELLOW}⚠️  No Terraform state found, skipping Karpenter resources destruction${NC}"
fi

echo -e "${GREEN}✅ Karpenter resources cleanup complete!${NC}\n"

# Step 4: Uninstall Karpenter Helm Release
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 4/6: Uninstalling Karpenter Helm Release${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ "$KUBECTL_WORKS" = true ]; then
    echo -e "${YELLOW}🗑️  Uninstalling Karpenter...${NC}"
    helm uninstall karpenter -n karpenter 2>/dev/null || echo "  Karpenter already uninstalled or not found"

    echo -e "${YELLOW}🗑️  Deleting Karpenter namespace...${NC}"
    kubectl delete namespace karpenter --ignore-not-found=true --timeout=60s 2>/dev/null || true
else
    echo -e "${YELLOW}⚠️  Skipping Karpenter Helm uninstall (cluster not accessible)${NC}"
fi

echo -e "${GREEN}✅ Karpenter uninstall complete!${NC}\n"

# Step 5: Verify ENIs are cleaned up
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 5/6: Verifying Network Interfaces Cleanup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}🔍 Checking for remaining ENIs in cluster subnets...${NC}"
cd ../1-infra

# Get VPC ID from terraform state
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")

if [ -n "$VPC_ID" ]; then
    RETRY_COUNT=0
    MAX_RETRIES=6
    
    while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
        # Check for ENIs in the VPC that are not attached to the cluster control plane
        ENI_COUNT=$(aws ec2 describe-network-interfaces --region ${AWS_REGION} \
            --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=*karpenter*" \
            --query 'NetworkInterfaces[?Status!=`available`]' --output text 2>/dev/null | wc -l)
        
        if [ "$ENI_COUNT" -eq 0 ]; then
            echo -e "${GREEN}✅ All Karpenter ENIs have been cleaned up!${NC}"
            break
        fi
        
        echo -e "${YELLOW}⚠️  $ENI_COUNT ENI(s) still exist, waiting 30s... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)${NC}"
        sleep 30
        RETRY_COUNT=$((RETRY_COUNT+1))
    done
else
    echo -e "${YELLOW}⚠️  Could not determine VPC ID, skipping ENI check${NC}"
    sleep 30
fi

echo -e "${GREEN}✅ Network cleanup verified!${NC}\n"

# Step 6: Destroy Infrastructure
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  STEP 6/6: Destroying Infrastructure (EKS + VPC + IAM)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ -f "terraform.tfstate" ] || [ -f ".terraform/terraform.tfstate" ]; then
    echo -e "${YELLOW}🗑️  Destroying infrastructure...${NC}"
    terraform destroy -auto-approve
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Infrastructure destroyed successfully!${NC}\n"
    else
        echo -e "${RED}⚠️  Some infrastructure resources may still exist. Please check AWS console.${NC}\n"
        echo -e "${YELLOW}💡 Common issues:${NC}"
        echo -e "  - ENIs still attached to subnets (wait a few minutes and try again)"
        echo -e "  - Security groups with dependencies (check EC2 console)"
        echo -e "  - LoadBalancers created by services (delete manually if needed)"
        echo -e "\n${YELLOW}To retry: cd 1-infra && terraform destroy${NC}\n"
    fi
else
    echo -e "${YELLOW}⚠️  No Terraform state found, infrastructure may already be destroyed${NC}"
fi

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
