# Migration to Unified Multi-Architecture Setup

## 🎯 What Changed

### Before (Old Structure):
```
1-infra/     → VPC + EKS + IAM (custom modules)
2-helm/      → Karpenter Helm install only
3-karpenter/ → Separate NodePools (AMD64 + ARM64)
```

### After (New Structure):
```
1-infra/     → VPC + EKS + IAM (same, using custom modules)
2-karpenter/ → Karpenter Helm + Single Multi-Arch NodePool
```

---

## 🚀 Key Improvements

### 1. **Unified Multi-Architecture NodePool**

**Before:** 2 separate NodePools
- `default` → AMD64 only (t3.medium, t3.large, t3.xlarge)
- `graviton` → ARM64 only (m6g, c6g families)

**After:** 1 NodePool for both!
```yaml
requirements:
  - key: kubernetes.io/arch
    operator: In
    values: ["amd64", "arm64"]  # ← Both!
  
  - key: karpenter.k8s.aws/instance-category
    operator: In
    values: ["c", "m", "t"]  # ← Flexible families
  
  - key: karpenter.k8s.aws/instance-generation
    operator: Gt
    values: ["2"]  # ← Only Gen 3+ instances
```

**Benefits:**
- ✅ Karpenter automatically picks **cheapest option** (ARM usually 20% cheaper)
- ✅ Better **availability** across AZs
- ✅ **Automatic fallback** if one arch is unavailable
- ✅ Simpler configuration

---

### 2. **Single EC2NodeClass (Multi-Arch Compatible)**

**Before:** 2 NodeClasses (duplicate config)

**After:** 1 NodeClass that works for both!
```yaml
amiSelectorTerms:
  - alias: bottlerocket@latest  # ← Auto-selects correct AMI for arch!
```

Karpenter **automatically** picks:
- `bottlerocket-aws-k8s-1.34-x86_64` for AMD64 pods
- `bottlerocket-aws-k8s-1.34-aarch64` for ARM64 pods

---

### 3. **Latest Karpenter 1.8.1 Features**

#### **a) Improved Disruption Control**
```yaml
disruption:
  consolidationPolicy: "WhenEmptyOrUnderutilized"
  consolidateAfter: "1m"  # ← Faster than old "5m"
```

#### **b) IMDSv2 Enforcement**
```yaml
metadataOptions:
  httpTokens: "required"  # ← Security best practice
  httpPutResponseHopLimit: 1
```

#### **c) Encrypted EBS by Default**
```yaml
blockDeviceMappings:
  - ebs:
      encrypted: true  # ← Not in old config
      iops: 3000
      throughput: 125  # ← Better performance
```

#### **d) Smart Instance Selection**
```yaml
# No hardcoded instance types!
# Uses instance-category and generation instead
```

**Old way:**
```yaml
values: ["t3.medium", "t3.large", "m6g.medium", ...]  # ← Manual list
```

**New way:**
```yaml
instance-category: ["c", "m", "t"]    # ← Any C/M/T family
instance-generation: Gt "2"            # ← Only Gen 3+
```

Benefits:
- ✅ Automatically uses **new instance types** as AWS releases them
- ✅ More **diversity** for Spot reliability
- ✅ Less maintenance

---

### 4. **Simplified Configuration Management**

**Removed:**
- ❌ `terraform/modules/karpenter/` (custom module)
- ❌ `3-karpenter/` directory
- ❌ Duplicate NodeClass configs
- ❌ `karpenter_version` variable (now in locals)

**Kept:**
- ✅ All in `2-karpenter/main.tf`
- ✅ Clean separation: Infra (1) → Karpenter (2)
- ✅ Single source of truth

---

## 📊 Resource Comparison

| **Before** | **After** |
|------------|-----------|
| 2 NodePools | 1 NodePool (multi-arch) |
| 2 EC2NodeClasses | 1 EC2NodeClass |
| 3 Terraform stages | 2 Terraform stages |
| Hardcoded instance types | Dynamic selection |
| No IMDSv2 enforcement | IMDSv2 required |
| Unencrypted EBS | Encrypted by default |
| 5min consolidation | 1min consolidation |

---

## 🎯 How Pods Choose Architecture

### Option 1: Let Karpenter Decide (Recommended)
```yaml
# No nodeSelector - Karpenter picks cheapest!
spec:
  containers:
  - image: nginx  # Must be multi-arch image
```

### Option 2: Force Specific Architecture
```yaml
spec:
  nodeSelector:
    kubernetes.io/arch: arm64  # Force ARM64
  containers:
  - image: my-arm-only-app
```

### Option 3: Use Topology Spread
```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/arch
    whenUnsatisfiable: ScheduleAnyway
```

---

## 🔧 Configuration Highlights

### userData for Bottlerocket
```toml
[settings.kubernetes]
"cluster-dns" = "172.20.0.10"

[settings.host-containers.admin]
enabled = false  # ← Disabled for security

[settings.host-containers.control]
enabled = true   # ← For debugging only
```

### Node Expiration
```yaml
expireAfter: "168h"  # 7 days (was 24h)
```
Longer lifecycle = less churn, but still rotates for security patches.

### Resource Limits
```yaml
limits:
  cpu: "100"      # Up from 50
  memory: "200Gi" # Up from 50Gi
```
More capacity for growth.

---

## 🚨 Breaking Changes

### For Application Teams:

**If your app uses:**
```yaml
nodeSelector:
  node-type: default  # ← REMOVED!
```

**Change to:**
```yaml
nodeSelector:
  workload-type: general  # ← New label
  # Or just remove and let Karpenter choose!
```

### For Monitoring:

**Old labels:**
- `node-type: default`
- `node-type: graviton`

**New label:**
- `workload-type: general`

---

## 📈 Expected Behavior

### Cost Optimization
Karpenter will:
1. **Prefer ARM64** when possible (20% cheaper)
2. **Use Spot** by default (up to 90% discount)
3. **Consolidate** nodes after 1 minute of underutilization
4. **Right-size** instances based on actual pod requirements

### Example Scenario:
```
Pod Request: 2 CPU, 4Gi RAM
Architecture: Not specified

Karpenter Decision Tree:
1. Check ARM64 Spot availability → m6g.large ($0.05/hr) ✓
2. Check AMD64 Spot availability → m5.large ($0.06/hr)
3. Pick: m6g.large (ARM64 Spot) → Save 20%!
```

---

## 🧪 Testing

### Verify Multi-Arch Support:
```bash
# Deploy AMD64 app
kubectl run nginx-amd64 --image=nginx --overrides='
{
  "spec": {
    "nodeSelector": {"kubernetes.io/arch": "amd64"}
  }
}'

# Deploy ARM64 app
kubectl run nginx-arm64 --image=nginx --overrides='
{
  "spec": {
    "nodeSelector": {"kubernetes.io/arch": "arm64"}
  }
}'

# Check nodes
kubectl get nodes -L kubernetes.io/arch
```

Expected: Both nodes provisioned by the same NodePool!

---

## 📚 References

- [Karpenter v1 Migration Guide](https://karpenter.sh/docs/upgrading/v1-migration/)
- [Multi-Arch Best Practices](https://aws.amazon.com/blogs/containers/multi-architecture-container-clusters/)
- [Instance Requirements](https://karpenter.sh/docs/concepts/nodepools/#instance-requirements)

