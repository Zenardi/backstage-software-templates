# EKS Deployment Order

This file defines the correct order to apply Crossplane resources to avoid dependency issues.

- [EKS Deployment Order](#eks-deployment-order)
  - [Order of Application](#order-of-application)
    - [Phase 1: Providers (Apply First)](#phase-1-providers-apply-first)
    - [Phase 2: Networking (Second)](#phase-2-networking-second)
    - [Phase 3: IAM (Third)](#phase-3-iam-third)
    - [Phase 4: EKS Cluster (Fourth)](#phase-4-eks-cluster-fourth)
    - [Phase 5: Add-ons (Fifth)](#phase-5-add-ons-fifth)
  - [Quick Deploy Script](#quick-deploy-script)
  - [Verification](#verification)
  - [Cleanup](#cleanup)


## Order of Application

### Phase 1: Providers (Apply First)
```bash
kubectl apply -f template/provider-config.yaml -n eks-demo
kubectl apply -f template/providers.yaml -n eks-demo
```

Wait for providers to be ready:
```bash
kubectl wait --for=condition=healthy --timeout=300s provider.pkg.crossplane.io --all -n eks-demo
```

### Phase 2: Networking (Second)
```bash
kubectl apply -f template/networking.yaml -n eks-demo
kubectl apply -f template/security-groups.yaml -n eks-demo
```

Wait for VPC and subnets:
```bash
kubectl wait --for=condition=ready --timeout=600s vpc.ec2.aws.m.upbound.io --all -n eks-demo
kubectl wait --for=condition=ready --timeout=600s subnet.ec2.aws.m.upbound.io --all -n eks-demo
kubectl wait --for=condition=ready --timeout=600s securitygroup.ec2.aws.m.upbound.io --all -n eks-demo
```

### Phase 3: IAM (Third)
```bash
kubectl apply -f template/iam.yaml -n eks-demo
```

Wait for IAM roles:
```bash
kubectl wait --for=condition=ready --timeout=600s role.iam.aws.m.upbound.io --all -n eks-demo
```

### Phase 4: EKS Cluster (Fourth)
```bash
kubectl apply -f template/eks.yaml -n eks-demo
```

This takes 10-15 minutes. Monitor with:
```bash
kubectl wait --for=condition=ready --timeout=1800s cluster.eks.aws.m.upbound.io --all -n eks-demo
```

### Phase 5: Add-ons (Fifth)
```bash
kubectl apply -f template/addon.yaml -n eks-demo
```

Wait for add-ons:
```bash
kubectl wait --for=condition=ready --timeout=600s addon.eks.aws.m.upbound.io --all -n eks-demo
```

## Quick Deploy Script

```bash
#!/bin/bash
set -e

NAMESPACE="eks-demo"

echo "Phase 1: Deploying providers..."
kubectl apply -f template/provider.yaml -n $NAMESPACE
kubectl apply -f template/provider-config.yaml -n $NAMESPACE
kubectl wait --for=condition=healthy --timeout=300s provider.pkg.crossplane.io --all -n $NAMESPACE

echo "Phase 2: Deploying networking and security groups..."
kubectl apply -f template/networking.yaml -n $NAMESPACE
kubectl apply -f template/security-groups.yaml -n $NAMESPACE
kubectl wait --for=condition=ready --timeout=600s vpc.ec2.aws.m.upbound.io --all -n $NAMESPACE
kubectl wait --for=condition=ready --timeout=600s subnet.ec2.aws.m.upbound.io --all -n $NAMESPACE

echo "Phase 3: Deploying IAM roles..."
kubectl apply -f template/iam.yaml -n $NAMESPACE
kubectl wait --for=condition=ready --timeout=600s role.iam.aws.m.upbound.io --all -n $NAMESPACE

echo "Phase 4: Deploying EKS cluster (this takes 10-15 minutes)..."
kubectl apply -f template/eks.yaml -n $NAMESPACE
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=ready --timeout=900s cluster.eks.aws.m.upbound.io/cheap-cluster -n $NAMESPACE

echo "Phase 5: Deploying EKS add-ons..."
kubectl apply -f template/addon.yaml -n $NAMESPACE
kubectl wait --for=condition=ready --timeout=600s addon.eks.aws.m.upbound.io --all -n $NAMESPACE

echo "✅ EKS cluster deployment complete!"
echo ""
echo "Configure kubeconfig with:"
echo "aws eks update-kubeconfig --name cheap-cluster --region us-east-1"
```

## Verification

Once complete, verify with:
```bash
# Check all Crossplane resources
kubectl get crossplane -A

# Configure kubeconfig
aws eks update-kubeconfig --name cheap-cluster --region us-east-1

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

## Cleanup

To delete everything:
```bash
# Delete in reverse order
kubectl delete -f template/addon.yaml -n eks-demo
kubectl delete -f template/eks.yaml -n eks-demo
kubectl delete -f template/iam.yaml -n eks-demo
kubectl delete -f template/security-groups.yaml -n eks-demo
kubectl delete -f template/networking.yaml -n eks-demo
```

Wait 5-10 minutes for AWS resources to be deleted before removing providers.
