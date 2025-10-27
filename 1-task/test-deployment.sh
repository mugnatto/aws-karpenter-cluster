#!/bin/bash

# Test script to validate Karpenter deployment
# This script verifies that both AMD64 and ARM64 (Graviton) workloads are running correctly


set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing Karpenter Deployment${NC}\n"

# 1. Check nodes
echo -e "${YELLOW}📋 Nodes in cluster:${NC}"
kubectl get nodes -o wide | grep -E "NAME|ec2.internal"
echo ""

# 2. Check NodePools
echo -e "${YELLOW}📋 NodePools status:${NC}"
kubectl get nodepools
echo ""

# 3. Check NodeClaims
echo -e "${YELLOW}📋 NodeClaims status:${NC}"
kubectl get nodeclaims
echo ""

# 4. Check workload pods
echo -e "${YELLOW}📋 Workload pods:${NC}"
kubectl get pods -o wide
echo ""

# 5. Test Graviton (ARM64) pod
echo -e "${YELLOW}🧪 Testing Graviton (ARM64) pod:${NC}"
GRAVITON_POD=$(kubectl get pods -l app=graviton-workload -o jsonpath='{.items[0].metadata.name}')
if [ -n "$GRAVITON_POD" ]; then
    ARCH=$(kubectl exec $GRAVITON_POD -- uname -m)
    NODE=$(kubectl get pod $GRAVITON_POD -o jsonpath='{.spec.nodeName}')
    echo -e "  Pod: ${GREEN}$GRAVITON_POD${NC}"
    echo -e "  Node: ${GREEN}$NODE${NC}"
    echo -e "  Architecture: ${GREEN}$ARCH${NC}"
    if [ "$ARCH" == "aarch64" ]; then
        echo -e "  ${GREEN}✅ ARM64 (Graviton) confirmed!${NC}"
    else
        echo -e "  ${RED}❌ Expected aarch64, got $ARCH${NC}"
    fi
else
    echo -e "  ${RED}❌ No Graviton pods found${NC}"
fi
echo ""

# 6. Test Spot (AMD64) pod
echo -e "${YELLOW}🧪 Testing Spot (AMD64) pod:${NC}"
SPOT_POD=$(kubectl get pods -l app=spot-workload -o jsonpath='{.items[0].metadata.name}')
if [ -n "$SPOT_POD" ]; then
    ARCH=$(kubectl exec $SPOT_POD -- uname -m)
    NODE=$(kubectl get pod $SPOT_POD -o jsonpath='{.spec.nodeName}')
    echo -e "  Pod: ${GREEN}$SPOT_POD${NC}"
    echo -e "  Node: ${GREEN}$NODE${NC}"
    echo -e "  Architecture: ${GREEN}$ARCH${NC}"
    if [ "$ARCH" == "x86_64" ]; then
        echo -e "  ${GREEN}✅ AMD64 (x86_64) confirmed!${NC}"
    else
        echo -e "  ${RED}❌ Expected x86_64, got $ARCH${NC}"
    fi
else
    echo -e "  ${RED}❌ No Spot pods found${NC}"
fi
echo ""

# 7. Check Karpenter logs for errors
echo -e "${YELLOW}📋 Recent Karpenter activity:${NC}"
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=5 --since=2m | grep -E "created nodeclaim|launched nodeclaim|deleted nodeclaim" || echo "  No recent provisioning activity"
echo ""

# 8. Summary
echo -e "${GREEN}✅ Deployment validation complete!${NC}"
echo -e "${BLUE}📊 Summary:${NC}"
echo -e "  - Fargate nodes: $(kubectl get nodes | grep fargate | wc -l)"
echo -e "  - EC2 nodes (Karpenter): $(kubectl get nodes | grep -v fargate | grep ec2.internal | wc -l)"
echo -e "  - AMD64 nodes: $(kubectl get nodes -l kubernetes.io/arch=amd64 | grep -v NAME | grep -v fargate | wc -l)"
echo -e "  - ARM64 nodes: $(kubectl get nodes -l kubernetes.io/arch=arm64 | grep -v NAME | wc -l)"
echo -e "  - Running workload pods: $(kubectl get pods | grep Running | wc -l)"
echo ""

