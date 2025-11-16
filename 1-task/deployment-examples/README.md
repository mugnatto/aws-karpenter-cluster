# Example Deployments

This directory contains example Kubernetes deployments demonstrating how to run workloads on different architectures.

## Quick Start

```bash
# Deploy all examples
kubectl apply -f examples/

# Check what nodes were provisioned
kubectl get nodes -L kubernetes.io/arch

# Check where pods are running
kubectl get pods -o wide
```

## Examples

### 1. Automatic Selection (`01-auto-arch.yaml`)
Let Karpenter choose the best architecture (usually ARM64 for cost savings).

```bash
kubectl apply -f examples/01-auto-arch.yaml
kubectl get pods -l app=nginx-auto -o wide
```

### 2. Force x86 (`02-force-x86.yaml`)
Explicitly request AMD64 nodes.

```bash
kubectl apply -f examples/02-force-x86.yaml

# Verify architecture
POD=$(kubectl get pods -l app=nginx-x86 -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- uname -m
# Expected: x86_64
```

### 3. Force Graviton (`03-force-graviton.yaml`)
Explicitly request ARM64/Graviton nodes.

```bash
kubectl apply -f examples/03-force-graviton.yaml

# Verify architecture
POD=$(kubectl get pods -l app=nginx-graviton -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- uname -m
# Expected: aarch64
```

### 4. Mixed Workload (`04-mixed-workload.yaml`)
Distribute pods across both architectures using topology spread constraints.

```bash
kubectl apply -f examples/04-mixed-workload.yaml
kubectl get pods -l app=mixed-workload -o wide
```

## Verify Node Architectures

```bash
# Show all nodes with their architecture
kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type

# Show pods and which architecture they're on
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
ARCH:.spec.nodeSelector.kubernetes\\.io/arch
```

## Cleanup

```bash
kubectl delete -f examples/
```

## Notes

- All nginx images used are multi-architecture
- Karpenter will provision nodes on-demand
- Nodes will be consolidated when underutilized (after 1 minute)
- Spot instances are preferred for cost savings

