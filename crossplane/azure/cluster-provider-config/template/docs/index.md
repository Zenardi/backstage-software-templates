# AWS Cluster Provider Config

## Overview

This Backstage template provisions a Crossplane **ClusterProviderConfig** resource that enables Crossplane to authenticate and interact with AWS services. The ClusterProviderConfig is a critical foundational component that must be configured before deploying any AWS resources through Crossplane.

## What is a ClusterProviderConfig?

A ClusterProviderConfig is a cluster-scoped Crossplane resource that defines how Crossplane providers authenticate with cloud providers. Unlike namespace-scoped ProviderConfigs, ClusterProviderConfigs can be referenced across all namespaces in the cluster, making them ideal for centralized cloud credentials management.

## Purpose

This template creates the authentication bridge between your Kubernetes cluster and AWS, allowing Crossplane to:

- Provision and manage AWS infrastructure resources (EC2, S3, RDS, etc.)
- Apply infrastructure-as-code patterns to AWS resources
- Enable GitOps workflows for cloud infrastructure
- Provide a consistent API for AWS resource management

## What Gets Deployed

The template deploys a single `ClusterProviderConfig` resource that:

- **Name**: `default` (can be referenced by other Crossplane resources)
- **Credentials Source**: Kubernetes Secret
- **Secret Location**: `crossplane-system` namespace
- **Secret Name**: `aws-secret`
- **Secret Key**: `creds`

## Prerequisites

Before using this template, ensure:

1. **Crossplane Installed**: Crossplane must be installed in your cluster
   ```bash
   kubectl get pods -n crossplane-system
   ```

2. **AWS Provider Installed**: The Crossplane AWS provider must be deployed
   ```bash
   kubectl get providers
   ```

3. **AWS Credentials Secret**: A secret named `aws-secret` must exist in the `crossplane-system` namespace with valid AWS credentials

## Creating the AWS Credentials Secret

Create the AWS credentials secret using one of the following methods:

### Method 1: Using AWS Access Keys

```bash
# Create AWS credentials file
cat > aws-credentials.txt << EOF
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
EOF

# Create the secret
kubectl create secret generic aws-secret \
  -n crossplane-system \
  --from-file=creds=./aws-credentials.txt

# Clean up the credentials file
rm aws-credentials.txt
```

### Method 2: Using IAM Roles for Service Accounts (IRSA)

For EKS clusters, you can use IRSA for more secure credential management without storing long-lived AWS credentials.

## How It Works

1. Crossplane resources (like `Bucket`, `Instance`, `VPC`) reference the ClusterProviderConfig
2. When creating AWS resources, Crossplane uses the credentials from the referenced secret
3. The credentials are used to authenticate API calls to AWS
4. Resources are provisioned in your AWS account

## Usage Example

Once the ClusterProviderConfig is deployed, other Crossplane resources can reference it:

```yaml
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
metadata:
  name: my-crossplane-bucket
spec:
  forProvider:
    region: us-east-1
  providerConfigRef:
    name: default  # References this ClusterProviderConfig
```

## Validation

After deploying this template, verify the ClusterProviderConfig:

```bash
# Check if the resource was created
kubectl get clusterproviderconfig

# Verify the configuration details
kubectl describe clusterproviderconfig default

# Ensure the secret exists
kubectl get secret aws-secret -n crossplane-system
```

## Security Considerations

- **Secret Protection**: The AWS credentials are stored in a Kubernetes secret. Ensure RBAC policies restrict access to the `crossplane-system` namespace
- **Credential Rotation**: Regularly rotate AWS credentials and update the secret
- **Least Privilege**: Use IAM credentials with minimal required permissions
- **IRSA Preferred**: For EKS clusters, prefer IRSA over static credentials

## Troubleshooting

### Common Issues

**ClusterProviderConfig not working:**
- Verify the secret exists: `kubectl get secret aws-secret -n crossplane-system`
- Check secret format matches AWS credentials file format
- Ensure AWS provider is healthy: `kubectl get providers`

**Permission Errors:**
- Verify IAM credentials have necessary permissions for resources being created
- Check AWS CloudTrail for denied API calls

**Resources not creating:**
- Check Crossplane logs: `kubectl logs -n crossplane-system -l app=crossplane`
- Verify provider config is referenced correctly in resource manifests

## Next Steps

After deploying the ClusterProviderConfig:

1. Deploy AWS infrastructure resources (VPC, S3, RDS, etc.)
2. Create namespace-scoped ProviderConfigs for multi-tenant scenarios
3. Implement GitOps workflows using ArgoCD or Flux
4. Set up monitoring for Crossplane-managed resources

## Additional Resources

- [Crossplane Documentation](https://docs.crossplane.io)
- [Crossplane AWS Provider](https://marketplace.upbound.io/providers/upbound/provider-aws)
- [AWS Provider Configuration](https://marketplace.upbound.io/providers/upbound/provider-aws/latest/resources)
