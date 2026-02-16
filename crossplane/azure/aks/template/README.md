# Low-Cost AKS Cluster Template

This template creates a low-cost Azure Kubernetes Service (AKS) cluster using Crossplane.

## Prerequisites

*   A running Backstage instance with the Azure DevOps plugin installed.
*   A Crossplane instance running in your Kubernetes cluster.
*   The `upbound/provider-azure-containerservice` and `upbound/provider-azure` Crossplane providers installed.
*   An Azure service principal with sufficient permissions to create resources, and a secret named `azure-credentials` in the `crossplane-system` namespace containing the credentials.

## Usage

After running the template in Backstage, a new repository will be created in your Azure DevOps organization with the generated files.

To provision the AKS cluster, you need to apply the claim to your Kubernetes cluster where Crossplane is installed.

You can use the following YAML to create the claim. Save it as `claim.yaml` and apply it with `kubectl apply -f claim.yaml`.

```yaml
apiVersion: example.com/v1alpha1
kind: AKSCluster
metadata:
  name: ${{ values.cluster_name }}
  namespace: default
spec:
  parameters:
    location: ${{ values.location }}
    cluster_name: ${{ values.cluster_name }}
    node_count: ${{ values.node_count }}
    node_size: ${{ values.node_size }}
```

After a few minutes, your AKS cluster will be provisioned.
