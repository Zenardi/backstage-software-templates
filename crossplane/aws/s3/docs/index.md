# Crossplane AWS S3 Provider

This component contains the necessary Crossplane resources to enable the provisioning and management of AWS S3 buckets directly from Kubernetes.

These resources are designed to be deployed and managed as a single unit by ArgoCD, providing a foundational capability for on-demand S3 bucket creation.

## Overview

This component ensures that:
1.  The Crossplane provider for AWS S3 (`provider-aws-s3`) is installed in the cluster.
2.  A `ClusterProviderConfig` is created, which configures how Crossplane authenticates with your AWS account.
3.  A dedicated namespace (`s3-test`) exists for managing S3 bucket resources.

All of these resources are defined in the `crossplane/aws/s3` directory and synced by the `s3-resources` ArgoCD Application.

## Prerequisites

Before the ArgoCD application can sync successfully, you must configure two things:

### 1. ArgoCD Project Permissions

The ArgoCD project that this application belongs to (e.g., `s3-test`) must have permissions to manage cluster-scoped resources. If you see errors about "resource ... is not permitted", you need to update your `AppProject` YAML to whitelist them.

Example `clusterResourceWhitelist` in `AppProject`:
```yaml
spec:
  # ...
  clusterResourceWhitelist:
  - group: 'pkg.crossplane.io'
    kind: 'Provider'
  - group: 'aws.m.upbound.io'
    kind: 'ClusterProviderConfig'
  - group: '' # Core Kubernetes API
    kind: 'Namespace'
```

### 2. AWS Credentials Secret

The `ClusterProviderConfig` is configured to use credentials from a Kubernetes secret named `aws-secret` in the `crossplane-system` namespace. You must create this secret with your AWS credentials.

You can create the secret with the following command, replacing the placeholder values:

```bash
kubectl create secret generic aws-secret -n crossplane-system --from-literal=credentials="[default]
aws_access_key_id = <YOUR_AWS_ACCESS_KEY_ID>
aws_secret_access_key = <YOUR_AWS_SECRET_ACCESS_KEY>"
```

## How to Provision an S3 Bucket

Once this provider component is running, any developer can provision a new S3 bucket by simply creating a `Bucket` custom resource in the `s3-test` namespace.

### Example Bucket Manifest

Create a file named `my-bucket.yaml` with the following content. Make sure to choose a globally unique name for your bucket.

```yaml
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
metadata:
  # The name of your bucket must be globally unique
  name: my-awesome-app-bucket-2026-xyz
  namespace: s3-test
spec:
  forProvider:
    region: us-east-1
  providerConfigRef:
    # This must match the name of the ClusterProviderConfig
    name: aws
```

Apply it to the cluster:

```bash
kubectl apply -f my-bucket.yaml
```

Crossplane will see this new resource and automatically create the bucket in your AWS account. You can check the status of the bucket provisioning with `kubectl get bucket -n s3-test`. After a minute or two, you should see `READY: True` and `SYNCED: True`.
