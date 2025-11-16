# 2-helm: Karpenter Helm Deployment

This directory manages the Karpenter deployment using Terraform Helm provider instead of bash scripts.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with valid credentials
- kubectl installed
- Infrastructure from stage `1-infra` already applied

## Files

- **backend.tf** - S3 backend configuration for Terraform state
- **main.tf** - Helm provider and helm_release resource for Karpenter
- **variables.tf** - Configurable variables
- **outputs.tf** - Deployment outputs
- **helm_values.yaml** - Karpenter Helm chart values
- **terraform.tfvars** (optional) - Custom variable values

## Usage

### Initialize Terraform

```bash
cd 1-task/2-helm
terraform init
```

### Validate configuration

```bash
terraform validate
terraform plan
```

### Apply deployment

```bash
terraform apply
```

Terraform will:
- Read outputs from `1-infra` stage via remote state
- Create the `karpenter` namespace
- Install Karpenter via Helm using official OCI chart
- Configure IRSA automatically
- Wait until deployment is ready

### Verify deployment

```bash
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

kubectl get pods -n karpenter

kubectl get crd | grep karpenter
```

## Customization

All configurations are in `helm_values.yaml`. Edit that file to customize:
- Controller resources
- Replicas
- Affinity rules
- Any other Helm chart values

To change Karpenter version, edit `variables.tf` or create `terraform.tfvars`:

```hcl
karpenter_version = "1.8.1"
```

## Update

To update Karpenter:

```bash
terraform apply
```

## Removal

To remove Karpenter:

```bash
terraform destroy
```

**Warning:** Ensure there are no active NodeClaims before destroying Karpenter.

## Outputs

After apply, view outputs:

```bash
terraform output
```

Available outputs:
- `karpenter_release_name`
- `karpenter_namespace`
- `karpenter_version`
- `karpenter_status`
- `cluster_name`
- `aws_region`

## Next steps

After Karpenter deployment:

1. Apply NodePools and EC2NodeClasses in `../3-karpenter`:
   ```bash
   cd ../3-karpenter
   terraform init
   terraform apply
   ```

2. Test the deployment:
   ```bash
   cd ..
   ./test-deployment.sh
   ```

## Benefits vs Bash Scripts

### Before (bash scripts):
- Manual deployment via bash
- Difficult to version and track changes
- No state management
- Difficult rollback
- Limited validation

### Now (Terraform):
- Declarative infrastructure as code
- Automatic state management
- Easy rollback and updates
- Validation before apply
- CI/CD pipeline integration
- Drift detection

## Troubleshooting

### Error: "Kubernetes cluster unreachable"

Verify AWS credentials:
```bash
aws sts get-caller-identity
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>
```

### Error: "Failed to download chart"

Logout from OCI registry:
```bash
helm registry logout public.ecr.aws
```

### Timeout on deployment

Increase timeout in `main.tf`:
```hcl
timeout = 600
```
