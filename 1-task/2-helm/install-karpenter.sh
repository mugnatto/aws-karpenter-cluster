#!/bin/bash

# 2-helm: Karpenter Installation via Helm
# This script installs Karpenter using Helm after the infrastructure is ready

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Installing Karpenter via Helm...${NC}"

# Extract values from terraform state (works with remote backend)
export CLUSTER_NAME=$(cd ../1-infra && terraform output -raw cluster_name)
export AWS_DEFAULT_REGION=$(cd ../1-infra && terraform output -raw aws_region)
export AWS_REGION=${AWS_DEFAULT_REGION}
export KARPENTER_IAM_ROLE_ARN=$(cd ../1-infra && terraform output -raw karpenter_iam_role_arn)
export CLUSTER_ENDPOINT=$(cd ../1-infra && terraform output -raw cluster_endpoint)
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export AWS_PARTITION="aws"

# Configuration
export KARPENTER_VERSION="1.8.1"
export KARPENTER_NAMESPACE="karpenter"

echo -e "${YELLOW}📋 Configuration:${NC}"
echo -e "  Cluster Name: ${CLUSTER_NAME}"
echo -e "  Cluster Endpoint: ${CLUSTER_ENDPOINT}"
echo -e "  AWS Region: ${AWS_REGION}"
echo -e "  AWS Account: ${AWS_ACCOUNT_ID}"
echo -e "  Karpenter Version: ${KARPENTER_VERSION}"
echo -e "  Namespace: ${KARPENTER_NAMESPACE}"
echo -e "  IAM Role: ${KARPENTER_IAM_ROLE_ARN}"

# Configure kubectl
echo -e "${BLUE}🔧 Configuring kubectl...${NC}"
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

# Verify cluster access
echo -e "${BLUE}🔍 Verifying cluster access...${NC}"
kubectl get nodes || {
    echo -e "${RED}❌ Error: Cannot access cluster. Please check your AWS credentials and cluster status.${NC}"
    exit 1
}

# Logout of helm registry to perform an unauthenticated pull against the public ECR
echo -e "${BLUE}🔓 Logging out of Helm registry...${NC}"
helm registry logout public.ecr.aws || true

# Install Karpenter using OCI registry (official method)
echo -e "${BLUE}⚙️ Installing Karpenter from public ECR...${NC}"
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace "${KARPENTER_NAMESPACE}" \
  --create-namespace \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.clusterEndpoint=${CLUSTER_ENDPOINT}" \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${KARPENTER_IAM_ROLE_ARN}" \
  --set "controller.resources.requests.cpu=1" \
  --set "controller.resources.requests.memory=1Gi" \
  --set "controller.resources.limits.cpu=1" \
  --set "controller.resources.limits.memory=1Gi" \
  --set "replicas=1"

# Wait for Karpenter to be ready
echo -e "${BLUE}⏳ Waiting for Karpenter to be ready...${NC}"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=karpenter -n ${KARPENTER_NAMESPACE} --timeout=300s

# Verify installation
echo -e "${BLUE}✅ Verifying Karpenter installation...${NC}"
kubectl get pods -n ${KARPENTER_NAMESPACE} | grep karpenter
kubectl get crd | grep karpenter

echo -e "${GREEN}🎉 Karpenter installed successfully!${NC}"
echo -e "${YELLOW}📝 Next steps:${NC}"
echo -e "  1. Run 'terraform apply' in ../3-karpenter/ to create NodePools and EC2NodeClasses"
echo -e "  2. Deploy test workloads to verify Karpenter is working"
echo -e "  3. Run '../test-deployment.sh' to validate the deployment"
